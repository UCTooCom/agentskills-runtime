/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.model.channel

import magic.app.dao.uctoo.{LlmChannelDAO, LlmChannelAuditDAO, LlmChannelModelDAO, LlmRouteRuleDAO, ModelPricingDAO}
import magic.app.models.uctoo.{LlmChannelPO, LlmChannelAuditPO, LlmChannelModelPO, LlmRouteRulePO}
import std.time.DateTime
import std.collection.{HashMap, ArrayList}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonNull, JsonArray, JsonInt, JsonBool}
import magic.jsonable.JsonUtils
import f_orm.*
import magic.core.model.*
import magic.log.LogUtils

/**
 * ChannelService — 通道读写 / 审计 / 种子播种。
 *
 * 职责边界（design.md §1.4）：负责通道元数据持久化与版本管理、审计；
 * 不负责协议实现、路由决策、实例构造（那些在 adapter_factory / model_router / registry）。
 *
 * 消费方：ChannelRegistry（启动时加载）、后续 llm_channel 管理 API/Controller。
 */
public class ChannelService {
    private static let INSTANCE = ChannelService()
    public static func shared(): ChannelService {
        INSTANCE
    }

    /**
     * 首次启动播种：llm_channel 为空时写入内置 20 通道（source=seed），并设 deepseek 为默认。
     * 返回本次播种条数（0 表示已存在，未改动）。
     *
     * 【默认通道为什么是 deepseek（2026-10-16 修订）】
     * 此前这里**硬偏好 arcbench**：只要种子里有 arcbench 就把它钉成默认。后果是用户在界面上
     * 看到的默认通道不是自己在管理界面选的那个，而是代码里写死的一个厂商 —— 这正是本工程要
     * 淘汰的「用户不可见的硬编码兜底」（dynamic-model-channel 的初衷）。
     * 修订原则：
     *   ① 播种只负责「让表里有一个可用默认」，默认取 deepseek（与本户要求的产品默认一致）；
     *   ② 默认一旦进库，后续真相就是 `llm_channel.is_default`，由界面 / 增量 SQL 改写，
     *      代码不再偏袒任何 provider —— 「界面可见 = 实际生效」。
     */
    public func seedIfEmpty(): Int64 {
        try {
            let daoOpt = ORM.executor() as LlmChannelDAO
            if (let Some(dao) <- daoOpt) {
                if (dao.countModelChannels() > 0) {
                    return 0
                }
                let seeds = buildSeedChannels()
                var n = 0
                for (po in seeds) {
                    let id = dao.insertModelChannel(po)
                    if (id != "") {
                        n += 1
                    }
                }
                // 设全局默认通道：deepseek 优先，否则取列表首元素。
                // 偏好本身不是"兜底"，而是播种时的一次性选择；之后以库里的 is_default 为真相。
                if (dao.findModelChannelByCode("deepseek").isSome()) {
                    dao.unsetDefaultExcept("deepseek")
                    dao.setDefaultByCode("deepseek")
                } else {
                    let all = dao.findAllModelChannels()
                    if (all.size > 0) {
                        if (let Some(first) <- all.get(0)) {
                            dao.unsetDefaultExcept(first.code)
                            dao.setDefaultByCode(first.code)
                        }
                    }
                }
                LogUtils.info("ChannelService.seedIfEmpty: 播种 ${n} 条内置通道（source=seed）")
                return n
            }
            LogUtils.error("ChannelService.seedIfEmpty: 无法获取 DAO")
            return 0
        } catch (e: Exception) {
            LogUtils.error("ChannelService.seedIfEmpty 失败：${e.message}")
            return 0
        }
    }

    public func getChannelByCode(code: String): Option<LlmChannelPO> {
        try {
            let daoOpt = ORM.executor() as LlmChannelDAO
            if (let Some(dao) <- daoOpt) {
                return dao.findModelChannelByCode(code)
            }
            return None<LlmChannelPO>
        } catch (e: Exception) {
            LogUtils.error("ChannelService.getChannelByCode(${code}) 失败：${e.message}")
            return None<LlmChannelPO>
        }
    }

    public func listChannels(): ArrayList<LlmChannelPO> {
        try {
            let daoOpt = ORM.executor() as LlmChannelDAO
            if (let Some(dao) <- daoOpt) {
                return dao.findAllModelChannels()
            }
            return ArrayList<LlmChannelPO>()
        } catch (e: Exception) {
            LogUtils.error("ChannelService.listChannels 失败：${e.message}")
            return ArrayList<LlmChannelPO>()
        }
    }

    public func countChannels(): Int64 {
        try {
            let daoOpt = ORM.executor() as LlmChannelDAO
            if (let Some(dao) <- daoOpt) {
                return dao.countModelChannels()
            }
            return 0
        } catch (e: Exception) {
            return 0
        }
    }

