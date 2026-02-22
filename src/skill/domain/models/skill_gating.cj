/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.domain.models

import std.collection.ArrayList
import std.collection.HashMap
import magic.utils.getEnv
import std.env.getVariable

public enum OSType {
    | Windows
    | Linux
    | macOS
    | All
}

public func osTypeToString(osType: OSType): String {
    return match (osType) {
        case OSType.Windows => "Windows"
        case OSType.Linux => "Linux"
        case OSType.macOS => "macOS"
        case OSType.All => "All"
    }
}

@When[os == "Windows"]
private const CURRENT_OS_TYPE: OSType = OSType.Windows

@When[os == "Linux"]
private const CURRENT_OS_TYPE: OSType = OSType.Linux

@When[os == "macOS"]
private const CURRENT_OS_TYPE: OSType = OSType.macOS

@When[os != "Windows" && os != "Linux" && os != "macOS"]
private const CURRENT_OS_TYPE: OSType = OSType.All

public func getCurrentOS(): OSType {
    return CURRENT_OS_TYPE
}

public func osTypesEqual(a: OSType, b: OSType): Bool {
    return match ((a, b)) {
        case (OSType.Windows, OSType.Windows) => true
        case (OSType.Linux, OSType.Linux) => true
        case (OSType.macOS, OSType.macOS) => true
        case (OSType.All, OSType.All) => true
        case _ => false
    }
}

public enum GatingRequirementType {
    | Binary
    | AnyBinary
    | Environment
    | Config
    | OS
    | Directory
    | File
}

public class GatingRequirement {
    public let requirementType: GatingRequirementType
    public let name: String
    public let value: Option<String>
    public let values: Option<ArrayList<String>>
    public let optional: Bool

    public init(
        requirementType!: GatingRequirementType,
        name!: String,
        value!: Option<String>,
        values!: Option<ArrayList<String>>,
        optional!: Bool
    ) {
        this.requirementType = requirementType
        this.name = name
        this.value = value
        this.values = values
        this.optional = optional
    }
}

public func createSimpleRequirement(requirementType: GatingRequirementType, name: String): GatingRequirement {
    return GatingRequirement(
        requirementType: requirementType,
        name: name,
        value: None,
        values: None,
        optional: false
    )
}

public class GatingCheckResult {
    public var passed: Bool
    public let failedRequirements: ArrayList<GatingRequirement>
    public let warnings: ArrayList<String>
    public let messages: ArrayList<String>

    public init(passed!: Bool) {
        this.passed = passed
        this.failedRequirements = ArrayList()
        this.warnings = ArrayList()
        this.messages = ArrayList()
    }

    public func addFailedRequirement(req: GatingRequirement): Unit {
        failedRequirements.add(req)
    }

    public func addWarning(warning: String): Unit {
        warnings.add(warning)
    }

    public func addMessage(message: String): Unit {
        messages.add(message)
    }
}

public class SkillGatingRules {
    public let requiresBinaries: ArrayList<String>
    public let requiresAnyBinaries: ArrayList<String>
    public let requiresEnv: HashMap<String, String>
    public let requiresConfig: HashMap<String, String>
    public let osRestriction: OSType
    public let requiresDirectories: ArrayList<String>
    public let requiresFiles: ArrayList<String>
    public let customRequirements: ArrayList<GatingRequirement>

    public init() {
        this.requiresBinaries = ArrayList()
        this.requiresAnyBinaries = ArrayList()
        this.requiresEnv = HashMap()
        this.requiresConfig = HashMap()
        this.osRestriction = OSType.All
        this.requiresDirectories = ArrayList()
        this.requiresFiles = ArrayList()
        this.customRequirements = ArrayList()
    }

    public func addRequiredBinary(binaryName: String): Unit {
        requiresBinaries.add(binaryName)
    }

    public func addAnyBinary(binaryName: String): Unit {
        requiresAnyBinaries.add(binaryName)
    }

    public func addEnvRequirement(name: String, value: String): Unit {
        requiresEnv.add(name, value)
    }

    public func addConfigRequirement(name: String, value: String): Unit {
        requiresConfig.add(name, value)
    }

    public func addRequiredDirectory(dirPath: String): Unit {
        requiresDirectories.add(dirPath)
    }

    public func addRequiredFile(filePath: String): Unit {
        requiresFiles.add(filePath)
    }

    public func addCustomRequirement(req: GatingRequirement): Unit {
        customRequirements.add(req)
    }

    public func hasRequirements(): Bool {
        return !requiresBinaries.isEmpty() ||
               !requiresAnyBinaries.isEmpty() ||
               !requiresEnv.isEmpty() ||
               !requiresConfig.isEmpty() ||
               !osTypesEqual(osRestriction, OSType.All) ||
               !requiresDirectories.isEmpty() ||
               !requiresFiles.isEmpty() ||
               !customRequirements.isEmpty()
    }

    public func getAllRequirements(): ArrayList<GatingRequirement> {
        let allReqs = ArrayList<GatingRequirement>()

        for (binary in requiresBinaries) {
            allReqs.add(createSimpleRequirement(
                GatingRequirementType.Binary,
                binary
            ))
        }

        if (!requiresAnyBinaries.isEmpty()) {
            allReqs.add(GatingRequirement(
                requirementType: GatingRequirementType.AnyBinary,
                name: "any-binary",
                value: None,
                values: Some(requiresAnyBinaries),
                optional: false
            ))
        }

        for ((name, value) in requiresEnv) {
            allReqs.add(GatingRequirement(
                requirementType: GatingRequirementType.Environment,
                name: name,
                value: if (value.isEmpty()) { None } else { Some(value) },
                values: None,
                optional: false
            ))
        }

        for ((name, value) in requiresConfig) {
            allReqs.add(GatingRequirement(
                requirementType: GatingRequirementType.Config,
                name: name,
                value: if (value.isEmpty()) { None } else { Some(value) },
                values: None,
                optional: false
            ))
        }

        if (!osTypesEqual(osRestriction, OSType.All)) {
            allReqs.add(createSimpleRequirement(
                GatingRequirementType.OS,
                osTypeToString(osRestriction)
            ))
        }

        for (dir in requiresDirectories) {
            allReqs.add(createSimpleRequirement(
                GatingRequirementType.Directory,
                dir
            ))
        }

        for (file in requiresFiles) {
            allReqs.add(createSimpleRequirement(
                GatingRequirementType.File,
                file
            ))
        }

        for (req in customRequirements) {
            allReqs.add(req)
        }

        return allReqs
    }
}
