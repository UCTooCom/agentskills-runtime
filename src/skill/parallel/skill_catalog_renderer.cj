/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

import magic.core.skill.Skill

public class SkillCatalogRenderer {

    public init() {}

    public func renderCatalog(skills: Array<Skill>): String {
        let sb = StringBuilder()
        sb.append("<available_skills>\n")
        for (skill in skills) {
            sb.append("- `${skill.name}`: ${skill.description}\n")
        }
        sb.append("</available_skills>")
        return sb.toString()
    }
}