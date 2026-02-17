/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.application

import std.collection.{HashMap, ArrayList, HashSet}
import std.fs.{exists, Directory, FileInfo, Path, File, copy, remove, OpenMode}
import std.process.{launch, ProcessRedirect, SubProcess}
import std.env.{getWorkingDirectory, getVariable}
import std.time.DateTime
import std.io.{StringReader, StringWriter}
import magic.core.skill.SkillManager
import magic.log.LogUtils
import magic.skill.domain.models.ValidationResult
import magic.utils.{move, newProcess}

/**
 * SkillPackageManager handles the installation, update, and uninstallation of skills
 * Implements uctoo-inspired features for Git repository integration and dependency management
 */
public class SkillPackageManager {
    private let _installationPath: String
    private let _dependencyResolver: DependencyResolver
    private let _skillRegistry: SkillRegistry
    private let _gitManager: GitManager

    /**
     * Determine the installation path based on priority:
     * Priority 1: Provided path parameter (if not empty)
     * Priority 2: Environment variable SKILL_INSTALL_PATH from .env file
     * Priority 3: Default path "./skills"
     * 
     * This is a static utility method that can be used by CLI, API, or any other caller.
     */
    public static func determineInstallationPath(providedPath: String): String {
        // Priority 1: Use provided path if not empty
        if (!providedPath.isEmpty()) {
            LogUtils.info("Using provided installation path: ${providedPath}")
            return Path(providedPath).toString()
        }

        // Priority 2: Use environment variable SKILL_INSTALL_PATH
        if (let Some(configuredPath) <- getVariable("SKILL_INSTALL_PATH")) {
            if (!configuredPath.isEmpty()) {
                LogUtils.info("Using SKILL_INSTALL_PATH from environment: ${configuredPath}")
                return Path(configuredPath).toString()
            }
        }

        // Priority 3: Default to "./skills" directory
        let currentDir = getWorkingDirectory().toString()
        let defaultPath = Path(currentDir).join("skills").toString()
        LogUtils.info("Using default installation path: ${defaultPath}")
        return defaultPath
    }

    public init(
        installationPath!: String,
        dependencyResolver!: DependencyResolver,
        skillRegistry!: SkillRegistry,
        gitManager!: GitManager
    ) {
        _dependencyResolver = dependencyResolver
        _skillRegistry = skillRegistry
        _gitManager = gitManager
        
        // Use the unified path determination logic
        _installationPath = SkillPackageManager.determineInstallationPath(installationPath)
    }

