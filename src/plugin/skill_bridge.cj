/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

import std.collection.{ArrayList, HashMap}
import std.fs.exists
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString}
import magic.core.skill.{Skill, SkillManager}
import magic.skill.application.SkillManagementService
import magic.log.LogUtils
import plugin_spi.PluginSkillBridge

/**
 * SkillBridge - 插件技能注册桥
 *
 * 复用存量技能管线（design.md v2.2 修订，见 review-report.md 问题#1）：
 * SkillManagementService.loadSkillsFromDirectory 已含 SKILL.md 解析
 * （YAML frontmatter）→ manifest 校验 → Skill 实例创建（SkillRegistry
 * 工厂 + BaseSkill 兜底）完整管线；本桥仅做"按插件目录"的包装与登记。
 *
 * 插件三维一体约定：插件目录（plugins/<name>/）可同时包含
 * plugin.yaml、SKILL.md、scripts/、references/ 等资产；
 * 无 SKILL.md 的插件按纯 Service 插件处理（注册数为 0）。
 */
public class SkillBridge <: PluginSkillBridge {
    private let skillManagementService: SkillManagementService
    private let skillManager: SkillManager

    /// 各插件成功注册的技能名登记（buildCapabilityCatalog 用）
    private let pluginSkills: HashMap<String, ArrayList<String>>

    public init(skillManagementService: SkillManagementService, skillManager: SkillManager) {
        this.skillManagementService = skillManagementService
        this.skillManager = skillManager
        this.pluginSkills = HashMap<String, ArrayList<String>>()
    }

    /**
     * 按插件目录加载技能并注册到 SkillManager
     *
     * 技能来源（两路互补，均走存量管线）：
     * 1. 插件目录根下的 SKILL.md（三维一体约定：plugins/<name>/SKILL.md，
     *    经 loadSkillFromPath 直载——loadSkillsFromDirectory 仅扫描子目录，
     *    无法覆盖根级文件）
     * 2. 插件子目录中的技能（plugins/<name>/<skill>/SKILL.md，
     *    经 loadSkillsFromDirectory 批量扫描）
     *
     * 两路均无命中时按纯 Service 插件处理（返回 0）
     *
     * 参数：
     *   - pluginDir: 插件目录路径
     *   - pluginName: 插件名（登记技能归属）
     *
     * 返回：成功注册的技能数量
     */
    public func registerPluginSkills(pluginDir: String, pluginName: String): Int64 {
        let registered = ArrayList<String>()

        // 1. 插件目录根下的 SKILL.md（三维一体主通道）
        let rootSkillMd = "${pluginDir}/SKILL.md"
        if (exists(rootSkillMd)) {
            match (this.skillManagementService.loadSkillFromPath(rootSkillMd)) {
                case Some(skill) => this.registerOne(skill, pluginName, registered)
                case None =>
                    LogUtils.error("[SkillBridge] plugin '${pluginName}' root SKILL.md parse failed: ${rootSkillMd}")
            }
        }

        // 2. 插件子目录中的技能（兼容多技能插件布局）
        let skills = this.skillManagementService.loadSkillsFromDirectory(pluginDir)
        for (skill in skills) {
            this.registerOne(skill, pluginName, registered)
        }

        if (registered.isEmpty()) {
            LogUtils.info("[SkillBridge] plugin '${pluginName}' has no skills (pure service plugin)")
            return 0
        }

        // 登记技能归属（幂等合并：重复注册名不重复登记）
        match (this.pluginSkills.get(pluginName)) {
            case Some(existing) =>
                for (name in registered) {
                    if (!existing.contains(name)) {
                        existing.add(name)
                    }
                }
            case None => this.pluginSkills[pluginName] = registered
        }
        return Int64(registered.size)
    }

    /**
     * 注册单个技能并登记归属（registerPluginSkills 内部复用）
     */
    private func registerOne(skill: Skill, pluginName: String, registered: ArrayList<String>): Unit {
        let ok = this.skillManagementService.registerSkill(skill, this.skillManager)
        if (ok) {
            registered.add(skill.name)
            LogUtils.info("[SkillBridge] plugin '${pluginName}' skill registered: ${skill.name}")
        } else {
            LogUtils.error("[SkillBridge] plugin '${pluginName}' skill register failed: ${skill.name}")
        }
    }

    /**
     * 生成插件能力目录条目（AI 可消费的 JSON 描述）
     *
     * 结构：{"plugin": <name>, "skills": [技能名...]}
     */
    public func buildCapabilityCatalog(pluginName: String): JsonValue {
        let obj = JsonObject()
        obj.put("plugin", JsonString(pluginName))
        let skillArr = JsonArray()
        match (this.pluginSkills.get(pluginName)) {
            case Some(names) =>
                for (name in names) {
                    skillArr.add(JsonString(name))
                }
            case None => ()
        }
        obj.put("skills", skillArr)
        return obj
    }

    /**
     * 注销插件时清理技能登记（不卸载技能本身，由 SkillManager 全局管理）
     */
    public func clearPluginSkills(pluginName: String): Unit {
        this.pluginSkills.remove(pluginName)
    }
}
