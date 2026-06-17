/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.crontab

import magic.app.services.crontab.model.TriggerType
import magic.app.services.uctoo.CrontabService
import magic.app.models.uctoo.CrontabPO
import magic.app.core.response.APIResult
import magic.log.LogUtils
import std.time.DateTime

public class CrontabSchedulerService {
    private let crontabService = CrontabService()

    public init() {}

    public func createAndSchedule(entity: CrontabPO, creatorId: String): APIResult<CrontabPO> {
        let result = crontabService.create(entity, creatorId)
        if (result.success) {
            if (let Some(data) <- result.data) {
                match (SchedulerEngine.instance) {
                    case Some(engine) =>
                        engine.reloadTask(data.id)
                    case None =>
                        LogUtils.error("CrontabSchedulerService", "调度引擎未初始化, 任务已创建但未注册到调度器")
                }
            }
        }
        result
    }

    public func updateAndReschedule(entityId: String, entity: CrontabPO): APIResult<CrontabPO> {
        let result = crontabService.update(entityId, entity)
        if (result.success) {
            match (SchedulerEngine.instance) {
                case Some(engine) =>
                    engine.reloadTask(entityId)
                case None =>
                    LogUtils.error("CrontabSchedulerService", "调度引擎未初始化, 任务已更新但未重新加载到调度器")
            }
        }
        result
    }

    public func deleteAndUnschedule(entityId: String, force: Bool): APIResult<Bool> {
        if (crontabService.isSystemTask(entityId)) {
            return APIResult<Bool>(false, "系统任务不允许删除")
        }

        let result = crontabService.delete(entityId, force)
        if (result.success) {
            match (SchedulerEngine.instance) {
                case Some(engine) =>
                    engine.removeTask(entityId)
                case None =>
                    LogUtils.error("CrontabSchedulerService", "调度引擎未初始化")
            }
        }
        result
    }

    public func pauseTask(entityId: String): APIResult<CrontabPO> {
        let existing = crontabService.getById(entityId)
        if (!existing.success) {
            return APIResult<CrontabPO>(false, "任务不存在")
        }
        let entity = existing.data.getOrThrow()
        if (entity.groupName.isEmpty()) {
            entity.groupName = "1"
        }
        if (entity.groupName == "2") {
            return APIResult<CrontabPO>(false, "系统任务不允许暂停")
        }
        if (entity.status != 1) {
            return APIResult<CrontabPO>(false, "任务已处于禁用状态")
        }

        entity.status = 2
        entity.updatedAt = DateTime.now()
        let updateResult = crontabService.update(entityId, entity)
        if (updateResult.success) {
            match (SchedulerEngine.instance) {
                case Some(engine) =>
                    engine.removeTask(entityId)
                case None =>
                    LogUtils.error("CrontabSchedulerService", "调度引擎未初始化")
            }
            return APIResult<CrontabPO>(entity)
        }
        APIResult<CrontabPO>(false, "暂停失败")
    }

    public func resumeTask(entityId: String): APIResult<CrontabPO> {
        let existing = crontabService.getById(entityId)
        if (!existing.success) {
            return APIResult<CrontabPO>(false, "任务不存在")
        }
        let entity = existing.data.getOrThrow()
        if (entity.status == 1) {
            return APIResult<CrontabPO>(false, "任务已处于启用状态")
        }

        entity.status = 1
        entity.updatedAt = DateTime.now()
        let updateResult = crontabService.update(entityId, entity)
        if (updateResult.success) {
            match (SchedulerEngine.instance) {
                case Some(engine) =>
                    engine.reloadTask(entityId)
                case None =>
                    LogUtils.error("CrontabSchedulerService", "调度引擎未初始化")
            }
            return APIResult<CrontabPO>(entity)
        }
        APIResult<CrontabPO>(false, "恢复失败")
    }

    public func triggerTask(entityId: String): APIResult<Bool> {
        let existing = crontabService.getById(entityId)
        if (!existing.success) {
            return APIResult<Bool>(false, "任务不存在")
        }

        match (SchedulerEngine.instance) {
            case Some(engine) =>
                engine.triggerTask(entityId, TriggerType.Manual)
                return APIResult<Bool>(true)
            case None =>
                return APIResult<Bool>(false, "调度引擎未初始化")
        }
    }
}