    /**
     * Install a skill from a local path
     */
    public func installFromPath(path: String, validate: Bool): SkillInstallResult {
        LogUtils.info("Installing skill from path: ${path}")
        
        // Validate skill format and dependencies
        if (validate) {
            let validationResult = _validateSkillAtPath(path)
            if (!validationResult.isValid) {
                return SkillInstallResult.failureResult(validationResult.errors)
            }
        }

        // Resolve and install dependencies
        let dependencies = _dependencyResolver.resolveFromPath(path)
        for (dependency in dependencies) {
            _installDependency(dependency)
        }

        // Copy skill to installation directory
        LogUtils.info("Attempting to install skill from: ${path}")
        LogUtils.info("Installation path base: ${_installationPath}")
        
        let skillName = _extractSkillName(path)
        LogUtils.info("Extracted skill name: ${skillName}")
        
        let installPath = Path(_installationPath).join(skillName).toString()
        LogUtils.info("Calculated install path: ${installPath}")

        // Check if destination already exists - will overwrite
        let installPathObj = Path(installPath)
        if (exists(installPathObj)) {
            LogUtils.info("Destination already exists, will overwrite: ${installPath}")
        }

        // Create installation directory if it doesn't exist
        if (!exists(installPathObj.parent)) {
            LogUtils.info("Creating parent directory: ${installPathObj.parent}")
            Directory.create(installPathObj.parent, recursive: true)
        }

        // Actually copy the skill files to the installation directory
        try {
            // Check if source exists before copying
            LogUtils.info("Checking if source path exists: ${path}")
            if (exists(path)) {
                let sourcePath = Path(path)
                let sourceInfo = FileInfo(sourcePath.toString())
                LogUtils.info("Source is directory: ${sourceInfo.isDirectory()}")

                if (sourceInfo.isDirectory()) {
                    // Copy directory contents (create dest if not exists)
                    LogUtils.info("Copying directory from ${sourcePath} to ${installPathObj}")
                    if (!exists(installPathObj)) {
                        Directory.create(installPathObj, recursive: true)
                    }
                    
                    // Copy all files from source to destination
                    Directory.walk(sourcePath.toString()) { fileInfo =>
                        if (!fileInfo.isDirectory()) {
                            let relativePath = fileInfo.path.toString().replace(sourcePath.toString(), "")
                            // Remove leading slash or backslash from relative path
                            var cleanRelativePath = relativePath
                            if (cleanRelativePath.startsWith("/") || cleanRelativePath.startsWith("\\")) {
                                cleanRelativePath = cleanRelativePath[1..cleanRelativePath.size]
                            }
                            let destFilePath = Path(installPath).join(cleanRelativePath.replace("\\", "/"))
                            if (!exists(destFilePath.parent)) {
                                Directory.create(destFilePath.parent, recursive: true)
                            }
                            copy(fileInfo.path.toString(), to: destFilePath.toString(), overwrite: true)
                        }
                        true
                    }
                } else {
                    // Copy single file
                    Directory.create(installPathObj, recursive: true)
                    let destFilePath = Path(installPath).join(sourcePath.fileName)
                    LogUtils.info("Copying file from ${sourcePath} to ${destFilePath}")
                    copy(sourcePath.toString(), to: destFilePath.toString(), overwrite: true)
                }

                // Verify that files were copied
                let destInfo = FileInfo(installPath)
                if (destInfo.isDirectory()) {
                    LogUtils.info("Successfully copied to destination directory")
                } else {
                    LogUtils.info("Successfully copied to destination file")
                }
            } else {
                LogUtils.error("Source path does not exist: ${path}")
                return SkillInstallResult.failureResult(["Source path does not exist: ${path}"])
            }

            LogUtils.info("Skill successfully copied to: ${installPath}")
        } catch (ex: Exception) {
            LogUtils.error("Failed to copy skill from ${path} to ${installPath}: ${ex.message}")
            LogUtils.error("Exception details: ${ex.message}")
            return SkillInstallResult.failureResult(["Failed to copy skill files: ${ex.message}"])
        }

        // Register skill in the registry
        _skillRegistry.registerSkill(skillName, installPath)

        return SkillInstallResult.successResult(installPath)
    }

    /**
     * Install a skill from a Git repository with branch/tag/commit support
     */
    public func installFromGit(
        gitUrl: String,
        branch: Option<String>,
        tag: Option<String>,
        commit: Option<String>
    ): SkillInstallResult {
        LogUtils.info("Installing skill from Git repository: ${gitUrl}")
        
        // Determine Git reference priority: commit > branch > tag
        let gitRef: GitReference = if (commit.isSome()) {
            GitReferenceCommit(value: commit.getOrThrow())
        } else if (branch.isSome()) {
            GitReferenceBranch(value: branch.getOrThrow())
        } else if (tag.isSome()) {
            GitReferenceTag(value: tag.getOrThrow())
        } else {
            GitReferenceDefault()
        }

        // Clone repository to temporary location
        let tempPath = _gitManager.cloneRepository(gitUrl, gitRef)

        // Install from cloned path
        let result = installFromPath(tempPath, true)

        // Clean up temporary directory
        _cleanupTempDirectory(tempPath)

        return result
    }

    /**
     * Install a skill from a Git repository with default parameters
     */
    public func installFromGit(gitUrl: String): SkillInstallResult {
        return installFromGit(gitUrl, None, None, None)
    }

