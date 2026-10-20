/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.model.channel

import magic.app.models.uctoo.LlmChannelPO
import std.env.getVariable
import magic.utils.SecretCrypto
import std.collection.{HashMap, ArrayList}
import std.time.DateTime
import magic.log.LogUtils

/**
 * 通道快照（注册表内存态）。不可变，切换时整份替换（copy-on-write）。
 */
public struct ChannelSnapshot {
    public let code: String
    public let protocol: String
    public let baseUrl: String
    public let secretRef: String
    public let apiKey: String            // llm_channel.api_key 的密文（解密后才可用）
    public let displayName: String
    public let capabilities: String
    public let status: String
    public let isDefault: Bool
    public let defaultModel: String
    public let revision: Int64

    public init(code: String, protocol: String, baseUrl: String, secretRef: String, apiKey: String, displayName: String, capabilities: String, status: String, isDefault: Bool, defaultModel: String, revision: Int64) {
        this.code = code
        this.protocol = protocol
        this.baseUrl = baseUrl
        this.secretRef = secretRef
        this.apiKey = apiKey
        this.displayName = displayName
        this.capabilities = capabilities
        this.status = status
        this.isDefault = isDefault
        this.defaultModel = defaultModel
        this.revision = revision
    }
}

/**
 * ChannelRegistry — 运行时通道注册表。
 *
 * 设计（design.md §2/§4）：
 * - 真相在 llm_channel 表；DB 不可用退化为「内置种子」（双驱动兜底，REQ-DMC-017 V7）。
 * - 内存快照 + revision 比对；热路径零 DB 查询。
 * - 切换不是「改 HashMap」而是「换指针」（rebuild 整份替换），并发读无锁。
 */
public class ChannelRegistry {
    private static let INSTANCE = ChannelRegistry()
    public static func shared(): ChannelRegistry {
        INSTANCE
    }

    // T011：订阅通道变更事件，写操作后即时 refresh（原子换快照，满足 V1 ≤5s 生效）
    public init() {
        ChannelEventBus.shared().subscribe({ ev =>
            try {
                this.refresh()
                LogUtils.info("ChannelRegistry refreshed by ChannelChanged event (code=${ev.channelCode})")
            } catch (e: Exception) {
                LogUtils.error("ChannelRegistry refresh on event failed: ${e.message}")
            }
        })
    }

    private var snapshot: HashMap<String, ChannelSnapshot> = HashMap<String, ChannelSnapshot>()
    private var defaultCode: String = ""
    private var loadedRevision: Int64 = 0
    private var loadedAt: DateTime = DateTime.now()

    /**
     * 启动加载：优先从 DB（llm_channel）加载；为空则退化为内置种子。
     * 返回 true=成功从 DB 加载，false=退化种子。
     */
    public func load(): Bool {
        try {
            let channels = ChannelService.shared().listChannels()
            if (channels.size > 0) {
                rebuild(channels)
                LogUtils.info("ChannelRegistry.load: 从 DB 加载 ${snapshot.size} 个通道，默认=${defaultCode}")
                return true
            }
        } catch (e: Exception) {
            // V7：DB 不可用（断库）→ 退化为内置种子，保证 runtime 仍可聊天
            LogUtils.warn("ChannelRegistry.load: DB 读取通道失败，退化为内置种子（双驱动兜底）：${e.message}")
        }
        LogUtils.warn("ChannelRegistry.load: DB 无通道或不可用，退化为内置种子")
        rebuild(buildSeedChannels())
        return false
    }

    /**
     * 热刷新：重新加载并整份替换快照（原子替换，copy-on-write）。
     */
    public func refresh(): Bool {
        return load()
    }

    private func rebuild(channels: ArrayList<LlmChannelPO>): Unit {
        let map = HashMap<String, ChannelSnapshot>()
        var def = ""
        var maxRev: Int64 = 0
        for (po in channels) {
            let snap = ChannelSnapshot(
                po.code,
                po.protocol,
                str(po.baseUrl),
                str(po.secretRef),
                str(po.apiKey),
                str(po.displayName),
                po.capabilities,
                po.status,
                po.isDefault,
                str(po.defaultModel),
                po.revision
            )
            map.add(po.code, snap)
            if (po.isDefault) {
                def = po.code
            }
            if (po.revision > maxRev) {
                maxRev = po.revision
            }
        }
        this.snapshot = map
        this.defaultCode = def
        this.loadedRevision = maxRev
        this.loadedAt = DateTime.now()
    }

    // ==================== 查询（热路径，零 DB） ====================

    public func getChannel(code: String): Option<ChannelSnapshot> {
        snapshot.get(code)
    }

    public func getDefault(): Option<ChannelSnapshot> {
        if (defaultCode == "") {
            return None<ChannelSnapshot>
        }
        return snapshot.get(defaultCode)
    }

    public func getDefaultCode(): String {
        defaultCode
    }

    public func listSnapshots(): ArrayList<ChannelSnapshot> {
        let list = ArrayList<ChannelSnapshot>()
        for (v in snapshot.values()) {
            list.add(v)
        }
        return list
    }

    public func isLoaded(): Bool {
        snapshot.size > 0
    }

    public func currentRevision(): Int64 {
        loadedRevision
    }

    public func loadedAtTime(): DateTime {
        loadedAt
    }

    // ==================== 凭证解析（host.secret 简化版，MVP） ====================

    /**
     * 解析通道 base_url：目前种子/UI 直接存字面量 URL，原样返回；
     * 若未来存 `env:VAR` 形式，在此展开。
     */
    public func resolveBaseUrl(code: String): String {
        if (let Some(snap) <- snapshot.get(code)) {
            return snap.baseUrl
        }
        return ""
    }

    /**
     * 解析通道密钥（真相源：llm_channel 表，加密存储）。
     * 优先级：① DB 内加密 api_key（SecretCrypto 解密出明文）→ ② secret_ref=env:VAR（读进程环境变量，
     *   兼容旧数据 / 逃生舱）→ ③ 均为空则返回空（通道未配置密钥）。
     * 所有消费者（AdapterFactory / cordis_host_services / channel_probe）统一经此入口，改一处即全局生效。
     */
    public func resolveSecret(code: String): String {
        if (let Some(snap) <- snapshot.get(code)) {
            // ① 优先：DB 内加密存储的 api_key（解密后即为明文）
            if (!snap.apiKey.isEmpty()) {
                let plain = SecretCrypto.decrypt(snap.apiKey)
                if (!plain.isEmpty()) {
                    return plain
                }
                LogUtils.warn("ChannelRegistry.resolveSecret(${code})", "api_key 解密失败（密钥错误或主密钥不匹配），回退 secret_ref")
            }
            // ② 兼容旧数据：secret_ref = env:VAR
            let ref = snap.secretRef
            if (ref.startsWith("env:")) {
                let parts = ref.split(":")
                let varName = if (parts.size == 2) { parts[1] } else { "" }
                return getVariable(varName) ?? ""
            }
            // ③ 未配置
            return ""
        }
        return ""
    }

    private func str(o: Option<String>): String {
        if (let Some(v) <- o) {
            v
        } else {
            ""
        }
    }
}
