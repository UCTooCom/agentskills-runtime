/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.model.channel

import magic.core.model.ChatModel
import std.collection.HashMap

/**
 * 实例缓存条目。
 */
private struct InstanceEntry {
    let model: ChatModel
    let revision: Int64

    public init(model: ChatModel, revision: Int64) {
        this.model = model
        this.revision = revision
    }
}

/**
 * ModelInstanceCache — 按 (通道编码, 模型ID) 缓存 ChatModel 实例。
 *
 * 设计（design.md §4 / REQ-DMC-018）：热路径零重建；通道 revision 变化 → 下一请求换新实例。
 * 真正的「进行中会话 drain」（V4）由会话边界持有旧实例实现，本缓存只负责 revision 比对增量替换。
 */
public class ModelInstanceCache {
    private static let INSTANCE = ModelInstanceCache()
    public static func shared(): ModelInstanceCache {
        INSTANCE
    }

    private var cache: HashMap<String, InstanceEntry> = HashMap<String, InstanceEntry>()

    public func getOrBuild(code: String, modelId: String, revision: Int64, buildFn: () -> ChatModel): ChatModel {
        let key = "${code}:${modelId}"
        if (let Some(entry) <- cache.get(key)) {
            if (entry.revision >= revision) {
                return entry.model
            }
        }
        let inst = buildFn()
        cache.add(key, InstanceEntry(inst, revision))
        return inst
    }

    /**
     * 注册表整体刷新后的兜底清空（正常靠 revision 比对增量替换）。
     */
    public func purge(): Unit {
        cache.clear()
    }
}