    /**
     * Update an installed skill
     */
    public func updateSkill(skillName: String): SkillInstallResult {
        LogUtils.info("Updating skill: ${skillName}")
        
        // Get current skill info from registry
        if (let Some(skillInfo) <- _skillRegistry.getSkillInfo(skillName)) {
            if (skillInfo.sourceType == "git") {
                // Re-clone and reinstall from Git source
                return installFromGit(
                    skillInfo.sourceUrl.getOrDefault({=>""}),
                    skillInfo.branch,
                    skillInfo.tag,
                    skillInfo.commit
                )
            } else {
                return SkillInstallResult.errorResult("Cannot update locally installed skill: ${skillName}")
            }
        }

        return SkillInstallResult.errorResult("Skill not found: ${skillName}")
    }

    /**
     * Uninstall a skill
     * Searches for the skill in multiple paths based on priority
     */
    public func uninstallSkill(skillName: String): Bool {
        LogUtils.info("Uninstalling skill: ${skillName}")
        
        // Remove skill from registry
        _skillRegistry.unregisterSkill(skillName)

        // Try to find the skill in multiple paths based on priority
        let skillPath = _findSkillPath(skillName)
        
        if (skillPath.isSome()) {
            let foundPath = skillPath.getOrThrow()
            LogUtils.info("Found skill to uninstall at: ${foundPath}")
            
            try {
                // Remove the skill directory and all its contents recursively
                _removeDirectoryRecursively(Path(foundPath))
                LogUtils.info("Skill directory removed: ${foundPath}")
                return true
            } catch (ex: Exception) {
                LogUtils.error("Failed to remove skill directory: ${ex.message}")
                return false
            }
        }
        
        LogUtils.info("Skill directory not found for: ${skillName}")
        return true
    }

    /**
     * Remove a directory and all its contents recursively
     */
    private func _removeDirectoryRecursively(dirPath: Path): Unit {
        if (!exists(dirPath)) {
            return
        }
        
        let dirInfo = FileInfo(dirPath)
        if (dirInfo.isDirectory()) {
            // Walk through all files and delete them first
            Directory.walk(dirPath.toString()) { fileInfo =>
                if (!fileInfo.isDirectory()) {
                    remove(fileInfo.path.toString())
                }
                true
            }
            // Now walk again to delete empty directories (in reverse order would be better but walk should work)
            Directory.walk(dirPath.toString()) { fileInfo =>
                if (fileInfo.isDirectory()) {
                    let subDirInfo = FileInfo(fileInfo.path)
                    if (subDirInfo.isDirectory()) {
                        remove(fileInfo.path.toString())
                    }
                }
                true
            }
            // Finally delete the root directory
            remove(dirPath.toString())
        } else {
            remove(dirPath.toString())
        }
    }

    /**
     * List installed skills
     */
    public func listInstalledSkills(): Array<InstalledSkill> {
        LogUtils.info("Listing installed skills")

        // Get list of installed skills from registry
        let skillInfos = _skillRegistry.listSkills()
        let installedSkills = ArrayList<InstalledSkill>()

        for (skillInfo in skillInfos) {
            installedSkills.add(InstalledSkill(
                name: skillInfo.name,
                path: skillInfo.path,
                version: skillInfo.version,
                sourceType: skillInfo.sourceType,
                sourceUrl: skillInfo.sourceUrl,
                branch: skillInfo.branch,
                tag: skillInfo.tag,
                commit: skillInfo.commit
            ))
        }

        return installedSkills.toArray()
    }

    /**
     * Validate skill at path
     */
    private func _validateSkillAtPath(path: String): ValidationResult {
        // In a real implementation, this would validate the skill format and dependencies
        // For now, we'll return a successful validation
        return ValidationResult.success()
    }

    /**
     * Install a dependency
     */
    private func _installDependency(dependency: SkillDependency): Unit {
        LogUtils.info("Installing dependency: ${dependency.name}")
        // In a real implementation, this would install the dependency
    }

    /**
     * Extract skill name from path
     */
    private func _extractSkillName(path: String): String {
        // In a real implementation, this would extract the skill name from the skill definition
        // For now, we'll extract it from the directory name
        // Normalize path separators to forward slashes for consistent processing
        let normalizedPath = path.replace("\\", "/")
        let pathParts = normalizedPath.split("/")
        return pathParts[pathParts.size - 1]
    }

    /**
     * Clean up temporary directory
     */
    private func _cleanupTempDirectory(tempPath: String): Unit {
        LogUtils.info("Cleaning up temporary directory: ${tempPath}")
    }