    /**
     * 用户面通道目录（REQ-DMC-021 / T035，design.md §9.1）。
     *
     * 返回「终端用户可在聊天框里选」的全部通道 —— 即作用域对用户可见的通道，
     * **不再按 status 过滤**：前端切换器会展示所有通道，并用状态灯（绿灯=enabled /
     * 红灯=degraded·disabled）提示可用性（V8：用户明确要求"无可用通道也显示空列表、
     * 且全量通道带状态标识"）。调用方（LlmChannelController.catalog）再做字段裁剪，
     * 敏感字段（base_url / secret_ref / health / config）绝不出口，但会带上 status。
     *
     * 作用域判定：scopes 含 "user" 或 "global" 均视为对用户可见。
     * - "user"  = 显式开放给用户面；
     * - "global" = 全作用域可用，天然包含用户面。
     * ⚠️ 内置种子 BUILTIN_SEED 的 scopes 是 ["global"]，若只认 "user"，
     *    全新安装（或已播种的库）目录会是空的 —— 切换器直接变空壳。
     */
    public func listUserCatalog(): ArrayList<LlmChannelPO> {
        let out = ArrayList<LlmChannelPO>()
        for (po in listChannels()) {
            if (isUserVisibleScope(po.scopes)) {
                out.add(po)
            }
        }
        return out
    }

    /**
     * 判断 scopes（JSON 数组字符串，如 ["global","user"]）是否对用户面可见。
     * 用子串匹配而非 JSON 解析：scopes 是受控的枚举数组，避免引入解析失败路径；
     * 空串（老数据未设置）视为 ["global"] 兼容处理，保证目录不为空。
     */
    public func isUserVisibleScope(scopes: String): Bool {
        if (scopes.isEmpty()) {
            return true
        }
        scopes.contains("\"user\"") || scopes.contains("\"global\"")
    }

    /**
     * 将某通道设为全局默认（热生效核心动作）。返回是否成功。
     */
    public func setDefault(code: String): Bool {
        try {
            let daoOpt = ORM.executor() as LlmChannelDAO
            if (let Some(dao) <- daoOpt) {
                if (dao.findModelChannelByCode(code).isNone()) {
                    LogUtils.error("ChannelService.setDefault 失败：通道 ${code} 不存在")
                    return false
                }
                let beforeCh = dao.findModelChannelByCode(code)
                let beforePayload = if (let Some(c) <- beforeCh) { channelAuditPayload(c) } else { "{}" }
                dao.unsetDefaultExcept(code)
                dao.setDefaultByCode(code)
                let afterCh = dao.findModelChannelByCode(code)
                let afterPayload = if (let Some(c) <- afterCh) { channelAuditPayload(c) } else { "{}" }
                writeAudit(code, "switch", beforePayload, afterPayload, "system")
                LogUtils.info("ChannelService.setDefault: ${code} 已设为默认通道")
                // T011：广播变更，触发 ChannelRegistry 即时 refresh（原子换快照，满足 V1 ≤5s 生效）
                ChannelEventBus.shared().publish(ChannelChanged(code, 0))
                return true
            }
            LogUtils.error("ChannelService.setDefault(${code}): 无法获取 DAO")
            return false
        } catch (e: Exception) {
            LogUtils.error("ChannelService.setDefault(${code}) 失败：${e.message}")
            return false
        }
    }

    // ==================== 审计（密钥掩码） ====================

    /**
     * 写一条通道变更审计。before/after 为通道快照 JSON（密钥已掩码）。
     */
    public func writeAudit(channelCode: String, action: String, before: String, after: String, source: String): Unit {
        try {
            let daoOpt = ORM.executor() as LlmChannelDAO
            if (let Some(dao) <- daoOpt) {
                let ch = dao.findModelChannelByCode(channelCode)
                let channelId: Option<String> = if (let Some(c) <- ch) { Some(c.id) } else { None<String> }
                let audit = LlmChannelAuditPO(
                    "",
                    channelId,
                    action,
                    before,
                    after,
                    None<String>,
                    source,
                    DateTime.now()
                )
                let auditDAOOpt = ORM.executor() as LlmChannelAuditDAO
                if (let Some(auditDAO) <- auditDAOOpt) {
                    auditDAO.insertModelChannelAudit(audit)
                }
            }
        } catch (e: Exception) {
            LogUtils.error("ChannelService.writeAudit(${channelCode}/${action}) 失败：${e.message}")
        }
    }

