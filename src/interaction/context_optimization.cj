/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.interaction

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonBool}
import magic.log.LogUtils

public class CompressionLayer {
    public var name: String = ""
    public var priority: Int64 = 0
    public var enabled: Bool = true

    public init() {}
}

public class ContextCompressionPipeline {
    private let _layers: ArrayList<CompressionLayer>
    private let _compressFn: (String, String) -> String

    public init(compressFn!: (String, String) -> String) {
        _layers = ArrayList<CompressionLayer>()
        _compressFn = compressFn
        initDefaultLayers()
    }

    private func initDefaultLayers(): Unit {
        let l1 = CompressionLayer()
        l1.name = "deduplication"
        l1.priority = 1
        _layers.add(l1)

        let l2 = CompressionLayer()
        l2.name = "summarization"
        l2.priority = 2
        _layers.add(l2)

        let l3 = CompressionLayer()
        l3.name = "abstraction"
        l3.priority = 3
        _layers.add(l3)

        let l4 = CompressionLayer()
        l4.name = "extraction"
        l4.priority = 4
        _layers.add(l4)

        let l5 = CompressionLayer()
        l5.name = "token_reduction"
        l5.priority = 5
        _layers.add(l5)
    }

    public func compress(context: String): String {
        var result = context
        for (layer in _layers) {
            if (!layer.enabled) { continue }
            result = _compressFn(layer.name, result)
            LogUtils.info("[ContextCompression] Applied layer: ${layer.name}, length: ${result.size.toString()}")
        }
        result
    }

    public func getLayers(): ArrayList<CompressionLayer> {
        _layers
    }

    public func enableLayer(name: String): Unit {
        for (layer in _layers) {
            if (layer.name == name) { layerG(layer) }
        }
    }

    private func layerG(l: CompressionLayer): Unit { l.enabled = true }

    public func disableLayer(name: String): Unit {
        for (layer in _layers) {
            if (layer.name == name) { layerD(layer) }
        }
    }

    private func layerD(l: CompressionLayer): Unit { l.enabled = false }
}

public class PromptCacheEntry {
    public var key: String = ""
    public var value: String = ""
    public var isSacred: Bool = false
    public var createdAt: DateTime = DateTime.now()
    public var lastAccessedAt: DateTime = DateTime.now()
    public var accessCount: Int64 = 0

    public init() {}
}

public class PromptCache {
    private var _cache: HashMap<String, PromptCacheEntry>
    private let _maxSize: Int64

    public init(maxSize!: Int64 = 100) {
        _cache = HashMap<String, PromptCacheEntry>()
        _maxSize = maxSize
    }

    public func get(key: String): Option<String> {
        if (let Some(entry) <- _cache.get(key)) {
            entry.lastAccessedAt = DateTime.now()
            entry.accessCount = entry.accessCount + 1
            return Some(entry.value)
        }
        None<String>
    }

    public func put(key: String, value: String, sacred!: Bool = false): Unit {
        if (let Some(existing) <- _cache.get(key)) {
            if (existing.isSacred && !sacred) {
                LogUtils.info("[PromptCache] Cannot overwrite sacred entry: ${key}")
                return
            }
            existing.value = value
            existing.isSacred = sacred
            existing.lastAccessedAt = DateTime.now()
            return
        }

        if (Int64(_cache.size) >= _maxSize) {
            evictOne()
        }

        let entry = PromptCacheEntry()
        entry.key = key
        entry.value = value
        entry.isSacred = sacred
        _cache.add(key, entry)
    }

    public func markSacred(key: String): Unit {
        if (let Some(entry) <- _cache.get(key)) {
            entry.isSacred = true
        }
    }

    public func invalidate(key: String): Bool {
        if (let Some(entry) <- _cache.get(key)) {
            if (entry.isSacred) {
                LogUtils.info("[PromptCache] Cannot invalidate sacred entry: ${key}")
                return false
            }
            _cache.remove(key)
            return true
        }
        false
    }

    public func clear(): Unit {
        let sacredEntries = HashMap<String, PromptCacheEntry>()
        for ((k, entry) in _cache) {
            if (entry.isSacred) { sacredEntries.add(k, entry) }
        }
        _cache = HashMap<String, PromptCacheEntry>()
        for ((k, entry) in sacredEntries) {
            _cache.add(k, entry)
        }
        LogUtils.info("[PromptCache] Cache cleared, preserved ${sacredEntries.size.toString()} sacred entries")
    }

    public func size(): Int64 {
        Int64(_cache.size)
    }

    private func evictOne(): Unit {
        var oldestKey = ""
        var oldestTime = DateTime.now()
        var found = false
        for ((k, entry) in _cache) {
            if (entry.isSacred) { continue }
            if (!found || entry.lastAccessedAt < oldestTime) {
                oldestKey = k
                oldestTime = entry.lastAccessedAt
                found = true
            }
        }
        if (found && oldestKey.size > 0) {
            _cache.remove(oldestKey)
        }
    }
}