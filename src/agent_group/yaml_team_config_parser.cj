/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.agent_group

import std.collection.ArrayList
import std.fs.{File, Path}
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString}
import yaml4cj.yaml.decode
import magic.skill.infrastructure.utils.YamlUtils
import magic.log.LogUtils

public class YamlTeamConfigParser {
    public init() {}

    public func parseFromFile(filePath: String): Option<TeamConfig> {
        try {
            let bytes = File.readFrom(filePath)
            let content = String.fromUtf8(bytes)
            return parseFromString(content)
        } catch (e: Exception) {
            LogUtils.error("[YamlTeamConfigParser] Failed to read file: ${filePath}, error: ${e.message}")
            return None
        }
    }

    public func parseFromString(content: String): Option<TeamConfig> {
        try {
            let yamlBytes = content.toArray()
            let parsedYaml = decode(yamlBytes)

            if (parsedYaml is JsonObject) {
                let jsonObj = (parsedYaml as JsonObject).getOrThrow()
                return TeamConfig.fromJsonValue(jsonObj)
            }
            return None
        } catch (e: Exception) {
            LogUtils.error("[YamlTeamConfigParser] Failed to parse YAML content: ${e.message}")
            return None
        }
    }

    public func validate(config: TeamConfig): TeamConfigValidationResult {
        let result = TeamConfigValidationResult()

        if (config.name.isEmpty()) {
            result.valid = false
            result.errors.add("Team name is required")
        }

        if (config.manager.agentType.isEmpty()) {
            result.valid = false
            result.errors.add("Manager agent_type is required")
        }

        if (config.manager.skills.isEmpty()) {
            result.warnings.add("Manager has no skills configured")
        }

        for (i in 0..config.leaders.size) {
            let leader = config.leaders[i]
            if (leader.agentType.isEmpty()) {
                result.valid = false
                result.errors.add("Leader[${i}] agent_type is required")
            }
            if (leader.workers.isEmpty()) {
                result.warnings.add("Leader[${i}] has no workers configured")
            }
            for (j in 0..leader.workers.size) {
                let worker = leader.workers[j]
                if (worker.agentType.isEmpty()) {
                    result.valid = false
                    result.errors.add("Leader[${i}].Worker[${j}] agent_type is required")
                }
            }
        }

        if (config.leaders.isEmpty()) {
            result.warnings.add("No leaders configured, manager will handle all tasks directly")
        }

        return result
    }
}