/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

import magic.core.skill.Skill
import std.collection.ArrayList

public class SkillContentRenderer {

    public init() {}

    public func renderSkillContent(skill: Skill): String {
        if (skill.instructions.isEmpty()) {
            return ""
        }
        let sb = StringBuilder()
        sb.append("<skill_content name=\"${skill.name}\">\n")
        sb.append("<skill_instructions>\n")
        sb.append(skill.instructions)
        sb.append("\n</skill_instructions>\n")
        sb.append("</skill_content>")
        return sb.toString()
    }

    public func renderMultipleSkills(skills: Array<Skill>): String {
        let parts = ArrayList<String>()
        for (skill in skills) {
            let rendered = renderSkillContent(skill)
            if (!rendered.isEmpty()) {
                parts.add(rendered)
            }
        }
        if (parts.size == 0) {
            return ""
        }
        let sb = StringBuilder()
        sb.append(parts[0])
        for (i in 1..parts.size) {
            sb.append("\n\n")
            sb.append(parts[i])
        }
        return sb.toString()
    }
}