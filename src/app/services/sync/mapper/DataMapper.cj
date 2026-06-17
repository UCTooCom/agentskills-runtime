package magic.app.services.sync.mapper

import std.collection.{HashMap, ArrayList}
import std.time.DateTime
import std.fs.Path
import magic.app.models.uctoo.{AgentsPO, AgentSkillsPO}
import magic.core.agent.{AgentDefinition, AgentPermission}
import magic.skill.domain.models.SkillManifest
import magic.app.services.sync.detector.ChangeDetector

public class DataMapper {

    public init() {}

    public func agentDefinitionToPO(definition: AgentDefinition, existingPO: Option<AgentsPO>): AgentsPO {
        let po = if (let Some(existing) <- existingPO) {
            existing
        } else {
            AgentsPO()
        }
        po.name = definition.name
        po.agentType = definition.agentType.toString()
        po.description = Some(definition.description)
        po.systemPrompt = Some(definition.systemPrompt)
        po.version = Some(definition.version)
        po.author = definition.author
        po.model = definition.model
        po.maxTurns = Some(Int32(definition.maxTurns))
        po.memoryScope = Some(definition.memory.toString())
        po.background = Some(definition.background)
        po.color = definition.color
        po.isolationMode = definition.isolation
        po.sourcePath = Some(ChangeDetector().normalizePath(definition.sourcePath.toString()))
        po.syncStatus = Some("synced")
        po.lastSyncAt = Some(DateTime.now())
        if (definition.tools.size > 0) {
            po.tools = Some(stringArrayToJsonArray(definition.tools))
        }
        if (definition.permissions.size > 0) {
            po.permissions = Some(permissionArrayToJsonArray(definition.permissions))
        }
        return po
    }

    public func poToAgentDefinition(po: AgentsPO): Option<AgentDefinition> {
        try {
            let builder = AgentDefinition.builder()
            builder.setName(po.name)
            builder.setAgentType(po.agentType)
            if (let Some(desc) <- po.description) {
                builder.setDescription(desc)
            }
            if (let Some(prompt) <- po.systemPrompt) {
                builder.setSystemPrompt(prompt)
            }
            if (let Some(ver) <- po.version) {
                builder.setVersion(ver)
            }
            if (let Some(author) <- po.author) {
                builder.setAuthor(author)
            }
            if (let Some(model) <- po.model) {
                builder.setModel(model)
            }
            if (let Some(turns) <- po.maxTurns) {
                builder.setMaxTurns(Int64(turns))
            }
            if (let Some(mem) <- po.memoryScope) {
                builder.setMemory(mem)
            }
            if (let Some(bg) <- po.background) {
                builder.setBackground(bg)
            }
            if (let Some(color) <- po.color) {
                builder.setColor(color)
            }
            if (let Some(isolation) <- po.isolationMode) {
                builder.setIsolation(isolation)
            }
            if (let Some(sp) <- po.sourcePath) {
                builder.setSourcePath(Path(sp))
            }
            if (let Some(toolsJson) <- po.tools) {
                builder.setTools(jsonArrayToStringArray(toolsJson))
            }
            if (let Some(permJson) <- po.permissions) {
                builder.setPermissions(stringArrayToPermissionArray(jsonArrayToStringArray(permJson)))
            }
            return builder.build()
        } catch (_: Exception) {
            return None
        }
    }

    public func skillManifestToPO(manifest: SkillManifest, existingPO: Option<AgentSkillsPO>): AgentSkillsPO {
        let po = if (let Some(existing) <- existingPO) {
            existing
        } else {
            AgentSkillsPO()
        }
        po.name = manifest.name
        po.description = Some(manifest.description)
        po.license = manifest.license
        po.compatibility = manifest.compatibility
        po.allowedTools = manifest.allowedTools
        po.instructions = Some(manifest.instructions)
        po.sourcePath = Some(manifest.skillPath)
        po.scriptsDirExists = if (manifest.scriptsDirExists) { 1 } else { 0 }
        po.referencesDirExists = if (manifest.referencesDirExists) { 1 } else { 0 }
        po.assetsDirExists = if (manifest.assetsDirExists) { 1 } else { 0 }
        po.syncStatus = Some("synced")
        po.lastSyncAt = Some(DateTime.now())
        return po
    }

    public func poToSkillManifest(po: AgentSkillsPO): Option<SkillManifest> {
        try {
            let name = po.name
            let description = if (let Some(d) <- po.description) { d } else { "" }
            let instructions = if (let Some(i) <- po.instructions) { i } else { "" }
            let skillPath = if (let Some(sp) <- po.sourcePath) { sp } else { "" }
            let metadata = HashMap<String, String>()
            let manifest = SkillManifest(
                name: name,
                description: description,
                license: po.license,
                compatibility: po.compatibility,
                metadata: metadata,
                allowedTools: po.allowedTools,
                instructions: instructions,
                skillPath: skillPath,
                scriptsDirExists: po.scriptsDirExists == 1,
                referencesDirExists: po.referencesDirExists == 1,
                assetsDirExists: po.assetsDirExists == 1,
                parameters: []
            )
            return Some(manifest)
        } catch (_: Exception) {
            return None
        }
    }

    private func stringArrayToJsonArray(arr: Array<String>): String {
        var sb = StringBuilder()
        sb.append("[")
        var first = true
        for (item in arr) {
            if (!first) {
                sb.append(",")
            }
            sb.append("\"")
            sb.append(item)
            sb.append("\"")
            first = false
        }
        sb.append("]")
        return sb.toString()
    }

    private func jsonArrayToStringArray(json: String): Array<String> {
        let trimmed = json.trimAscii()
        if (trimmed.size < 2) {
            return []
        }
        let content = trimmed[1..trimmed.size - 1]
        if (content.isEmpty()) {
            return []
        }
        let result = ArrayList<String>()
        var current = StringBuilder()
        var inQuote = false
        for (i in 0..content.size) {
            let ch = content[i]
            if (ch == UInt8(34) && !inQuote) {
                inQuote = true
                current = StringBuilder()
            } else if (ch == UInt8(34) && inQuote) {
                inQuote = false
                result.add(current.toString())
            } else if (inQuote) {
                current.append(String.fromUtf8(Array<UInt8>(1, { _ => ch })))
            }
        }
        return result.toArray()
    }

    private func permissionArrayToJsonArray(permissions: Array<AgentPermission>): String {
        var sb = StringBuilder()
        sb.append("[")
        var first = true
        for (perm in permissions) {
            if (!first) {
                sb.append(",")
            }
            sb.append("\"")
            sb.append(perm.toString())
            sb.append("\"")
            first = false
        }
        sb.append("]")
        return sb.toString()
    }

    private func stringArrayToPermissionArray(arr: Array<String>): Array<AgentPermission> {
        let result = ArrayList<AgentPermission>()
        for (str in arr) {
            if (let Some(perm) <- AgentPermission.parse(str)) {
                result.add(perm)
            }
        }
        return result.toArray()
    }

}