    /**
     * 构造通道快照 JSON 用于审计，密钥一律掩码为 "***"。
     */
    public func channelAuditPayload(po: LlmChannelPO): String {
        var map = HashMap<String, JsonValue>()
        map.add("code", JsonString(po.code))
        map.add("display_name", optJson(po.displayName))
        map.add("protocol", JsonString(po.protocol))
        map.add("base_url", optJson(po.baseUrl))
        map.add("secret_ref", JsonString("***"))   // 密钥绝不写明文
        map.add("api_key", JsonString("***"))       // api_key 密文也绝不进审计
        map.add("default_model", optJson(po.defaultModel))
        map.add("capabilities", JsonString(po.capabilities))
        map.add("scopes", JsonString(po.scopes))
        map.add("priority", JsonString(po.priority.toString()))
        map.add("status", JsonString(po.status))
        let isDefaultStr = if (po.isDefault) {
            "true"
        } else {
            "false"
        }
        map.add("is_default", JsonString(isDefaultStr))
        return JsonObject(map).toString()
    }

    private func optJson(o: Option<String>): JsonValue {
        if (let Some(v) <- o) {
            JsonString(v)
        } else {
            JsonString("")
        }
    }

    // ==================== T012：通道管理 API 写操作 ====================

    /**
     * 新增通道（管理 API /add）。返回创建后的 PO（含 id）；失败（code 空或已存在）返回 None。
     */
    public func addChannel(po: LlmChannelPO, source: String): Option<LlmChannelPO> {
        try {
            if (po.code.isEmpty()) {
                LogUtils.error("ChannelService.addChannel: code 不能为空")
                return None<LlmChannelPO>
            }
            let daoOpt = ORM.executor() as LlmChannelDAO
            if (let Some(dao) <- daoOpt) {
                if (dao.findModelChannelByCode(po.code).isSome()) {
                    LogUtils.error("ChannelService.addChannel: 通道 ${po.code} 已存在")
                    return None<LlmChannelPO>
                }
                let now = DateTime.now()
                po.id = ""
                po.revision = 0
                po.isDefault = false
                po.health = ""
                po.probeAt = None<DateTime>
                po.creator = Some<String>(source)
                po.createdAt = now
                po.updatedAt = now
                if (po.status.isEmpty()) {
                    po.status = "enabled"
                }
                let id = dao.insertModelChannel(po)
                if (id != "") {
                    po.id = id
                    writeAudit(po.code, "add", "{}", channelAuditPayload(po), source)
                    // 广播变更 → 触发 ChannelRegistry 即时 refresh（V1 热生效）
                    ChannelEventBus.shared().publish(ChannelChanged(po.code, 0))
                    return Some<LlmChannelPO>(po)
                }
            }
            return None<LlmChannelPO>
        } catch (e: Exception) {
            LogUtils.error("ChannelService.addChannel(${po.code}) 失败：${e.message}")
            return None<LlmChannelPO>
        }
    }

    /**
     * 更新通道（管理 API /edit）。请求表单提供的值覆盖既有值；空字符串/None 保留原值。
     * revision 自增 → 触发 ModelInstanceCache 失效与新实例构建（V4 drain）。
     */
    public func updateChannel(po: LlmChannelPO, source: String): Bool {
        try {
            if (po.code.isEmpty()) {
                return false
            }
            let daoOpt = ORM.executor() as LlmChannelDAO
            if (let Some(dao) <- daoOpt) {
                let existingOpt = dao.findModelChannelByCode(po.code)
                if (existingOpt.isNone()) {
                    return false
                }
                let existing = existingOpt.getOrThrow()
                let beforePayload = channelAuditPayload(existing)
                existing.displayName = if (let Some(v) <- po.displayName) { if (v.isEmpty()) { existing.displayName } else { po.displayName } } else { existing.displayName }
                existing.protocol = if (po.protocol.isEmpty()) { existing.protocol } else { po.protocol }
                existing.baseUrl = if (let Some(v) <- po.baseUrl) { if (v.isEmpty()) { existing.baseUrl } else { po.baseUrl } } else { existing.baseUrl }
                existing.secretRef = if (let Some(v) <- po.secretRef) { if (v.isEmpty()) { existing.secretRef } else { po.secretRef } } else { existing.secretRef }
                // api_key：控制器已在写入前用 SecretCrypto 加密成密文存入 po.apiKey；空串表示不改、保留原值
                existing.apiKey = if (let Some(v) <- po.apiKey) { if (v.isEmpty()) { existing.apiKey } else { po.apiKey } } else { existing.apiKey }
                existing.defaultModel = if (let Some(v) <- po.defaultModel) { if (v.isEmpty()) { existing.defaultModel } else { po.defaultModel } } else { existing.defaultModel }
                existing.capabilities = if (po.capabilities.isEmpty()) { existing.capabilities } else { po.capabilities }
                existing.scopes = if (po.scopes.isEmpty()) { existing.scopes } else { po.scopes }
                existing.priority = po.priority
                existing.status = if (po.status.isEmpty()) { existing.status } else { po.status }
                existing.config = if (po.config.isEmpty()) { existing.config } else { po.config }
                existing.revision = existing.revision + 1
                existing.updatedAt = DateTime.now()
                let rows = dao.updateModelChannel(existing)
                if (rows > 0) {
                    let afterPayload = channelAuditPayload(existing)
                    writeAudit(po.code, "edit", beforePayload, afterPayload, source)
                    ChannelEventBus.shared().publish(ChannelChanged(po.code, existing.revision))
                    return true
                }
            }
            return false
        } catch (e: Exception) {
            LogUtils.error("ChannelService.updateChannel(${po.code}) 失败：${e.message}")
            return false
        }
    }

