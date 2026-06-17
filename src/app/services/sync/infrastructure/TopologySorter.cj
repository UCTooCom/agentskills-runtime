package magic.app.services.sync.infrastructure

import std.collection.{HashMap, HashSet, ArrayList}
import magic.app.services.sync.handler.SyncHandler
import magic.log.LogUtils

public class TopologySorter {
    public static func sort(handlers: Array<SyncHandler>): Array<SyncHandler> {
        if (handlers.size <= 1) {
            return handlers
        }
        let handlerMap = HashMap<String, SyncHandler>()
        for (h in handlers) {
            handlerMap.add(h.entityType, h)
        }
        let sorted = ArrayList<SyncHandler>()
        let visited = HashSet<String>()
        for (h in handlers) {
            visit(h, handlerMap, visited, sorted)
        }
        return sorted.toArray()
    }

    private static func visit(
        handler: SyncHandler,
        handlerMap: HashMap<String, SyncHandler>,
        visited: HashSet<String>,
        sorted: ArrayList<SyncHandler>
    ): Unit {
        let entityType = handler.entityType
        if (visited.contains(entityType)) {
            return
        }
        visited.add(entityType)
        for (dep in handler.dependencies) {
            if (let Some(depHandler) <- handlerMap.get(dep)) {
                visit(depHandler, handlerMap, visited, sorted)
            } else {
                LogUtils.warn("TopologySorter: dependency '${dep}' not found for '${entityType}'")
            }
        }
        sorted.add(handler)
    }

    public static func detectCircularDependency(handlers: Array<SyncHandler>): Option<Array<String>> {
        let handlerMap = HashMap<String, SyncHandler>()
        for (h in handlers) {
            handlerMap.add(h.entityType, h)
        }
        let visiting = HashSet<String>()
        for (h in handlers) {
            let result = detectCycle(h.entityType, handlerMap, visiting, HashSet<String>())
            if (result.isSome()) {
                return result
            }
        }
        return None
    }

    private static func detectCycle(
        entityType: String,
        handlerMap: HashMap<String, SyncHandler>,
        visiting: HashSet<String>,
        path: HashSet<String>
    ): Option<Array<String>> {
        if (path.contains(entityType)) {
            let cycleArr = ArrayList<String>()
            for (s in path) {
                cycleArr.add(s)
            }
            cycleArr.add(entityType)
            return Some(cycleArr.toArray())
        }
        if (visiting.contains(entityType)) {
            return None
        }
        visiting.add(entityType)
        if (let Some(handler) <- handlerMap.get(entityType)) {
            let newPath = HashSet<String>()
            for (s in path) {
                newPath.add(s)
            }
            newPath.add(entityType)
            for (dep in handler.dependencies) {
                let result = detectCycle(dep, handlerMap, visiting, newPath)
                if (result.isSome()) {
                    return result
                }
            }
        }
        return None
    }
}