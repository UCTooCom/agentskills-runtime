/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

import std.fs.File
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray}
import yaml4cj.yaml.decode
import f_base.Result
import magic.log.LogUtils
import plugin_spi.PluginError

/**
 * PluginConfigParser - plugins.yaml 解析器
 *
 * 解析管线复用存量模式（参照 src/agent_group/yaml_team_config_parser.cj）：
 * yaml4cj.yaml.decode(bytes) -> JsonValue -> JsonObject -> getFields
 * -> 逐条 PluginManifestEntry.fromJsonValue
 *
 * JSON 解析器无法解析 YAML，故必须走 yaml4cj 通道。
 */
public class PluginConfigParser {
    public init() {}

    /**
     * 解析 plugins.yaml 文本内容为插件清单
     */
    public func parse(yamlContent: String): Result<PluginList, PluginError> {
        try {
            let yamlBytes = yamlContent.toArray()
            let parsedYaml = decode(yamlBytes)

            if (!(parsedYaml is JsonObject)) {
                return Err(PluginError.ConfigInvalid("root node must be a mapping"))
            }
            let jsonObj = (parsedYaml as JsonObject).getOrThrow()
            let fields = jsonObj.getFields()

            let list = PluginList()
            match (fields.get("plugins")) {
                case Some(pluginsVal) =>
                    if (!(pluginsVal is JsonArray)) {
                        return Err(PluginError.ConfigInvalid("'plugins' must be a list"))
                    }
                    let arr = (pluginsVal as JsonArray).getOrThrow()
                    for (i in 0..arr.size()) {
                        match (PluginManifestEntry.fromJsonValue(arr[i])) {
                            case Some(entry) => list.plugins.add(entry)
                            case None =>
                                return Err(PluginError.ConfigInvalid(
                                    "plugins[${i}] missing required field 'name' or 'className'"))
                        }
                    }
                case None =>
                    return Err(PluginError.ConfigInvalid("missing 'plugins' list"))
            }

            // 按声明顺序构建后统一按 order 排序（同序保持声明顺序）
            list.sortByOrder()
            return Ok(list)
        } catch (e: Exception) {
            LogUtils.error("[PluginConfigParser] failed to parse plugins.yaml: ${e.message}")
            return Err(PluginError.ConfigInvalid("yaml parse error: ${e.message}"))
        }
    }

    /**
     * 从文件路径解析插件清单
     */
    public func parseFromFile(path: String): Result<PluginList, PluginError> {
        try {
            let bytes = File.readFrom(path)
            let content = String.fromUtf8(bytes)
            return this.parse(content)
        } catch (e: Exception) {
            LogUtils.error("[PluginConfigParser] failed to read file: ${path}, error: ${e.message}")
            return Err(PluginError.ConfigInvalid("cannot read file: ${path}"))
        }
    }
}
