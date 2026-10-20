/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

import std.collection.{ArrayList, HashMap}
import std.convert.*
import magic.log.LogUtils

public class SkillParallelDeclarationParser {

    public static func parseLoadPolicy(metadata: HashMap<String, String>): LoadPolicy {
        let value = metadata.get("load_policy")
        if (value.isSome()) {
            let v = value.getOrThrow()
            if (v == "always_on") {
                return LoadPolicy.AlwaysOn
            } else if (v == "conditional") {
                return LoadPolicy.Conditional
            } else {
                return LoadPolicy.OnDemand
            }
        }
        return LoadPolicy.OnDemand
    }

    public static func parsePriority(metadata: HashMap<String, String>): SkillPriority {
        let value = metadata.get("priority")
        if (value.isSome()) {
            let v = value.getOrThrow()
            if (v == "high") {
                return SkillPriority.High
            } else if (v == "low") {
                return SkillPriority.Low
            } else {
                return SkillPriority.Medium
            }
        }
        return SkillPriority.Medium
    }

    public static func parseSkillType(metadata: HashMap<String, String>): SkillType {
        let value = metadata.get("skill_type")
        if (value.isSome()) {
            let v = value.getOrThrow()
            if (v == "profile") {
                return SkillType.Profile
            } else if (v == "capability") {
                return SkillType.Capability
            } else {
                LogUtils.warn("SkillParallelDeclarationParser: unknown skill_type '${v}', defaulting to capability")
                return SkillType.Capability
            }
        }
        return SkillType.Capability
    }

    public static func parseDependsOn(metadata: HashMap<String, String>): ArrayList<String> {
        return parseListField(metadata, "depends_on")
    }

    public static func parseConflictsWith(metadata: HashMap<String, String>): ArrayList<String> {
        return parseListField(metadata, "conflicts_with")
    }

    public static func parseContextBudgetTokens(metadata: HashMap<String, String>): Int64 {
        let value = metadata.get("context_budget_tokens")
        if (value.isSome()) {
            return Int64.parse(value.getOrThrow())
        }
        return 2000
    }

    public static func parseCompatibleWith(metadata: HashMap<String, String>): ArrayList<String> {
        return parseListField(metadata, "compatible_with")
    }

    private static func parseListField(metadata: HashMap<String, String>, fieldName: String): ArrayList<String> {
        let result = ArrayList<String>()
        let value = metadata.get(fieldName)
        if (value.isSome()) {
            let parts = value.getOrThrow().split(",")
            for (part in parts) {
                let trimmed = part.trimAscii()
                if (!trimmed.isEmpty()) {
                    result.add(trimmed)
                }
            }
        }
        return result
    }

    public static func parseDistributionMetadata(metadata: HashMap<String, String>): DistributionMetadata {
        let syncScope = parseSyncScope(metadata.get("sync_scope"), SyncScope.NodeLocal)
        let authoritative = parseBoolField(metadata.get("authoritative"), false)
        let conflictPolicy = parseConflictPolicy(metadata.get("conflict_policy"), ConflictPolicy.LastWriteWins)
        let version = parseIntField(metadata.get("version"), 1)
        let etag = metadata.get("etag").getOrDefault({ => "" })
        return DistributionMetadata(
            syncScope: syncScope,
            authoritative: authoritative,
            conflictPolicy: conflictPolicy,
            version: version,
            etag: etag
        )
    }

    private static func parseSyncScope(value: Option<String>, default: SyncScope): SyncScope {
        if (value.isSome()) {
            let v = value.getOrThrow()
            if (v == "agent_owned") {
                return SyncScope.AgentOwned
            } else if (v == "user_owned") {
                return SyncScope.UserOwned
            } else if (v == "node_local") {
                return SyncScope.NodeLocal
            } else {
                LogUtils.warn("SkillParallelDeclarationParser: unknown sync_scope '${v}', defaulting to node_local")
                return default
            }
        }
        return default
    }

    private static func parseConflictPolicy(value: Option<String>, default: ConflictPolicy): ConflictPolicy {
        if (value.isSome()) {
            let v = value.getOrThrow()
            if (v == "last_write_wins") {
                return ConflictPolicy.LastWriteWins
            } else if (v == "merge") {
                return ConflictPolicy.Merge
            } else if (v == "manual") {
                return ConflictPolicy.Manual
            } else {
                LogUtils.warn("SkillParallelDeclarationParser: unknown conflict_policy '${v}', defaulting to last_write_wins")
                return default
            }
        }
        return default
    }

    private static func parseBoolField(value: Option<String>, default: Bool): Bool {
        if (value.isSome()) {
            let v = value.getOrThrow().toAsciiLower()
            if (v == "true" || v == "1" || v == "yes") {
                return true
            } else if (v == "false" || v == "0" || v == "no") {
                return false
            }
        }
        return default
    }

    private static func parseIntField(value: Option<String>, default: Int64): Int64 {
        if (value.isSome()) {
            let v = value.getOrThrow().trimAscii()
            if (!v.isEmpty()) {
                try {
                    return Int64.parse(v)
                } catch (e: Exception) {
                    LogUtils.warn("SkillParallelDeclarationParser: invalid int field '${v}', using default")
                }
            }
        }
        return default
    }
}