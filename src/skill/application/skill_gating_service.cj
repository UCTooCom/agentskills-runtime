/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.application

import magic.skill.domain.models.{
    SkillGatingRules,
    GatingCheckResult,
    GatingRequirement,
    GatingRequirementType,
    OSType,
    createSimpleRequirement,
    osTypesEqual,
    osTypeToString,
    getCurrentOS
}
import magic.log.LogUtils
import std.collection.{ArrayList, HashMap}
import std.fs.{exists, Path, FileInfo, Directory}
import std.env.{getVariable}

func joinList(list: ArrayList<String>, separator: String): String {
    if (list.isEmpty()) {
        return ""
    }
    let sb = StringBuilder()
    var first = true
    for (item in list) {
        if (first) {
            first = false
        } else {
            sb.append(separator)
        }
        sb.append(item)
    }
    return sb.toString()
}

public class SkillGatingService {
    public static func checkSkillGating(rules: SkillGatingRules): GatingCheckResult {
        let result = GatingCheckResult(passed: true)
        
        checkOSRequirement(rules, result)
        checkRequiredBinaries(rules, result)
        checkRequiredAnyBinaries(rules, result)
        checkRequiredDirectories(rules, result)
        checkRequiredFiles(rules, result)
        checkRequiredEnvironmentVariables(rules, result)
        checkCustomRequirements(rules, result)
        
        return result
    }
    
    private static func checkOSRequirement(
        rules: SkillGatingRules,
        result: GatingCheckResult
    ): Unit {
        if (osTypesEqual(rules.osRestriction, OSType.All)) {
            return
        }
        
        let requiredOS = rules.osRestriction
        let currentOS = getCurrentOS()
        
        if (!osTypesEqual(requiredOS, currentOS)) {
            result.passed = false
            let req = createSimpleRequirement(GatingRequirementType.OS, osTypeToString(requiredOS))
            result.addFailedRequirement(req)
            let msg = "OS requirement failed: required ${osTypeToString(requiredOS)}, current ${osTypeToString(currentOS)}"
            result.addMessage(msg)
            LogUtils.error("[SkillGatingService] ${msg}")
        } else {
            let msg = "OS requirement satisfied: ${osTypeToString(currentOS)}"
            result.addMessage(msg)
            LogUtils.info("[SkillGatingService] ${msg}")
        }
    }
    
    private static func checkRequiredBinaries(
        rules: SkillGatingRules,
        result: GatingCheckResult
    ): Unit {
        for (binaryName in rules.requiresBinaries) {
            let exists = checkBinaryExists(binaryName)
            
            if (!exists) {
                result.passed = false
                let req = createSimpleRequirement(GatingRequirementType.Binary, binaryName)
                result.addFailedRequirement(req)
                LogUtils.error("[SkillGatingService] Required binary not found: ${binaryName}")
                result.addMessage("Required binary not found: ${binaryName}")
            } else {
                LogUtils.info("[SkillGatingService] Required binary found: ${binaryName}")
                result.addMessage("Binary found: ${binaryName}")
            }
        }
    }
    
    private static func checkRequiredAnyBinaries(
        rules: SkillGatingRules,
        result: GatingCheckResult
    ): Unit {
        if (rules.requiresAnyBinaries.isEmpty()) {
            return
        }
        
        var found = false
        var foundBinary: Option<String> = None
        
        for (binaryName in rules.requiresAnyBinaries) {
            if (checkBinaryExists(binaryName)) {
                found = true
                foundBinary = Some(binaryName)
                break
            }
        }
        
        if (!found) {
            result.passed = false
            let req = GatingRequirement(
                requirementType: GatingRequirementType.AnyBinary,
                name: "any-binary",
                value: None,
                values: Some(rules.requiresAnyBinaries),
                optional: false
            )
            result.addFailedRequirement(req)
            LogUtils.error("[SkillGatingService] None of the required binaries found: ${joinList(rules.requiresAnyBinaries, ", ")}")
            result.addMessage("None of the required binaries found")
        } else if (let Some(b) <- foundBinary) {
            LogUtils.info("[SkillGatingService] Found required binary: ${b}")
            result.addMessage("Binary found: ${b}")
        }
    }
    
