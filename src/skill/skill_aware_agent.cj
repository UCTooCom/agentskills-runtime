/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import magic.agent.base.BaseAgent
import magic.core.model.ChatModel
import magic.core.agent.{AgentExecutor, AgentRequest, AgentResponse}
import magic.core.tool.{ToolManager, ToolParameter}
import magic.core.memory.Memory
import magic.interaction.EventHandlerManager
import magic.jsonable.TypeSchema
import magic.tool.{SimpleToolManager, BuiltinToolsRegistry, GetSkillContentTool}
import magic.core.skill.SkillManager
import magic.log.LogUtils
import stdx.encoding.json.JsonObject

import std.collection.{ArrayList, HashMap}

public class SkillAwareAgent <: BaseAgent {
    private var _skillManagerVar: SkillManager
    private let _skillToolAdapters: HashMap<String, SkillToToolAdapter> = HashMap<String, SkillToToolAdapter>()
    // 存储前端注册的工具
    private let _frontendToolAdapters: HashMap<String, FrontendToolAdapter> = HashMap<String, FrontendToolAdapter>()

    public init(
        skillManager!: SkillManager,
        model!: ChatModel,
        executor!: AgentExecutor,
        name!: String = "Skill Aware Agent",
        description!: String = "An agent that can automatically select and execute skills",
        systemPrompt!: String = "",
        memory!: Option<Memory> = None<Memory>,
        eventHandlerManager!: Option<EventHandlerManager> = None<EventHandlerManager>
    ) {
        super(
            model: model,
            name: name,
            description: description,
            systemPrompt: systemPrompt,
            toolManager: SimpleToolManager(),
            executor: Some(executor),
            memory: memory,
            eventHandlerManager: eventHandlerManager
        )
        
        this._skillManagerVar = skillManager
        _registerSkillsAsTools()
    }

    private func _registerSkillsAsTools(): Unit {
        LogUtils.info("Registering built-in tools")
        try {
            BuiltinToolsRegistry.registerAll(_toolManager)
            GetSkillContentTool.setSkillManager(_skillManagerVar)
            LogUtils.info("All builtin tools registered via BuiltinToolsRegistry")
        } catch (ex: Exception) {
            LogUtils.error("Failed to register builtin tools: ${ex.message}")
        }
        
        let skills = _skillManagerVar.availableSkills.values().toArray()
        LogUtils.info("Registering ${skills.size.toString()} skills as tools for agent")
        
        for (skill in skills) {
            try {
                let adapter = SkillToToolAdapter(skill: skill)
                _skillToolAdapters.add(skill.name, adapter)
                _toolManager.addTool(adapter)
                LogUtils.info("Registered skill '${skill.name}' as tool")
            } catch (ex: Exception) {
                LogUtils.error("Failed to register skill '${skill.name}' as tool: ${ex.message}")
            }
        }
    }

    public func refreshSkills(): Unit {
        LogUtils.info("Refreshing skills and re-registering as tools")
        _toolManager.clear()
        _skillToolAdapters.clear()
        _registerSkillsAsTools()
    }

    public prop skillManager: SkillManager {
        get() { _skillManagerVar }
    }

    public prop registeredSkills: Array<String> {
        get() { _skillToolAdapters.keys().toArray() }
    }

    /**
     * 提示词 profile 候选链：`<已注册技能名（逗号分隔）>,<agent 名>`。
     *
     * ── 为什么需要它 ────────────────────────────────────────────────
     * `SimpleToolCompactor` 原先只拿 `agent.name` 当 profile（实测值是 `MainAgent`），
     * 而长程任务的定制摘要提示词文件叫 `tool-summarize.user.long-running-task.md`
     * ——技能名与 agent 名对不上，这个文件**从未命中**：2026-09-15 的实测日志里
     * 「命中 profile 摘要提示词」出现 0 次，全部回落到内置通用措辞
     * （`Summarize the tool execution result.`）。结果就是长程任务跨回合压缩时
     * 没有强制保留「目标 / 进度 / 已完成与待办 / 失败项 / 下一步」，
     * 上下文越跑越薄，最终在半途耗尽步数。
     *
     * 这里把已注册的技能名前置，让技能能声明自己的摘要提示词。
     * 多个候选都有文件时**靠前者优先**；`HashMap` 迭代序不保证，
     * 因此同一个 agent 上不要给两个技能配同用途的提示词文件。
     */
    public func promptProfileCandidates(): String {
        var chain = ""
        for (skillName in this.registeredSkills) {
            if (skillName.isEmpty()) {
                continue
            }
            chain = if (chain.isEmpty()) { skillName } else { "${chain},${skillName}" }
        }
        if (!this.name.isEmpty()) {
            chain = if (chain.isEmpty()) { this.name } else { "${chain},${this.name}" }
        }
        chain
    }

    /**
     * 注册前端工具到 agent
     * @param name 工具名称
     * @param title 工具标题
     * @param description 工具描述
     * @param route 对应的前端页面路由
     * @param inputSchema 输入参数 schema
     */
    public func addFrontendTool(
        name: String,
        title: ?String,
        description: ?String,
        route: ?String,
        inputSchema: ?JsonObject
    ): Unit {
        // 如果已存在同名工具，先移除
        if (_frontendToolAdapters.get(name).isSome()) {
            let existing = _frontendToolAdapters.get(name).getOrThrow()
            _toolManager.delTool(existing)
            _frontendToolAdapters.remove(name)
        }

        // 创建前端工具适配器
        let adapter = FrontendToolAdapter(name, title, description, route, inputSchema)

        // 添加到工具管理器
        _frontendToolAdapters.add(name, adapter)
        _toolManager.addTool(adapter)

        LogUtils.info("Registered frontend tool: ${name}")
    }

    /**
     * 移除前端工具
     * @param name 工具名称
     */
    public func removeFrontendTool(name: String): Unit {
        if (_frontendToolAdapters.get(name).isSome()) {
            let adapter = _frontendToolAdapters.get(name).getOrThrow()
            _toolManager.delTool(adapter)
            _frontendToolAdapters.remove(name)
            LogUtils.info("Unregistered frontend tool: ${name}")
        }
    }

    /**
     * 清空所有前端工具
     */
    public func clearFrontendTools(): Unit {
        for (name in _frontendToolAdapters.keys()) {
            if (let Some(adapter) <- _frontendToolAdapters.get(name)) {
                _toolManager.delTool(adapter)
            }
        }
        _frontendToolAdapters.clear()
        LogUtils.info("Cleared all frontend tools")
    }

    /**
     * 获取所有已注册的前端工具名称
     */
    public prop registeredFrontendTools: Array<String> {
        get() { _frontendToolAdapters.keys().toArray() }
    }
}
