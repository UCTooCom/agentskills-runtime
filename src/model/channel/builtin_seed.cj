/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.model.channel

import magic.app.models.uctoo.ModelChannelPO
import std.time.DateTime
import std.collection.ArrayList

/**
 * 内置通道种子（BUILTIN_SEED）
 *
 * 来源：原 `model_manager.cj` 的 `DEFAULT_PROVIDER_MAP`（20 个 provider）。
 * 动态化后它退化为「首次播种 + DB 不可用兜底」的数据，运行时真相改为查 llm_channel 表。
 *
 * 设计原则（design.md §1）：
 * - 真相在数据（llm_channel 表），确定性在代码（OpenAI 兼容协议实现不变）；
 * - 密钥绝不存明文：seed 只记 `secret_ref = env:<VAR>`，运行时由 AdapterFactory 解析；
 * - base_url 记默认 URL，`.env` 的变量可覆盖（逃生舱）。
 *
 * 能力位（capabilities）为 advisory：seed 给一个合理默认，真正能力以三枪探测为准（Phase 1）。
 */
public struct BuiltinChannelSeed {
    let code: String            // 通道编码，即旧 provider 名
    let displayName: String     // 界面显示名
    let protocol: String        // openai-chat / ollama / llamacpp / tokendance
    let baseUrl: String         // 默认 base_url（/v1 级）
    let keyEnvVar: String       // 密钥环境变量名；空串表示无密钥（本地推理）
    let capabilities: String    // JSON 数组字符串：chat/stream/tools/embedding/image

    public init(code: String, displayName: String, protocol: String, baseUrl: String, keyEnvVar: String, capabilities: String) {
        this.code = code
        this.displayName = displayName
        this.protocol = protocol
        this.baseUrl = baseUrl
        this.keyEnvVar = keyEnvVar
        this.capabilities = capabilities
    }
}

public let CHAT_CAP = "[\"chat\",\"stream\",\"tools\",\"embedding\",\"image\"]"
public let CHAT_EMBED_CAP = "[\"chat\",\"stream\",\"tools\",\"embedding\"]"
public let EMBED_ONLY_CAP = "[\"embedding\"]"

public let BUILTIN_CHANNEL_SEED: Array<BuiltinChannelSeed> = [
    BuiltinChannelSeed("openai", "OpenAI", "openai-chat", "https://api.openai.com/v1", "OPENAI_API_KEY", CHAT_CAP),
    BuiltinChannelSeed("dashscope", "阿里云百炼 DashScope", "openai-chat", "https://dashscope.aliyuncs.com/compatible-mode/v1", "DASHSCOPE_API_KEY", CHAT_CAP),
    BuiltinChannelSeed("ark", "火山方舟 Ark", "openai-chat", "https://ark.cn-beijing.volces.com/api/v3", "ARK_API_KEY", CHAT_CAP),
    BuiltinChannelSeed("deepseek", "DeepSeek", "openai-chat", "https://api.deepseek.com", "DEEPSEEK_API_KEY", CHAT_CAP),
    BuiltinChannelSeed("siliconflow", "SiliconFlow", "openai-chat", "https://api.siliconflow.cn/v1", "SILICONFLOW_API_KEY", CHAT_CAP),
    BuiltinChannelSeed("zhipuai", "智谱 GLM", "openai-chat", "https://open.bigmodel.cn/api/paas/v4", "ZHIPU_API_KEY", CHAT_CAP),
    BuiltinChannelSeed("maas", "华为云 MaaS", "openai-chat", "https://api.modelarts-maas.com/v2", "MAAS_API_KEY", CHAT_CAP),
    BuiltinChannelSeed("google", "Google", "openai-chat", "https://generativelanguage.googleapis.com/v1beta/openai", "GOOGLE_API_KEY", CHAT_CAP),
    BuiltinChannelSeed("moonshot", "Moonshot Kimi", "openai-chat", "https://api.moonshot.cn/v1", "MOONSHOT_API_KEY", CHAT_CAP),
    BuiltinChannelSeed("openrouter", "OpenRouter", "openai-chat", "https://openrouter.ai/api/v1", "OPENROUTER_API_KEY", CHAT_CAP),
    BuiltinChannelSeed("stepfun", "阶跃星辰 StepFun", "openai-chat", "https://api.stepfun.com/v1", "STEPFUN_API_KEY", CHAT_CAP),
    BuiltinChannelSeed("sophnet", "天翼云 SophNet", "openai-chat", "https://www.sophnet.com/api/open-apis/v1", "SOPHNET_API_KEY", CHAT_CAP),
    BuiltinChannelSeed("orbitai", "OrbitAI", "openai-chat", "https://aiapi.orbitai.global/v1", "ORBITAI_API_KEY", CHAT_CAP),
    BuiltinChannelSeed("gmicloud", "GMICloud", "openai-chat", "https://api.gmi-serving.com/v1", "GMICLOUD_API_KEY", CHAT_CAP),
    BuiltinChannelSeed("atomgit", "AtomGit", "openai-chat", "https://api.atomgit.com/api/v5", "ATOMGIT_API_KEY", CHAT_CAP),
    BuiltinChannelSeed("evomap", "EvoMap", "openai-chat", "https://api.evomap.ai/v1", "EVOMAP_API_KEY", CHAT_CAP),
    BuiltinChannelSeed("arcbench", "ArcBench", "openai-chat", "https://api.arc-bench.com/v1", "ARCBENCH_API_KEY", CHAT_CAP),
    BuiltinChannelSeed("tokendance", "Tokendance", "tokendance", "https://tokendance.space/gateway/v1", "TOKENDANCE_API_KEY", CHAT_EMBED_CAP),
    BuiltinChannelSeed("ollama", "Ollama", "ollama", "http://localhost:11434", "", CHAT_EMBED_CAP),
    BuiltinChannelSeed("llamacpp", "LlamaCPP", "llamacpp", "http://localhost:8080", "", EMBED_ONLY_CAP)
]

/**
 * 把种子数据落成 llm_channel 的 PO（source=seed 由 ChannelService 负责记审计，
 * 这里只产出实体；creator/默认标记等由调用方决定）。
 */
public func buildSeedChannels(): ArrayList<ModelChannelPO> {
    let now = DateTime.now()
    let list = ArrayList<ModelChannelPO>()
    for (s in BUILTIN_CHANNEL_SEED) {
        let secretRef: Option<String> = if (s.keyEnvVar == "") {
            None<String>
        } else {
            Some("env:${s.keyEnvVar}")
        }
        let po = ModelChannelPO(
            "",
            s.code,
            Some(s.displayName),
            s.protocol,
            Some(s.baseUrl),
            secretRef,
            None<String>,
            s.capabilities,
            "[\"global\"]",
            0,
            "enabled",
            false,
            "{}",
            None<DateTime>,
            "{}",
            0,
            None<String>,
            now,
            now,
            None<DateTime>
        )
        list.add(po)
    }
    return list
}
