/*
 * Copyright (c) 2026. All rights reserved.
 */
package magic.skill.application

import magic.skill.domain.models.{SkillManifest, SkillLoadingContext, ValidationResult}
import magic.skill.infrastructure.loaders.ResourceLoadingService
import magic.core.skill.{Skill, SkillManager}
import magic.skill.BaseSkill
import magic.tool.webmcp.WebRequestApprovalTool
import magic.log.LogUtils
import std.time.DateTime
import std.collection.ArrayList
import std.fs.{File, FileInfo, Directory, OpenMode, exists}
// 注意：StringReader 的 close()/readToEnd() 是 InputStream 接口的**扩展方法**，
// 只 import StringReader 不够，必须同时让 InputStream 可见（否则报
// `'close' is not a member of class 'StringReader<Class-File>'`，
//  编译器提示 `to use the following extension, import 'Interface-InputStream'`）。
// 同包先例（skill_md_loader.cj / resource_loader.cj）用 `import std.io.*` 即为此故。
import std.io.{StringReader, InputStream}

/**
 * SkillManagementService implements application service for managing skills throughout their lifecycle.
 */
public class SkillManagementService {
    private let skillLoadingService: SkillLoadingService
    private let skillValidationService: SkillValidationService
    private let resourceLoadingService: ResourceLoadingService
    private let skillRegistry: SkillRegistry
    /// 决策点运行时注册表：只登记校验通过的决策点，让"不生效"可被下游查询（spec 5.15.3 异常场景 3）
    private let decisionPointRegistry: DecisionPointRegistry

    public init() {
        this.skillLoadingService = SkillLoadingService()
        this.skillValidationService = SkillValidationService()
        this.resourceLoadingService = ResourceLoadingService()
        this.skillRegistry = SkillRegistry()
        this.decisionPointRegistry = DecisionPointRegistry()
        // 注入决策点有效性查询到审批工具，让"不生效"在请求路径上闭环（v15 修复问题 C）。
        // 用函数类型回调而非直接持有 DecisionPointRegistry，避免 tool.webmcp → skill.application 的循环依赖。
        // 捕获局部 let registry（闭包逃逸安全，见 Cangjie 闭包捕获规则），不捕获 this。
        let registry = this.decisionPointRegistry
        WebRequestApprovalTool.setDecisionPointChecker({ skill: String, point: String =>
            registry.find(skill, point).isSome()
        })
        // Note: Skill factories should be registered externally to avoid circular dependencies
        // Example: skillRegistry.registerFactory("uctoo-api-skill", UctooAPISkillFactory())
    }

    /**
     * 暴露决策点注册表，供执行器 / 审批工具按 (skill, pointId) 取用有效决策点。
     */
    public func getDecisionPointRegistry(): DecisionPointRegistry {
        return this.decisionPointRegistry
    }

    /**
     * Get the skill registry for external factory registration
     * This allows external code to register skill factories without causing circular dependencies
     */
    public func getSkillRegistry(): SkillRegistry {
        return this.skillRegistry
    }

