/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

import f_orm.*
import magic.app.dao.uctoo.AgentSkillsDAO
import magic.app.models.uctoo.AgentSkillsPO
import magic.log.LogUtils

import std.sync.Mutex
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonBool}
import plugin_spi.PluginEventBus

/**
 * PluginSyncBridge - 插件运行态同步桥（PS-T018，design.md §2.3）
 *
 * 订阅 PluginEventBus 生命周期事件，把插件运行态回写 agent_skills 表：
 * - plugin.activated   -> runtime_status = active
 * - plugin.deactivated -> runtime_status = inactive
 * - plugin.error       -> runtime_status = error（lastError 一并落库）
 * - plugin.unloaded    -> 仅记日志（deactivated 已落库，避免冗余写）
 *
 * 单向红线：只做 内存 -> 库 回写，不提供任何 库 -> plugin.yaml 路径。
 * 观测面非控制面：回写失败只记日志（尽力标记 sync_status=error），
 * 绝不阻断插件生命周期。
 * agent_skills 无对应行时跳过（等待存量 SyncManager 首扫建行后再回写）。
 *
 * 包依赖说明：magic.plugin -> magic.app.dao.uctoo / magic.app.models.uctoo
 * 为子包级依赖（与既有 magic.plugin -> magic.app.core.router 同构），
 * 两者均不依赖 magic.plugin，无循环。
 */
public class PluginSyncBridge {
    private let mutex = Mutex()

    public init() {}

    /**
     * 订阅插件生命周期事件（须在 PluginHostManager.loadAll 之前调用）
     */
    public func bind(eventBus: PluginEventBus): Unit {
        eventBus.subscribe("plugin-sync-bridge", "plugin.activated", { payload =>
            this.writeRuntimeState(this.extractField(payload, "name"), "active")
            JsonString("ok")
        })
        eventBus.subscribe("plugin-sync-bridge", "plugin.deactivated", { payload =>
            this.writeRuntimeState(this.extractField(payload, "name"), "inactive")
            JsonString("ok")
        })
        eventBus.subscribe("plugin-sync-bridge", "plugin.error", { payload =>
            let name = this.extractField(payload, "name")
            let errorText = this.extractField(payload, "error")
            this.writeRuntimeState(name, "error", errorMessage: Some(errorText))
            JsonString("ok")
        })
        eventBus.subscribe("plugin-sync-bridge", "plugin.unloaded", { payload =>
            LogUtils.info("[PluginSyncBridge] plugin unloaded: ${this.extractField(payload, "name")}")
            JsonString("ok")
        })
    }

    /**
     * 状态回写：runtime_status 落库（按 name 匹配行；无行跳过）
     *
     * 失败降级：异常只记日志并尽力标记 sync_status=error，不影响调用方
     */
    public func writeRuntimeState(name: String, runtimeStatus: String, errorMessage!: Option<String> = None): Unit {
        if (name.isEmpty()) {
            LogUtils.error("[PluginSyncBridge] writeRuntimeState skipped: empty plugin name")
            return
        }
        synchronized(this.mutex) {
            try {
                match (ORM.executor() as AgentSkillsDAO) {
                    case Some(dao) =>
                        match (this.findByName(dao, name)) {
                            case Some(skill) =>
                                skill.runtimeStatus = Some(runtimeStatus)
                                if (errorMessage.isSome()) {
                                    skill.lastError = errorMessage
                                }
                                dao.updateAgentSkills(skill)
                                LogUtils.info(
                                    "[PluginSyncBridge] runtime_status='${runtimeStatus}' written for '${name}'")
                            case None =>
                                LogUtils.info(
                                    "[PluginSyncBridge] no agent_skills row for '${name}', skip (waiting for first sync scan)")
                        }
                    case None =>
                        LogUtils.error("[PluginSyncBridge] AgentSkillsDAO unavailable, skip writeback")
                }
            } catch (e: Exception) {
                LogUtils.error("[PluginSyncBridge] writeback failed for '${name}': ${e.message}")
                this.markSyncError(name)
            }
        }
    }

    /**
     * 元数据合并：fragment 键读-改-写合并进 extra_metadata（保留其他键，带 plugin 标记）
     *
     * 返回是否成功落库（无行/异常返回 false，不抛出）
     */
    public func mergePluginMetadata(name: String, fragment: JsonObject): Bool {
        synchronized(this.mutex) {
            try {
                match (ORM.executor() as AgentSkillsDAO) {
                    case Some(dao) =>
                        match (this.findByName(dao, name)) {
                            case Some(skill) =>
                                let merged = this.mergeExtraMetadata(skill.extraMetadata, fragment)
                                skill.extraMetadata = Some(merged.toString())
                                dao.updateAgentSkills(skill)
                                LogUtils.info("[PluginSyncBridge] extra_metadata merged for '${name}'")
                                return true
                            case None =>
                                LogUtils.info(
                                    "[PluginSyncBridge] no agent_skills row for '${name}', skip metadata merge")
                                return false
                        }
                    case None =>
                        LogUtils.error("[PluginSyncBridge] AgentSkillsDAO unavailable, skip metadata merge")
                        return false
                }
            } catch (e: Exception) {
                LogUtils.error("[PluginSyncBridge] metadata merge failed for '${name}': ${e.message}")
                return false
            }
        }
    }

    /// 按 name 定位未软删除的 agent_skills 行
    private func findByName(dao: AgentSkillsDAO, name: String): Option<AgentSkillsPO> {
        let skills = dao.listAllAgentSkills()
        for (skill in skills) {
            if (skill.name == name && skill.deletedAt.isNone()) {
                return Some(skill)
            }
        }
        return None
    }

    /// 合并 extra_metadata（原值非法 JSON 时放弃保留、整体重建）
    private func mergeExtraMetadata(existing: Option<String>, fragment: JsonObject): JsonObject {
        let target = JsonObject()
        match (existing) {
            case Some(raw) =>
                if (!raw.isEmpty()) {
                    try {
                        let parsed = JsonValue.fromStr(raw)
                        if (parsed is JsonObject) {
                            let obj = parsed.asObject()
                            for ((k, v) in obj.getFields()) {
                                target.put(k, v)
                            }
                        }
                    } catch (_: Exception) {
                        LogUtils.info("[PluginSyncBridge] extra_metadata not valid JSON, rebuild")
                    }
                }
            case None => ()
        }
        for ((k, v) in fragment.getFields()) {
            target.put(k, v)
        }
        target.put("plugin", JsonBool(true))
        return target
    }

    /// 回写失败时尽力标记 sync_status=error（再失败仅记日志）
    private func markSyncError(name: String): Unit {
        try {
            match (ORM.executor() as AgentSkillsDAO) {
                case Some(dao) =>
                    match (this.findByName(dao, name)) {
                        case Some(skill) =>
                            skill.syncStatus = Some("error")
                            dao.updateAgentSkills(skill)
                        case None => ()
                    }
                case None => ()
            }
        } catch (e2: Exception) {
            LogUtils.error("[PluginSyncBridge] mark sync_status=error also failed: ${e2.message}")
        }
    }

    /// 从事件 payload 提取字符串字段（缺失/非字符串返回空串）
    private func extractField(payload: JsonValue, field: String): String {
        if (payload is JsonObject) {
            let obj = payload.asObject()
            match (obj.get(field)) {
                case Some(v) =>
                    match (v) {
                        case jStr: JsonString => return jStr.getValue()
                        case _ => ()
                    }
                case None => ()
            }
        }
        return ""
    }
}
