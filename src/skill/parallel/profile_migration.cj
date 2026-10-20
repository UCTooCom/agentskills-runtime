package magic.skill.parallel

import magic.memory.workspace.{AgentWorkspace, WorkspaceFile, WorkspaceFileType}
import std.collection.ArrayList

/**
 * 由 AgentWorkspace 的 SOUL / IDENTITY / USER / MEMORY 文件迁移生成的 profile 技能规格（T105）。
 *
 * 仅承载数据，落盘（写出 SKILL.md）由调用方负责；本类负责把旧文件路径内容转换为
 * 带 frontmatter 的 profile 技能规格。真源收敛后，这些文件由 profile 技能替代
 * （见 AgentWorkspace.getCombinedMemory：注入 profile 后关闭旧文件路径）。
 */
public class ProfileSkillSpec {
    public let name: String
    public let frontmatter: String
    public let body: String

    public init(name: String, frontmatter: String, body: String) {
        this.name = name
        this.frontmatter = frontmatter
        this.body = body
    }

    public func toSkillMarkdown(): String {
        let sb = StringBuilder()
        sb.append("---\n")
        sb.append(frontmatter)
        sb.append("\n---\n\n")
        sb.append(body)
        return sb.toString()
    }
}

public class ProfileMigration {
    public init() {}

    public func migrate(workspace: AgentWorkspace): ArrayList<ProfileSkillSpec> {
        let result = ArrayList<ProfileSkillSpec>()
        this.collectIfPresent(workspace.soulFile, "profile-soul", "identity", "soul", result)
        this.collectIfPresent(workspace.identityFile, "profile-identity", "persona", "identity", result)
        this.collectIfPresent(workspace.userFile, "profile-user", "user", "user", result)
        this.collectIfPresent(workspace.memoryFile, "profile-memory", "memory", "memory", result)
        return result
    }

    private func collectIfPresent(
        file: Option<WorkspaceFile>,
        skillName: String,
        profileKind: String,
        sourceKind: String,
        out: ArrayList<ProfileSkillSpec>
    ): Unit {
        if (file.isSome()) {
            let wf = file.getOrThrow()
            if (wf.content.isSome()) {
                let body = wf.content.getOrThrow()
                if (!body.trimAscii().isEmpty()) {
                    let fm = this.buildFrontmatter(skillName, profileKind, sourceKind)
                    out.add(ProfileSkillSpec(skillName, fm, body))
                }
            }
        }
    }

    private func buildFrontmatter(skillName: String, profileKind: String, sourceKind: String): String {
        let sb = StringBuilder()
        sb.append("skill_type: profile\n")
        sb.append("name: ${skillName}\n")
        sb.append("profile_kind: ${profileKind}\n")
        sb.append("sync_scope: agent_owned\n")
        sb.append("authoritative: true\n")
        sb.append("conflict_policy: last_write_wins\n")
        sb.append("source: ${sourceKind}\n")
        sb.append("version: 1\n")
        return sb.toString()
    }
}
