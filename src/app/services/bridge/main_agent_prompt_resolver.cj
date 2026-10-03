/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.bridge

import magic.core.agent.AgentDefinition
import magic.app.models.uctoo.AgentsPO
import magic.app.models.uctoo.ConfigPO
import magic.app.services.uctoo.AgentsService
import magic.app.services.uctoo.ConfigService
import magic.log.LogUtils

/**
 * 主 Agent 系统提示词的**唯一解析入口**。
 *
 * 设计原则（对齐 runtime「业务规则动态配置 / 可视化配置」哲学）：
 * 系统提示词是**数据**，不是代码。运行时代码里不允许出现任何策略性提示词字面量——
 * 提示词必须来自可配置的数据源，改提示词不需要改代码、不需要重新编译。
 *
 * 三级来源（按优先级，命中即返回）：
 *   ① Agent 定义文件（`AGENTS.md` / `agents/<name>.md` 的 markdown 正文）——真相源。
 *      `AgentLoader` 把 md 的 body 解析为 `AgentDefinition.systemPrompt`
 *      （见 `core/agent/agent_loader.cj` 的 `buildAgentFromYaml`）。
 *      启动时 `AgentRuntimeBridge.createRuntimeAgent` 会把该值回写 `agents` 表，
 *      所以后台「Agent 管理」里看到的 system_prompt 与文件始终一致。
 *   ② 数据库 `agents` 表 `agent_type=MAIN` 的 `system_prompt` —— 文件缺失时的可视化兜底，
 *      后台可直接编辑。
 *   ③ 数据库 `config` 表 key=`MAIN_AGENT_FALLBACK_PROMPT` 的 value —— 最后一道可配置兜底，
 *      后台「系统配置」里新增该 key 即可生效。
 *   ④ 以上都没有 → 返回空串并打 WARN。
 *
 * 为什么第 ④ 级不再写一份「代码里的默认提示词」：按「配置即事实」原则，运行时不做
 * 用户看不见的隐藏兜底。没配就是没配，宁可让 agent 在缺少人格设定下运行并留下明确告警，
 * 也不在 .cj 里塞一份与后台配置脱节、用户改不掉的默认文案。
 */
public class MainAgentPromptResolver {
    /** 兜底提示词在 `config` 表中的 key（后台「系统配置」可视化维护） */
    public static let FALLBACK_CONFIG_KEY: String = "MAIN_AGENT_FALLBACK_PROMPT"

    /**
     * 解析主 Agent 的系统提示词。
     *
     * - agentDef: AgentLoader 从文件解析出的主 Agent 定义（文件缺失时为 None）
     * - tag: 调用方标识，仅用于日志定位（如 "WebMCPProtocol"）
     */
    public static func resolve(agentDef: ?AgentDefinition, tag: String): String {
        // ① Agent 定义文件（AGENTS.md 等）
        if (let Some(def) <- agentDef) {
            let filePrompt = def.systemPrompt.trimAscii()
            if (!filePrompt.isEmpty()) {
                LogUtils.info("[${tag}] systemPrompt source=agent-definition-file, path=${def.sourcePath.toString()}, length=${filePrompt.size.toString()}")
                return def.systemPrompt
            }
        }

        // ② 数据库 agents 表（后台「Agent 管理」可视化编辑）
        let dbPrompt = loadFromAgentsTable(tag)
        if (!dbPrompt.isEmpty()) {
            return dbPrompt
        }

        // ③ 数据库 config 表（后台「系统配置」可视化维护）
        let cfgPrompt = loadFromConfigTable(tag)
        if (!cfgPrompt.isEmpty()) {
            return cfgPrompt
        }

        LogUtils.warn("[${tag}] 未解析到主 Agent 系统提示词。请在 AGENTS.md 定义主 Agent，或在后台「Agent 管理」配置 MAIN agent 的 system_prompt，或在「系统配置」新增 key=${FALLBACK_CONFIG_KEY}")
        return ""
    }

    private static func loadFromAgentsTable(tag: String): String {
        try {
            let agentsService = AgentsService()
            let (list, _) = agentsService.getListWithFilter(1, 1, "", "{\"agent_type\":{\"equals\":\"MAIN\"}}")
            if (list.size > 0) {
                if (let Some(sp) <- list[0].systemPrompt) {
                    let trimmed = sp.trimAscii()
                    if (!trimmed.isEmpty()) {
                        LogUtils.info("[${tag}] systemPrompt source=agents-table, name=${list[0].name}, length=${trimmed.size.toString()}")
                        return sp
                    }
                }
            }
        } catch (e: Exception) {
            LogUtils.warn("[${tag}] 读取 agents 表主 Agent 提示词失败: ${e.message}")
        }
        return ""
    }

    private static func loadFromConfigTable(tag: String): String {
        try {
            let configService = ConfigService()
            let result = configService.getConfigByKey(FALLBACK_CONFIG_KEY)
            if (result.success) {
                if (let Some(po) <- result.data) {
                    if (let Some(v) <- po.value) {
                        let trimmed = v.trimAscii()
                        if (!trimmed.isEmpty()) {
                            LogUtils.info("[${tag}] systemPrompt source=config-table, key=${FALLBACK_CONFIG_KEY}, length=${trimmed.size.toString()}")
                            return v
                        }
                    }
                }
            }
        } catch (e: Exception) {
            LogUtils.warn("[${tag}] 读取 config 表兜底提示词失败: ${e.message}")
        }
        return ""
    }
}
