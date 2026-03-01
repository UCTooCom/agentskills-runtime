/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import magic.agent.base.BaseAgent
import magic.core.model.ChatModel
import magic.core.agent.{AgentExecutor, AgentRequest, AgentResponse}
import magic.core.tool.ToolManager
import magic.tool.SimpleToolManager
import magic.core.skill.SkillManager
import magic.log.LogUtils
import magic.tool.HttpTool

import std.collection.{ArrayList, HashMap}

public class SkillAwareAgent <: BaseAgent {
    private var _skillManagerVar: SkillManager
    private let _skillToolAdapters: HashMap<String, SkillToToolAdapter> = HashMap<String, SkillToToolAdapter>()

    public init(
        skillManager!: SkillManager,
        model!: ChatModel,
        executor!: AgentExecutor,
        name!: String = "Skill Aware Agent",
        description!: String = "An agent that can automatically select and execute skills",
        systemPrompt!: String = ""
    ) {
        super(
            model: model,
            name: name,
            description: description,
            systemPrompt: systemPrompt,
            toolManager: SimpleToolManager(),
            executor: Some(executor)
        )
        
        this._skillManagerVar = skillManager
        _registerSkillsAsTools()
    }

    private func _registerSkillsAsTools(): Unit {
        LogUtils.info("Registering built-in tools")
        try {
            let httpTool = HttpTool()
            _toolManager.addTool(httpTool)
            LogUtils.info("Registered built-in tool '${httpTool.name}'")
        } catch (ex: Exception) {
            LogUtils.error("Failed to register built-in HTTP tool: ${ex.message}")
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
}