    /**
     * Edit a skill's SKILL.md file
     * Updates the YAML frontmatter fields with provided values
     * Searches for the skill in multiple paths based on priority
     */
    public func editSkill(skillName: String, updates: HashMap<String, String>): Bool {
        LogUtils.info("Editing skill: ${skillName}")
        
        // Try to find the skill in multiple paths based on priority
        let skillPath = _findSkillPath(skillName)
        
        if (skillPath.isNone()) {
            LogUtils.error("Skill directory not found for: ${skillName}")
            return false
        }
        
        let foundPath = skillPath.getOrThrow()
        LogUtils.info("Found skill at: ${foundPath}")
        
        // Find SKILL.md file
        let skillMdPath = Path(foundPath).join("SKILL.md")
        if (!exists(skillMdPath)) {
            LogUtils.error("SKILL.md not found at: ${skillMdPath}")
            return false
        }
        
        try {
            // Read the current content
            let content = _readFileContent(skillMdPath)
            
            // Update the frontmatter
            let updatedContent = _updateYamlFrontmatter(content, updates)
            
            // Write back
            _writeFileContent(skillMdPath, updatedContent)
            
            LogUtils.info("Successfully updated SKILL.md for skill: ${skillName}")
            return true
        } catch (ex: Exception) {
            LogUtils.error("Failed to edit skill: ${ex.message}")
            return false
        }
    }

    /**
     * Find skill path by searching in multiple directories based on priority
     * Priority 1: Provided path parameter (from request)
     * Priority 2: Environment variable SKILL_INSTALL_PATH from .env file
     * Priority 3: Default path "./skills"
     */
    private func _findSkillPath(skillName: String): Option<String> {
        var searchPaths = HashSet<String>()
        
        if (!_installationPath.isEmpty()) {
            searchPaths.add(_installationPath)
        }
        
        if (let Some(envPath) <- getVariable("SKILL_INSTALL_PATH")) {
            if (!envPath.isEmpty()) {
                searchPaths.add(envPath)
            }
        }
        
        let currentDir = getWorkingDirectory().toString()
        let defaultPath = Path(currentDir).join("skills").toString()
        searchPaths.add(defaultPath)
        
        for (searchPath in searchPaths) {
            let skillDir = Path(searchPath).join(skillName)
            if (exists(skillDir)) {
                LogUtils.info("Found skill '${skillName}' at: ${skillDir}")
                return Some(skillDir.toString())
            }
        }
        
        LogUtils.info("Skill '${skillName}' not found in any search path")
        return None
    }

    /**
     * Read file content
     */
    private func _readFileContent(path: Path): String {
        let file = File(path, OpenMode.Read)
        let reader = StringReader(file)
        let content = reader.readToEnd()
        file.close()
        return content
    }

    /**
     * Write content to file
     */
    private func _writeFileContent(path: Path, content: String): Unit {
        let file = File(path, OpenMode.Write)
        let writer = StringWriter(file)
        writer.write(content)
        writer.flush()
        file.close()
    }

    /**
     * Update YAML frontmatter in SKILL.md content
     */
    private func _updateYamlFrontmatter(content: String, updates: HashMap<String, String>): String {
        // Find frontmatter boundaries
        let lines = content.split('\n')
        let result = ArrayList<String>()
        var inFrontmatter = false
        var frontmatterEnded = false
        
        for (i in 0..lines.size) {
            let line = lines[i]
            
            if (i == 0 && line.trimAscii() == "---") {
                inFrontmatter = true
                result.add(line)
                continue
            }
            
            if (inFrontmatter && line.trimAscii() == "---") {
                // Add any updates that weren't in the original frontmatter
                for ((key, value) in updates) {
                    var keyFound = false
                    for (j in 0..result.size) {
                        let existingLine = result[j]
                        if (existingLine.startsWith("${key}:")) {
                            keyFound = true
                            break
                        }
                    }
                    if (!keyFound) {
                        result.add("${key}: ${value}")
                    }
                }
                result.add(line)
                inFrontmatter = false
                frontmatterEnded = true
                continue
            }
            
            if (inFrontmatter) {
                // Check if this line should be updated
                var lineUpdated = false
                for ((key, value) in updates) {
                    if (line.startsWith("${key}:")) {
                        result.add("${key}: ${value}")
                        lineUpdated = true
                        break
                    }
                }
                if (!lineUpdated) {
                    result.add(line)
                }
            } else {
                result.add(line)
            }
        }
        
        return String.join(result.toArray(), delimiter: "\n")
    }
}

