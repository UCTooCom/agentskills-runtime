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
import magic.tool.{SimpleToolManager, BuiltinToolsRegistry}
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