    /**
     * 删除通道（软删，管理 API /del）。
     */
    public func deleteChannel(code: String, source: String): Bool {
        try {
            let daoOpt = ORM.executor() as LlmChannelDAO
            if (let Some(dao) <- daoOpt) {
                let existingOpt = dao.findModelChannelByCode(code)
                if (existingOpt.isNone()) {
                    return false
                }
                let existing = existingOpt.getOrThrow()
                let beforePayload = channelAuditPayload(existing)
                let rows = dao.softDeleteModelChannelById(existing.id)
                if (rows > 0) {
                    writeAudit(code, "delete", beforePayload, "{}", source)
                    ChannelEventBus.shared().publish(ChannelChanged(code, 0))
                    return true
                }
            }
            return false
        } catch (e: Exception) {
            LogUtils.error("ChannelService.deleteChannel(${code}) 失败：${e.message}")
            return false
        }
    }

    /**
     * 启停通道（管理 API /:code/toggle）。
     */
    public func toggleChannel(code: String, enabled: Bool, source: String): Bool {
        try {
            let daoOpt = ORM.executor() as LlmChannelDAO
            if (let Some(dao) <- daoOpt) {
                let existingOpt = dao.findModelChannelByCode(code)
                if (existingOpt.isNone()) {
                    return false
                }
                let existing = existingOpt.getOrThrow()
                let beforePayload = channelAuditPayload(existing)
                existing.status = if (enabled) { "enabled" } else { "disabled" }
                existing.revision = existing.revision + 1
                existing.updatedAt = DateTime.now()
                let rows = dao.updateModelChannel(existing)
                if (rows > 0) {
                    let afterPayload = channelAuditPayload(existing)
                    writeAudit(code, "toggle", beforePayload, afterPayload, source)
                    ChannelEventBus.shared().publish(ChannelChanged(code, existing.revision))
                    return true
                }
            }
            return false
        } catch (e: Exception) {
            LogUtils.error("ChannelService.toggleChannel(${code}) 失败：${e.message}")
            return false
        }
    }

    /**
     * 通道连通性测试（管理 API /:code/test）。
     * 经 AdapterFactory 构造 ChatModel 并做一次最小补全，返回 (是否成功, 错误明细)。
     * 测试失败（如缺密钥/URL 不可达）即把异常信息透传给前端，便于排错（design.md §8）。
     */
    public func testChannel(code: String): (Bool, String) {
        let snapOpt = ChannelRegistry.shared().getChannel(code)
        if (snapOpt.isNone()) {
            return (false, "通道 ${code} 不在运行注册表中（可能尚未 reload，或已被删除）")
        }
        let snap = snapOpt.getOrThrow()
        let modelId = if (let Some(po) <- getChannelByCode(code)) {
            if (let Some(dm) <- po.defaultModel) { dm } else { code }
        } else { code }
        try {
            let chatModel = AdapterFactory.buildChatModel(snap, modelId)
            let _ = chatModel.create(ChatRequest("ping"))
            return (true, "ok")
        } catch (e: Exception) {
            return (false, e.message)
        }
    }

    /**
     * 手动触发注册表全量刷新（管理 API /reload 救急）。
     */
    public func reloadRegistry(): Unit {
        ChannelRegistry.shared().refresh()
    }

    // ==================== T019：变更审计查询 ====================

