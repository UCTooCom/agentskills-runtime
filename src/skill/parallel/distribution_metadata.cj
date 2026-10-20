/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

import std.collection.HashMap

/**
 * 分发元数据（TG22/T089）。
 *
 * 描述技能在「分发/同步」维度的属性，用于 profile 类技能的跨端一致性管理：
 * - `syncScope`：分发作用域（AgentOwned / UserOwned / NodeLocal，MEMORY 类默认 NodeLocal）；
 * - `authoritative`：是否为权威副本（真源）；
 * - `conflictPolicy`：多端冲突解决策略；
 * - `version`：语义版本号，单调递增；
 * - `etag`：内容指纹，用于快速比对是否变更。
 */
public class DistributionMetadata {
    public var syncScope: SyncScope
    public var authoritative: Bool
    public var conflictPolicy: ConflictPolicy
    public var version: Int64
    public var etag: String

    public init(
        syncScope!: SyncScope = SyncScope.NodeLocal,
        authoritative!: Bool = false,
        conflictPolicy!: ConflictPolicy = ConflictPolicy.LastWriteWins,
        version!: Int64 = 1,
        etag!: String = ""
    ) {
        this.syncScope = syncScope
        this.authoritative = authoritative
        this.conflictPolicy = conflictPolicy
        this.version = version
        this.etag = etag
    }

    public func toMetadataMap(): HashMap<String, String> {
        let m = HashMap<String, String>()
        m.add("sync_scope", this.syncScope.toString())
        m.add("authoritative", if (this.authoritative) { "true" } else { "false" })
        m.add("conflict_policy", this.conflictPolicy.toString())
        m.add("version", this.version.toString())
        m.add("etag", this.etag)
        return m
    }
}
