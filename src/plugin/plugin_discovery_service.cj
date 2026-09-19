/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

import std.collection.ArrayList
import std.fs.{exists, FileInfo, Directory}
import magic.log.LogUtils

/**
 * PluginDiscoveryService - 插件去中心化自动发现服务
 *
 * 复用 ProgressiveSkillLoader 的目录扫描框架，遍历技能基目录的子目录，
 * 自动发现 plugin.yaml 文件并解析为 PluginManifestEntry。
 * 与 SKILL.md 发现在同一目录扫描中完成，实现插件自完备描述 + 自动发现。
 *
 * 详见 design.md §5.5.2 插件去中心化自动发现机制。
 */
public class PluginDiscoveryService {

    public init() {}

    /**
     * 从技能基目录数组自动发现所有 plugin.yaml
     *
     * @param skillBaseDirectories 技能基目录路径数组（与 ProgressiveSkillLoader 同源）
     * @return PluginList 已按 order 排序的插件清单
     */
    public func discover(skillBaseDirectories: Array<String>): PluginList {
        let list = PluginList()

        for (baseDir in skillBaseDirectories) {
            if (!exists(baseDir)) {
                continue
            }

            let baseDirInfo = FileInfo(baseDir)
            if (!baseDirInfo.isDirectory()) {
                continue
            }

            let subdirs = ArrayList<String>()
            Directory.walk(baseDir) { fileInfo =>
                if (fileInfo.isDirectory() && fileInfo.path.toString() != baseDir) {
                    let startIdx = Int64(baseDir.size) + 1
                    let fullPathStr = fileInfo.path.toString()
                    let relativePath = if (startIdx < Int64(fullPathStr.size)) {
                        fullPathStr[startIdx..Int64(fullPathStr.size)]
                    } else {
                        ""
                    }
                    if (!relativePath.contains("/")) {
                        subdirs.add(fileInfo.path.toString())
                    }
                }
                return true
            }

            for (subdirPath in subdirs.toArray()) {
                let pluginYamlPath = "${subdirPath}/plugin.yaml"
                if (!exists(pluginYamlPath)) {
                    continue
                }
                match (PluginManifestEntry.fromPluginYaml(pluginYamlPath)) {
                    case Some(entry) =>
                        list.plugins.add(entry)
                        let modeStr = match (entry.mode) {
                            case PluginMode.Sync => "sync"
                            case PluginMode.Dylib => "dylib"
                            case PluginMode.Process => "process"
                        }
                        LogUtils.info("[PluginDiscoveryService] discovered plugin: ${entry.name} (mode=${modeStr}, enabled=${entry.enabled})")
                    case None =>
                        LogUtils.warn("[PluginDiscoveryService] failed to parse plugin.yaml: ${pluginYamlPath}")
                }
            }
        }

        list.sortByOrder()
        LogUtils.info("[PluginDiscoveryService] discovery complete: ${list.plugins.size} plugins found, ${list.enabledCount()} enabled")
        return list
    }
}