    /**
     * 变更审计列表（管理 API /audit，design.md §8）。
     *
     * @param code 通道编码；空串表示查全部通道。
     * @param limit 返回条数上限（由 Controller 校验，避免全表拖库）。
     *
     * 审计表是 append-only（只插入不 UPDATE），因此没有软删过滤。
     * 每条记录含 source（seed / api / ui / agent），用于追溯是谁改的（design.md §8）。
     */
    public func listAudits(code: String, limit: Int64): ArrayList<LlmChannelAuditPO> {
        try {
            let daoOpt = ORM.executor() as LlmChannelAuditDAO
            if (let Some(dao) <- daoOpt) {
                if (code.isEmpty()) {
                    return dao.findRecentModelChannelAudits(limit)
                }
                return dao.findModelChannelAuditsByCode(code, limit)
            }
            return ArrayList<LlmChannelAuditPO>()
        } catch (e: Exception) {
            LogUtils.error("ChannelService.listAudits 失败：${e.message}")
            return ArrayList<LlmChannelAuditPO>()
        }
    }

    public func countAudits(): Int64 {
        try {
            let daoOpt = ORM.executor() as LlmChannelAuditDAO
            if (let Some(dao) <- daoOpt) {
                return dao.countModelChannelAudits()
            }
            return 0
        } catch (e: Exception) {
            LogUtils.error("ChannelService.countAudits 失败：${e.message}")
            return 0
        }
    }

    // ==================== T017 / T026：探测结果写回 ====================

    /**
     * 三枪探测结果写回：能力位 + 健康快照 + 探测时间。
     * 不 bump revision（理由见 LlmChannelDAO.updateChannelProbe）。
     */
    public func applyProbeResult(code: String, capabilities: String, healthJson: String): Bool {
        try {
            let daoOpt = ORM.executor() as LlmChannelDAO
            if (let Some(dao) <- daoOpt) {
                let rows = dao.updateChannelProbe(code, capabilities, healthJson, DateTime.now())
                return rows >= 0
            }
            return false
        } catch (e: Exception) {
            LogUtils.error("ChannelService.applyProbeResult(${code}) 失败：${e.message}")
            return false
        }
    }

    /**
     * 周期探活（T026）写回健康状态：连续失败 -> degraded、恢复 -> enabled。
     */
    public func applyHealthStatus(code: String, status: String): Bool {
        try {
            let daoOpt = ORM.executor() as LlmChannelDAO
            if (let Some(dao) <- daoOpt) {
                let rows = dao.updateChannelStatusOnly(code, status, DateTime.now())
                return rows >= 0
            }
            return false
        } catch (e: Exception) {
            LogUtils.error("ChannelService.applyHealthStatus(${code}) 失败：${e.message}")
            return false
        }
    }

    // ==================== T016：模型清单查询 ====================

    /**
     * 某通道下的模型条目列表（用于下拉 / 同步结果展示）。
     */
    public func listModelsByChannel(code: String): ArrayList<LlmChannelModelPO> {
        try {
            let chOpt = getChannelByCode(code)
            if (chOpt.isNone()) {
                return ArrayList<LlmChannelModelPO>()
            }
            let daoOpt = ORM.executor() as LlmChannelModelDAO
            if (let Some(dao) <- daoOpt) {
                return dao.findModelChannelModelsByChannelId(chOpt.getOrThrow().id)
            }
            return ArrayList<LlmChannelModelPO>()
        } catch (e: Exception) {
            LogUtils.error("ChannelService.listModelsByChannel(${code}) 失败：${e.message}")
            return ArrayList<LlmChannelModelPO>()
        }
    }

    /**
     * 全部通道的模型条目（GET /models 数据源；供聊天框 / 管理页下拉）。
     */
    public func listAllModels(): ArrayList<LlmChannelModelPO> {
        try {
            let daoOpt = ORM.executor() as LlmChannelModelDAO
            if (let Some(dao) <- daoOpt) {
                let channels = listChannels()
                let out = ArrayList<LlmChannelModelPO>()
                for (ch in channels) {
                    let models = dao.findModelChannelModelsByChannelId(ch.id)
                    for (m in models) {
                        out.add(m)
                    }
                }
                return out
            }
            return ArrayList<LlmChannelModelPO>()
        } catch (e: Exception) {
            LogUtils.error("ChannelService.listAllModels 失败：${e.message}")
            return ArrayList<LlmChannelModelPO>()
        }
    }

    // ==================== T027：路由规则 CRUD（llm_route_rule） ====================

    public func listRouteRules(): ArrayList<LlmRouteRulePO> {
        try {
            let daoOpt = ORM.executor() as LlmRouteRuleDAO
            if (let Some(dao) <- daoOpt) {
                return dao.findAllModelRouteRules()
            }
            return ArrayList<LlmRouteRulePO>()
        } catch (e: Exception) {
            LogUtils.error("ChannelService.listRouteRules 失败：${e.message}")
            return ArrayList<LlmRouteRulePO>()
        }
    }