    /**
     * Load skill from path
     */
    public func loadSkillFromPath(path: String): Option<Skill> {
        // Load the skill manifest from the path
        let manifestOpt = this.skillLoadingService.loadSkillFromPath(path)

        if (manifestOpt.isNone()) {
            return None
        }

        let manifest = manifestOpt.getOrThrow()

        // ── 内容级校验（Ch13.1 决策点校验的接入点）────────────────────────
        // 修复 P0（v15 复核问题 A）：此前 loadSkillFromPath 只调 validateSkillManifest，
        // 导致 SkillValidationService.validateSkillContent（决策点校验的唯一入口）
        // 在全仓库零调用 ⇒ 技能里的决策点永不被校验。
        // 这里补上内容级校验：读 SKILL.md 原文 → 校验 frontmatter 结构与决策点。
        // 注意：决策点非法**不阻断加载**（spec 5.15.3 异常场景 3 要求"告警 + 该决策点不生效"），
        // 因此只在内容级校验出现**错误**（errors，如 frontmatter 缺 name/description）时才拒绝。
        let contentValidation = this._validateSkillFileContent(path, manifest.name)

        // Validate the skill manifest
        let manifestValidation = this.skillValidationService.validateSkillManifest(manifest)

        // Check if validation failed（manifest 或内容级 errors 任一失败即拒绝加载）
        let validationResult = if (contentValidation.isSome()) {
            ValidationResult.mergeValidations(manifestValidation, contentValidation.getOrThrow())
        } else {
            manifestValidation
        }

        if (!validationResult.isValid) {
            LogUtils.error("Skill '${manifest.name}' 加载失败：校验未通过 ${validationResult.errors.toString()}")
            return None
        }

        // 决策点告警（非阻断）：让技能作者在加载日志里看到"哪个决策点不生效"
        for (warning in validationResult.warnings) {
            LogUtils.warn("Skill '${manifest.name}' 校验告警: ${warning}")
        }

        // ── Ch13.1 决策点登记（"该决策点不生效"的落地）────────────────────
        // 只登记校验通过的决策点；失效决策点不登记 ⇒ registry.find 返回 None ⇒ 不生效。
        this.decisionPointRegistry.registerFromManifest(manifest)

        // Load external resources for the skill
        let resourceLoader = this.resourceLoadingService.loadExternalResources(path)

        // Create the skill loading context
        let context = SkillLoadingContext(
            manifest: manifest,
            resourceLoader: resourceLoader,
            validationResult: validationResult,
            creationDate: (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        )

        // Use the skill registry to create the appropriate skill instance
        // This allows specific skill implementations to be instantiated
        // instead of generic BaseSkill instances
        let skillOpt = skillRegistry.createSkill(manifest)

        if (skillOpt.isSome()) {
            let skill = skillOpt.getOrThrow()
            return Some(skill)
        }

        // Fallback: Create a generic BaseSkill instance
        let skill = BaseSkill(
            name: manifest.name,
            description: manifest.description,
            license: manifest.license,
            compatibility: manifest.compatibility,
            metadata: manifest.metadata,
            allowedTools: manifest.allowedTools,
            instructions: manifest.instructions,
            skillPath: manifest.skillPath
        )

        return Some(skill)
    }

    /**
     * 读取 SKILL.md 原文并做内容级校验（YAML 语法 + frontmatter 结构 + 决策点）。
     *
     * 返回 None 表示文件不可读（此时不额外报错，交由 manifest 校验路径处理）；
     * 返回 Some(result) 时 result.errors 为阻断性错误，result.warnings 为非阻断告警。
     */
    private func _validateSkillFileContent(path: String, skillName: String): Option<ValidationResult> {
        try {
            let file = File(path, OpenMode.Read)
            if (!file.canRead()) {
                return None
            }
            let reader = StringReader(file)
            let content = reader.readToEnd()
            reader.close()
            file.close()

            return Some(this.skillValidationService.validateSkillContent(content))
        } catch (ex: Exception) {
            LogUtils.warn("Skill '${skillName}' 内容级校验读取失败（已跳过内容校验）: ${path}")
            return None
        }
    }

    /**
     * Register skill with skill manager
     */
    public func registerSkill(skill: Skill, skillManager: SkillManager): Bool {
        try {
            skillManager.addSkill(skill)
            return true
        } catch (ex: Exception) {
            // Log the exception or handle it appropriately
            return false
        }
    }

    /**
     * Load skills from directory
     */
    public func loadSkillsFromDirectory(directoryPath: String): Array<Skill> {
        let skills = ArrayList<Skill>()

        // Check if the directory exists
        if (!exists(directoryPath)) {
         //   println("Directory does not exist: ${directoryPath}")
            return skills.toArray()
        }

        // Use Directory.walk to iterate through the directory
        let dirPath = directoryPath
        let baseDirInfo = FileInfo(dirPath)

        if (!baseDirInfo.isDirectory()) {
        //    println("Path is not a directory: ${directoryPath}")
            return skills.toArray()
        }

        // Get all subdirectories in the base directory
        let subdirs = ArrayList<String>()
        Directory.walk(dirPath) { fileInfo =>
            if (fileInfo.isDirectory() && fileInfo.path.toString() != dirPath) {
                // This is a subdirectory, add it to the list
                let startIdx = Int64(dirPath.size) + 1
                let fullPathStr = fileInfo.path.toString()
                let relativePath = if (startIdx < Int64(fullPathStr.size)) {
                    fullPathStr[startIdx..Int64(fullPathStr.size)]
                } else {
                    ""
                }
                // Only add direct subdirectories (not nested ones)
                if (!relativePath.contains("/")) {
                    subdirs.add(fileInfo.path.toString())
                }
            }
            return true
        }

        for (subdirPath in subdirs.toArray()) {
            let skillPath = "${subdirPath}/SKILL.md"

            // Check if SKILL.md exists in the subdirectory
            if (exists(skillPath)) {
                let skillOption = loadSkillFromPath(skillPath)
                if (skillOption.isSome()) {
                    let skill = skillOption.getOrThrow()
                    skills.add(skill)
                //        println("Successfully loaded skill: ${skill.name}")
                } else {
                //        println("Failed to load skill from: ${skillPath}")
                }
            } else {
                //        println("No SKILL.md file found in: ${subdirPath}")
            }
        }

        return skills.toArray()
    }
}
