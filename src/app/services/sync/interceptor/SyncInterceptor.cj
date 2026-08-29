package magic.app.services.sync.interceptor

import f_aspect.*
import f_aspect.macros.*
import f_bean.{BeanFactory, BeanMeta}
import magic.app.models.uctoo.{AgentsPO, AgentSkillsPO}
import magic.app.services.sync.SyncManager
import magic.app.services.sync.context.SyncContext
import magic.app.services.sync.model.TriggerSource
import magic.log.LogUtils

@AspectRoute[ExecutionRouteRule("magic.app.dao.uctoo.*", "insert*|update*", "**", "*") & !WithinRouteRule("magic.app.services.sync.*")]
@BeanMeta
public class SyncInterceptor <: Aspect {
    static init() {
        BeanFactory.instance.register<SyncInterceptor>({ => SyncInterceptor() })
    }

    private init() {}

    public func after(funcInfo: InvocationFuncInfo, result: Any): Any {
        if (SyncContext.isPresent()) {
            return result
        }
        try {
            let className = funcInfo.typeInfo.name
            let entityType = determineEntityType(className)
            if (entityType.isEmpty()) {
                return result
            }
            // insert* 返回 UUID 字符串（可直接提取）；update* 返回 Int64（影响行数），
            // 需从方法入参 funcInfo.args[0]（即被更新的 PO 实体）读取其 id 字段。
            let entityId = extractEntityId(result)
            if (entityId.isEmpty()) {
                let idFromArgs = extractIdFromArgs(funcInfo.args)
                if (idFromArgs.isEmpty()) {
                    return result
                }
                this.dispatchSync(entityType, idFromArgs)
                return result
            }
            this.dispatchSync(entityType, entityId)
        } catch (e: Exception) {
            LogUtils.error("SyncInterceptor", "after failed - ${e.message}")
        }
        return result
    }

    private func dispatchSync(entityType: String, entityId: String): Unit {
        match (SyncManager.instance) {
            case Some(manager) =>
                spawn {
                    try {
                        manager.syncToFileSystem(entityType, entityId, TriggerSource.Business)
                    } catch (e: Exception) {
                        LogUtils.error("SyncInterceptor", "async sync failed - ${e.message}")
                    }
                }
            case None => ()
        }
    }

    private func determineEntityType(className: String): String {
        if (className.contains("AgentsDAO")) {
            return "agent"
        }
        if (className.contains("AgentSkillsDAO")) {
            return "agent_skill"
        }
        return ""
    }

    private func extractEntityId(result: Any): String {
        let strResult = result as String
        match (strResult) {
            case Some(id) => return id
            case None => return ""
        }
    }

    /// 从 DAO 方法入参提取 PO 实体的 id 字段（update* 路径：返回值是 Int64 影响行数，无法直接用）
    /// AgentsPO/AgentSkillsPO 均有 public var id: String，用 as 转换后直接读取
    private func extractIdFromArgs(args: Array<Any>): String {
        if (args.size == 0) {
            return ""
        }
        let entity = args[0]
        match (entity as AgentsPO) {
            case Some(po) => return po.id
            case None => ()
        }
        match (entity as AgentSkillsPO) {
            case Some(po) => return po.id
            case None => ()
        }
        return ""
    }
}