    public func addRouteRule(po: LlmRouteRulePO, source: String): Option<LlmRouteRulePO> {
        try {
            if (po.scope.isEmpty()) {
                po.scope = "global"
            }
            if (po.strategy.isEmpty()) {
                po.strategy = "priority"
            }
            po.id = ""
            po.revision = 0
            po.enabled = true
            po.deletedAt = None<DateTime>
            po.createdAt = DateTime.now()
            po.updatedAt = DateTime.now()
            let daoOpt = ORM.executor() as LlmRouteRuleDAO
            if (let Some(dao) <- daoOpt) {
                let id = dao.insertModelRouteRule(po)
                if (id != "") {
                    po.id = id
                    LogUtils.info("ChannelService.addRouteRule: 新增规则 scope=${po.scope} strategy=${po.strategy}")
                    this.loadRouteRules()
                    return Some<LlmRouteRulePO>(po)
                }
            }
            return None<LlmRouteRulePO>
        } catch (e: Exception) {
            LogUtils.error("ChannelService.addRouteRule(${po.scope}) 失败：${e.message}")
            return None<LlmRouteRulePO>
        }
    }

    public func updateRouteRule(po: LlmRouteRulePO, source: String): Bool {
        try {
            if (po.id.isEmpty()) {
                return false
            }
            let daoOpt = ORM.executor() as LlmRouteRuleDAO
            if (let Some(dao) <- daoOpt) {
                let existingOpt = dao.findModelRouteRuleById(po.id)
                if (existingOpt.isNone()) {
                    return false
                }
                let existing = existingOpt.getOrThrow()
                existing.scope = if (po.scope.isEmpty()) { existing.scope } else { po.scope }
                existing.requireCapabilities = if (po.requireCapabilities.isEmpty()) { existing.requireCapabilities } else { po.requireCapabilities }
                existing.channelChain = if (po.channelChain.isEmpty()) { existing.channelChain } else { po.channelChain }
                existing.fallbackChain = if (po.fallbackChain.isEmpty()) { existing.fallbackChain } else { po.fallbackChain }
                existing.strategy = if (po.strategy.isEmpty()) { existing.strategy } else { po.strategy }
                existing.shadowPercent = po.shadowPercent
                existing.priority = po.priority
                existing.enabled = po.enabled
                existing.revision = existing.revision + 1
                existing.updatedAt = DateTime.now()
                let rows = dao.updateModelRouteRule(existing)
                if (rows > 0) {
                    LogUtils.info("ChannelService.updateRouteRule: 更新规则 ${po.id}")
                    this.loadRouteRules()
                    return true
                }
            }
            return false
        } catch (e: Exception) {
            LogUtils.error("ChannelService.updateRouteRule(${po.id}) 失败：${e.message}")
            return false
        }
    }

    public func deleteRouteRule(id: String, source: String): Bool {
        try {
            let daoOpt = ORM.executor() as LlmRouteRuleDAO
            if (let Some(dao) <- daoOpt) {
                let rows = dao.softDeleteModelRouteRuleById(id)
                if (rows > 0) {
                    LogUtils.info("ChannelService.deleteRouteRule: 删除规则 ${id}")
                    this.loadRouteRules()
                    return true
                }
            }
            return false
        } catch (e: Exception) {
            LogUtils.error("ChannelService.deleteRouteRule(${id}) 失败：${e.message}")
            return false
        }
    }

    /**
     * 启动时（或规则变更后）加载路由规则注入 ModelRouter，并注入成本策略所需的单价查询。
     * - 把 llm_route_rule 的 JSON 数组列（require_capabilities / channel_chain / fallback_chain）
     *   解析为 ArrayList<String> 构造 RouteRule 列表；
     * - 设置 ModelRouter.setPricingProvider：从 model_pricing 表取该 provider 的 active 单价均值，
     *   失败/缺数据则中性（0.0），不影响其它策略。
     * 与 ChannelRegistry 同属「配置加载」阶段，DB 不可用则静默跳过（路由退化为默认通道）。
     */
    public func loadRouteRules(): Unit {
        try {
            // 0. 通道优先级查询（T031 system1 策略归一化用）
            ModelRouter.shared().setPriorityProvider({ code =>
                let poOpt = this.getChannelByCode(code)
                if (poOpt.isSome()) {
                    Float64(poOpt.getOrThrow().priority)
                } else {
                    0.0
                }
            })

            // 1. 单价查询（cost 策略用）
            ModelRouter.shared().setPricingProvider({ code =>
                let daoOpt = ORM.executor() as ModelPricingDAO
                if (let Some(dao) <- daoOpt) {
                    let list = dao.listAllModelPricing()
                    var sum: Float64 = 0.0
                    var cnt: Int64 = 0
                    for (p in list) {
                        if (p.provider == code && p.isActive) {
                            sum = sum + (p.ratePromptPerMillion + p.rateCompletionPerMillion) / 2.0
                            cnt = cnt + 1
                        }
                    }
                    if (cnt > 0) { sum / Float64(cnt) } else { 0.0 }
                } else {
                    0.0
                }
            })

            // 2. 规则列表
            let daoOpt = ORM.executor() as LlmRouteRuleDAO
            if (let Some(dao) <- daoOpt) {
                let pos = dao.findAllModelRouteRules()
                var rules = ArrayList<RouteRule>()
                for (po in pos) {
                    let rule = RouteRule(
                        po.scope,
                        parseJsonStringArray(po.requireCapabilities),
                        parseJsonStringArray(po.channelChain),
                        parseJsonStringArray(po.fallbackChain),
                        po.strategy,
                        po.shadowPercent,
                        po.priority,
                        po.enabled
                    )
                    rules.add(rule)
                }
                ModelRouter.shared().setRules(rules)
                LogUtils.info("ChannelService.loadRouteRules: 载入 ${rules.size} 条路由规则")
            }
        } catch (e: Exception) {
            LogUtils.error("ChannelService.loadRouteRules 失败（路由退化为默认通道）：${e.message}")
        }
    }