    private static func checkBinaryExists(binaryName: String): Bool {
        let pathExts = getPathExtensions()
        let pathDirs = getPathDirectories()
        
        for (dir in pathDirs) {
            for (ext in pathExts) {
                let fullPath = Path(dir).join(binaryName + ext)
                if (exists(fullPath)) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private static func getPathExtensions(): ArrayList<String> {
        let exts = ArrayList<String>()
        let currentOS = getCurrentOS()
        
        if (osTypesEqual(currentOS, OSType.Windows)) {
            exts.add(".exe")
            exts.add(".cmd")
            exts.add(".bat")
            exts.add("")
        } else {
            exts.add("")
        }
        
        return exts
    }
    
    private static func getPathDirectories(): ArrayList<String> {
        let dirs = ArrayList<String>()
        let pathVar = getVariable("PATH")
        
        if (pathVar.isSome()) {
            let pathValue = pathVar.getOrThrow()
            let currentOS = getCurrentOS()
            let separator = if (osTypesEqual(currentOS, OSType.Windows)) { ";" } else { ":" }
            var current = StringBuilder()
            
            for (char in pathValue) {
                if (char.toString() == separator) {
                    let dir = current.toString()
                    if (dir != "") {
                        dirs.add(dir)
                    }
                    current = StringBuilder()
                } else {
                    current.append(char)
                }
            }
            
            let lastDir = current.toString()
            if (lastDir != "") {
                dirs.add(lastDir)
            }
        }
        
        return dirs
    }
    
    private static func checkRequiredDirectories(
        rules: SkillGatingRules,
        result: GatingCheckResult
    ): Unit {
        for (dirPath in rules.requiresDirectories) {
            let dirPathObj = Path(dirPath)
            let existsFlag = exists(dirPathObj)
            let isDir = if (existsFlag) {
                let info = FileInfo(dirPath)
                info.isDirectory()
            } else {
                false
            }
            
            if (!existsFlag || !isDir) {
                result.passed = false
                let req = createSimpleRequirement(GatingRequirementType.Directory, dirPath)
                result.addFailedRequirement(req)
                LogUtils.error("[SkillGatingService] Required directory not found: ${dirPath}")
                result.addMessage("Required directory not found: ${dirPath}")
            } else {
                LogUtils.info("[SkillGatingService] Directory exists: ${dirPath}")
                result.addMessage("Directory exists: ${dirPath}")
            }
        }
    }
    
    private static func checkRequiredFiles(
        rules: SkillGatingRules,
        result: GatingCheckResult
    ): Unit {
        for (filePath in rules.requiresFiles) {
            let filePathObj = Path(filePath)
            let existsFlag = exists(filePathObj)
            let isFile = if (existsFlag) {
                let info = FileInfo(filePath)
                !info.isDirectory()
            } else {
                false
            }
            
            if (!existsFlag || !isFile) {
                result.passed = false
                let req = createSimpleRequirement(GatingRequirementType.File, filePath)
                result.addFailedRequirement(req)
                LogUtils.error("[SkillGatingService] Required file not found: ${filePath}")
                result.addMessage("Required file not found: ${filePath}")
            } else {
                LogUtils.info("[SkillGatingService] File exists: ${filePath}")
                result.addMessage("File exists: ${filePath}")
            }
        }
    }
    
    private static func checkRequiredEnvironmentVariables(
        rules: SkillGatingRules,
        result: GatingCheckResult
    ): Unit {
        for ((varName, expectedValue) in rules.requiresEnv) {
            let value = getVariable(varName)
            
            if (value.isNone()) {
                result.passed = false
                let req = GatingRequirement(
                    requirementType: GatingRequirementType.Environment,
                    name: varName,
                    value: if (expectedValue.isEmpty()) { None } else { Some(expectedValue) },
                    values: None,
                    optional: false
                )
                result.addFailedRequirement(req)
                LogUtils.error("[SkillGatingService] Required environment variable not found: ${varName}")
                result.addMessage("Required environment variable not found: ${varName}")
            } else if (!expectedValue.isEmpty() && value.getOrThrow() != expectedValue) {
                result.passed = false
                let req = GatingRequirement(
                    requirementType: GatingRequirementType.Environment,
                    name: varName,
                    value: Some(expectedValue),
                    values: None,
                    optional: false
                )
                result.addFailedRequirement(req)
                LogUtils.error("[SkillGatingService] Environment variable value mismatch: ${varName} expected ${expectedValue}, got ${value.getOrThrow()}")
                result.addMessage("Environment variable value mismatch: ${varName}")
            } else {
                LogUtils.info("[SkillGatingService] Environment variable found: ${varName}")
                result.addMessage("Environment variable found: ${varName}")
            }
        }
    }
    
    private static func checkCustomRequirements(
        rules: SkillGatingRules,
        result: GatingCheckResult
    ): Unit {
        for (req in rules.customRequirements) {
            let passed = checkCustomRequirement(req)
            
            if (!passed && !req.optional) {
                result.passed = false
                result.addFailedRequirement(req)
                LogUtils.error("[SkillGatingService] Custom requirement failed: ${req.name}")
                result.addMessage("Custom requirement failed: ${req.name}")
            } else if (passed) {
                LogUtils.info("[SkillGatingService] Custom requirement passed: ${req.name}")
                result.addMessage("Custom requirement passed: ${req.name}")
            }
        }
    }
    
    private static func checkCustomRequirement(req: GatingRequirement): Bool {
        match (req.requirementType) {
            case GatingRequirementType.Binary =>
                return checkBinaryExists(req.name)
            case GatingRequirementType.Environment =>
                let value = getVariable(req.name)
                if (value.isNone()) {
                    return false
                }
                if (let Some(expected) <- req.value) {
                    return value.getOrThrow() == expected
                }
                return true
            case GatingRequirementType.Directory =>
                let pathObj = Path(req.name)
                let existsFlag = exists(pathObj)
                if (!existsFlag) {
                    return false
                }
                let info = FileInfo(req.name)
                return info.isDirectory()
            case GatingRequirementType.File =>
                let pathObj = Path(req.name)
                let existsFlag = exists(pathObj)
                if (!existsFlag) {
                    return false
                }
                let info = FileInfo(req.name)
                return !info.isDirectory()
            case _ =>
                return true
        }
    }
}