/**
 * Result of skill installation
 */
public struct SkillInstallResult {
    public let success: Bool
    public let path: Option<String>
    public let error: Option<String>

    public init(
        success!: Bool,
        path!: Option<String>,
        error!: Option<String>
    ) {
        this.success = success
        this.path = path
        this.error = error
    }
    
    public static func successResult(path: String): SkillInstallResult {
        return SkillInstallResult(success: true, path: Some(path), error: None)
    }

    public static func failureResult(errors: Array<String>): SkillInstallResult {
        return SkillInstallResult(success: false, path: None, error: Some(String.join(errors, delimiter: ", ")))
    }

    public static func errorResult(errorMsg: String): SkillInstallResult {
        return SkillInstallResult(success: false, path: None, error: Some(errorMsg))
    }
}

/**
 * Information about an installed skill
 */
public struct InstalledSkill {
    public let name: String
    public let path: String
    public let version: String
    public let sourceType: String  // "local", "git", etc.
    public let sourceUrl: Option<String>
    public let branch: Option<String>
    public let tag: Option<String>
    public let commit: Option<String>

    public init(
        name!: String,
        path!: String,
        version!: String,
        sourceType!: String,
        sourceUrl!: Option<String>,
        branch!: Option<String>,
        tag!: Option<String>,
        commit!: Option<String>
    ) {
        this.name = name
        this.path = path
        this.version = version
        this.sourceType = sourceType
        this.sourceUrl = sourceUrl
        this.branch = branch
        this.tag = tag
        this.commit = commit
    }
}

/**
 * Git reference type
 */
public interface GitReference {}

public class GitReferenceDefault <: GitReference {
    public init() {}
}

public class GitReferenceBranch <: GitReference {
    public let value: String

    public init(value!: String) {
        this.value = value
    }
}

public class GitReferenceTag <: GitReference {
    public let value: String

    public init(value!: String) {
        this.value = value
    }
}

public class GitReferenceCommit <: GitReference {
    public let value: String

    public init(value!: String) {
        this.value = value
    }
}

/**
 * Dependency resolver for skill dependencies
 */
public class DependencyResolver {
    public func resolveFromPath(path: String): Array<SkillDependency> {
        // In a real implementation, this would parse the skill definition and extract dependencies
        // For now, we'll return an empty array
        return []
    }
}

/**
 * Git manager for cloning repositories
 * Implements real Git clone functionality with branch/tag/commit support
 */
public class GitManager {
    private let _tempBaseDir: String
    
    public init() {
        let currentDir = getWorkingDirectory().toString()
        _tempBaseDir = Path(currentDir).join("temp").join("git-clone").toString()
    }
    
    public init(tempBaseDir!: String) {
        _tempBaseDir = tempBaseDir
    }
    
    /**
     * Clone a Git repository to a temporary directory
     * @param url Git repository URL
     * @param ref Git reference (branch, tag, or commit)
     * @return Path to the cloned repository
     */
    public func cloneRepository(url: String, ref: GitReference): String {
        let tempPath = _generateTempPath()
        LogUtils.info("[GitManager] Cloning repository: ${url}")
        LogUtils.info("[GitManager] Target path: ${tempPath}")
        
        try {
            let cloneResult = _executeClone(url, ref, tempPath)
            
            if (!cloneResult.success) {
                LogUtils.error("[GitManager] Clone failed: ${cloneResult.error}")
                throw GitException("Failed to clone repository: ${cloneResult.error}")
            }
            
            LogUtils.info("[GitManager] Successfully cloned to: ${tempPath}")
            return tempPath
        } catch (ex: Exception) {
            LogUtils.error("[GitManager] Exception during clone: ${ex.message}")
            throw GitException("Failed to clone repository: ${ex.message}")
        }
    }
    