    // ==================== 配置导出 / 导入（T033） ====================

    /**
     * 导出全部通道配置为 JSON 文本。
     *
     * 安全约束（V5）：**导出的 secretRef 是引用名（如 OPENAI_API_KEY / env:XXX），
     * 不是明文密钥**。channelAuditPayload 会把 secret_ref 掩码成 "***"，
     * 但导出需要保留引用名以便目标环境照配同名环境变量，所以这里单独构造——
     * 仍然**不导出明文**：只有当 secretRef 本身就是 env 引用名时才输出。
     * 若某通道的 secretRef 存的是明文（历史误操作），一律替换为 "***" 并在
     * warnings 里提示，避免明文随导出文件泄漏。
     */
    public func exportConfig(): String {
        let channels = this.listChannels()
        let arr = JsonArray()
        for (po in channels) {
            let item = JsonObject()
            item.put("code", JsonString(po.code))
            item.put("display_name", optJson(po.displayName))
            item.put("protocol", JsonString(po.protocol))
            item.put("base_url", optJson(po.baseUrl))
            item.put("default_model", optJson(po.defaultModel))
            item.put("capabilities", JsonString(po.capabilities))
            item.put("scopes", JsonString(po.scopes))
            item.put("priority", JsonInt(Int64(po.priority)))
            item.put("status", JsonString(po.status))
            item.put("is_default", JsonBool(po.isDefault))

            // 密钥只导引用，不导明文
            let ref = po.secretRef.getOrDefault({ => "" })
            if (ref.isEmpty()) {
                item.put("secret_ref", JsonString(""))
            } else if (ref.startsWith("env:") || ref == ref.toAsciiUpper()) {
                // 合法的引用形式：env:NAME 或全大写环境变量名
                item.put("secret_ref", JsonString(ref))
            } else {
                // 疑似明文，抹掉
                item.put("secret_ref", JsonString("***"))
            }
            arr.add(item)
        }

        let rules = this.listRouteRules()
        let ruleArr = JsonArray()
        for (r in rules) {
            let item = JsonObject()
            item.put("scope", JsonString(r.scope))
            item.put("strategy", JsonString(r.strategy))
            item.put("require_capabilities", JsonString(r.requireCapabilities))
            item.put("channel_chain", JsonString(r.channelChain))
            item.put("fallback_chain", JsonString(r.fallbackChain))
            item.put("priority", JsonInt(Int64(r.priority)))
            item.put("shadow_percent", JsonInt(Int64(r.shadowPercent)))
            item.put("enabled", JsonBool(r.enabled))
            ruleArr.add(item)
        }

        let root = JsonObject()
        root.put("version", JsonString("1"))
        root.put("exported_at", JsonString(DateTime.now().toString()))
        root.put("note", JsonString("密钥仅含引用名（env:NAME 或大写变量名），不含明文"))
        root.put("llm_channels", arr)
        root.put("llm_route_rules", ruleArr)
        root.toString()
    }

