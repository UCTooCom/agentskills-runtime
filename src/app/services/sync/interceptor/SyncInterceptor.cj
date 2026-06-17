package magic.app.services.sync.interceptor

import f_aspect.*
import f_aspect.macros.*
import f_bean.{BeanFactory, BeanMeta}
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
            let entityId = extractEntityId(result)
            if (entityId.isEmpty()) {
                return result
            }
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
        } catch (e: Exception) {
            LogUtils.error("SyncInterceptor", "after failed: ${e.message}")
        }
        return result
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
}