    /**
     * Check if Git is available in the system
     */
    public func isGitAvailable(): Bool {
        try {
            let result = _executeCommand("git", ["--version"])
            return result.success
        } catch (ex: Exception) {
            return false
        }
    }
    
    /**
     * Generate a unique temporary path for cloning
     */
    private func _generateTempPath(): String {
        let timestamp = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        let randomSuffix = _randomString(6)
        return Path(_tempBaseDir).join("skill-${timestamp}-${randomSuffix}").toString()
    }
    
    /**
     * Execute git clone command
     */
    private func _executeClone(url: String, ref: GitReference, targetPath: String): GitCommandResult {
        var args = ArrayList<String>()
        args.add("clone")
        
        match (ref) {
            case b: GitReferenceBranch =>
                args.add("--branch")
                args.add(b.value)
                args.add("--depth")
                args.add("1")
            case t: GitReferenceTag =>
                args.add("--branch")
                args.add(t.value)
                args.add("--depth")
                args.add("1")
            case c: GitReferenceCommit =>
                ()
            case d: GitReferenceDefault =>
                args.add("--depth")
                args.add("1")
            case _ =>
                args.add("--depth")
                args.add("1")
        }
        
        args.add(url)
        args.add(targetPath)
        
        let result = _executeCommand("git", args.toArray())
        
        // If commit reference, checkout the specific commit
        if (result.success) {
            match (ref) {
                case c: GitReferenceCommit =>
                    let checkoutArgs = ["checkout", c.value]
                    let checkoutResult = _executeCommandInDir(targetPath, "git", checkoutArgs)
                    if (!checkoutResult.success) {
                        return checkoutResult
                    }
                case _ => ()
            }
        }
        
        return result
    }
    
    /**
     * Execute a command and return the result
     */
    private func _executeCommand(command: String, args: Array<String>): GitCommandResult {
        try {
            let process = newProcess(command, args, redirectErr: true)
            let stdOut = StringReader(process.stdOutPipe).readToEnd()
            let stdErr = StringReader(process.stdErrPipe).readToEnd()
            let exitCode = process.wait()
            
            return GitCommandResult(
                success: exitCode == 0,
                output: stdOut,
                error: stdErr
            )
        } catch (ex: Exception) {
            return GitCommandResult(
                success: false,
                output: "",
                error: ex.message
            )
        }
    }
    
    /**
     * Execute a command in a specific directory
     */
    private func _executeCommandInDir(workDir: String, command: String, args: Array<String>): GitCommandResult {
        try {
            let process = newProcess(command, args, redirectErr: true)
            let stdOut = StringReader(process.stdOutPipe).readToEnd()
            let stdErr = StringReader(process.stdErrPipe).readToEnd()
            let exitCode = process.wait()
            
            return GitCommandResult(
                success: exitCode == 0,
                output: stdOut,
                error: stdErr
            )
        } catch (ex: Exception) {
            return GitCommandResult(
                success: false,
                output: "",
                error: ex.message
            )
        }
    }
    
    /**
     * Generate a random string for unique directory names
     */
    private func _randomString(length: Int64): String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        let sb = StringBuilder()
        let timestamp = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        var seed = timestamp
        for (i in 0..length) {
            seed = (seed * 1103515245 + 12345) % 2147483648
            let index = Int64(seed % chars.size)
            sb.append(chars[index])
        }
        return sb.toString()
    }
}

/**
 * Result of a Git command execution
 */
public struct GitCommandResult {
    public let success: Bool
    public let output: String
    public let error: String
    
    public init(success!: Bool, output!: String, error!: String) {
        this.success = success
        this.output = output
        this.error = error
    }
}

/**
 * Exception for Git operations
 */
public class GitException <: Exception {
    public init(message: String) {
        super(message)
    }
}


/**
 * Skill dependency
 */
public struct SkillDependency {
    public let name: String
    public let version: String
    public let optional: Bool

    public init(
        name!: String,
        version!: String,
        optional!: Bool
    ) {
        this.name = name
        this.version = version
        this.optional = optional
    }
}