    /**
     * 导入通道配置（来自 exportConfig 的 JSON 文本）。
     *
     * 语义（幂等 + 不覆盖密钥）：
     * - code 已存在 → 跳过（返回 skipped），**不改已有通道**，避免误覆盖生产配置；
     * - code 不存在 → 新增（source=import），secret_ref 为空或 "***" 时留空由管理员后补；
     * - 逐条 try/catch，单条失败不影响其余条目（返回 errors 明细）。
     *
     * @param jsonText 导出的 JSON 文本
     * @return 摘要 JSON：{"added":N,"skipped":M,"errors":[...]}
     */
    public func importConfig(jsonText: String): String {
        var added: Int64 = 0
        var skipped: Int64 = 0
        let errors = JsonArray()
        try {
            let v = JsonValue.fromStr(jsonText)
            let rootOpt = JsonUtils.asJsonObject(v)
            if (rootOpt.isNone()) {
                return "{\"added\":0,\"skipped\":0,\"errors\":[\"导入内容不是 JSON 对象\"]}"
            }
            let root = rootOpt.getOrThrow()
            let chOpt = root.get("llm_channels")
            if (chOpt.isSome()) {
                if (let Some(arr) <- JsonUtils.asJsonArray(chOpt.getOrThrow())) {
                    for (item in arr.getItems()) {
                        try {
                            let objOpt = JsonUtils.asJsonObject(item)
                            if (objOpt.isNone()) {
                                continue
                            }
                            let obj = objOpt.getOrThrow()
                            let po = LlmChannelPO()
                            po.code = importStr(obj, "code")
                            if (po.code.isEmpty()) {
                                continue
                            }
                            // 已存在则跳过，不覆盖
                            if (this.getChannelByCode(po.code).isSome()) {
                                skipped = skipped + 1
                                continue
                            }
                            po.displayName = Some<String>(importStr(obj, "display_name"))
                            po.protocol = importStr(obj, "protocol")
                            if (po.protocol.isEmpty()) {
                                po.protocol = "openai-chat"
                            }
                            let baseUrl = importStr(obj, "base_url")
                            if (!baseUrl.isEmpty()) {
                                po.baseUrl = Some<String>(baseUrl)
                            }
                            let defModel = importStr(obj, "default_model")
                            if (!defModel.isEmpty()) {
                                po.defaultModel = Some<String>(defModel)
                            }
                            po.capabilities = importStr(obj, "capabilities")
                            po.scopes = importStr(obj, "scopes")
                            if (po.capabilities.isEmpty()) {
                                po.capabilities = "[\"chat\"]"
                            }
                            if (po.scopes.isEmpty()) {
                                po.scopes = "[\"global\"]"
                            }
                            let priOpt = obj.get("priority")
                            if (priOpt.isSome()) {
                                if (let Some(p) <- JsonUtils.toInt(priOpt.getOrThrow())) {
                                    po.priority = Int32(p)
                                }
                            }
                            po.status = importStr(obj, "status")
                            if (po.status.isEmpty()) {
                                po.status = "enabled"
                            }
                            let isDefOpt = obj.get("is_default")
                            if (isDefOpt.isSome()) {
                                if (let Some(b) <- JsonUtils.toBool(isDefOpt.getOrThrow())) {
                                    po.isDefault = b
                                }
                            }
                            // 密钥：只接受引用名，"***" 与空值都留空
                            let ref = importStr(obj, "secret_ref")
                            if (!ref.isEmpty() && ref != "***") {
                                po.secretRef = Some<String>(ref)
                            }
                            po.id = ""
                            po.revision = 0
                            po.deletedAt = None<DateTime>
                            po.createdAt = DateTime.now()
                            po.updatedAt = DateTime.now()
                            if (this.addChannel(po, "import").isSome()) {
                                added = added + 1
                            } else {
                                errors.add(JsonString("新增失败：${po.code}"))
                            }
                        } catch (e: Exception) {
                            errors.add(JsonString("单条导入异常：${e.message}"))
                        }
                    }
                }
            }
        } catch (e: Exception) {
            errors.add(JsonString("解析失败：${e.message}"))
        }
        let result = JsonObject()
        result.put("added", JsonInt(added))
        result.put("skipped", JsonInt(skipped))
        result.put("errors", errors)
        result.toString()
    }

    private func importStr(obj: JsonObject, key: String): String {
        match (obj.get(key)) {
            case Some(v) => JsonUtils.toString(v).getOrDefault({ => "" })
            case None => ""
        }
    }

    /**
     * 解析 JSON 数组字符串为 ArrayList<String>（require_capabilities / scopes / channel_chain 等）。
     * 解析失败返回空列表，避免选路崩溃。
     */
    private func parseJsonStringArray(s: String): ArrayList<String> {
        let out = ArrayList<String>()
        if (s.isEmpty()) {
            return out
        }
        try {
            let v = JsonValue.fromStr(s)
            if (let Some(arr) <- JsonUtils.asJsonArray(v)) {
                for (item in arr.getItems()) {
                    if (let Some(js) <- JsonUtils.toString(item)) {
                        out.add(js)
                    }
                }
            }
        } catch (_: Exception) {}
        out
    }
}
