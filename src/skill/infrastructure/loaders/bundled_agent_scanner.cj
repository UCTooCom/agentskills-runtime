/*
 * Copyright (c) 2026. All rights reserved.
 */
package magic.skill.infrastructure.loaders

import std.fs.{exists, Directory}
import std.collection.ArrayList

/**
 * BundledAgentScanner 探测技能目录内的子 agent 声明文件。
 *
 * T-19（REQ-SDD-011「约定即注册」）：<skill-root>/agents/ 目录下每个 .md 声明文件即一个 bundled
 * 子 agent，文件名（去 .md 后缀）为子 agent 名。删文件即下线，禁硬编码名单之外的名字。
 *
 * 扫描口径与 ChangeDetector.collectMdFiles 保持一致（同一目录、同样只认 .md），
 * 保证「加载期探测」与「同步期落库」看到的是同一批声明文件。
 *
 * 两个加载入口共用本扫描器：SkillMdLoader（真解析点）与 SkillLoadingService.createSkillManifestFromContent。
 */
public class BundledAgentScanner {
    /**
     * 扫描 <skill-root>/agents/ 下的声明文件，返回子 agent 名数组（无该目录则返回空数组）。
     */
    public static func scan(skillDir: String): Array<String> {
        let result = ArrayList<String>()
        let agentsSubDir = if (skillDir.endsWith("/") || skillDir.endsWith("\\")) {
            "${skillDir}agents"
        } else {
            "${skillDir}/agents"
        }
        try {
            if (exists(agentsSubDir)) {
                Directory.walk(agentsSubDir) { fileInfo =>
                    if (!fileInfo.isDirectory() && fileInfo.path.toString().endsWith(".md")) {
                        // 统一分隔符再取末段：Windows 下 Path 也可能给出反斜杠
                        let fullPath = fileInfo.path.toString().replace("\\", "/")
                        let parts = fullPath.split("/")
                        let fileName = parts[parts.size - 1]
                        let agentName = fileName.split(".")[0]
                        if (!agentName.isEmpty()) {
                            result.add(agentName)
                        }
                    }
                    return true
                }
            }
        } catch (_: Exception) {}
        return result.toArray()
    }
}
