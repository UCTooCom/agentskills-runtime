/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip

import std.collection.*
import magic.app.models.uctoo.AgentSkillsPO
import magic.app.services.aip.model.AcsSkill

public class AgentSkillAcsMapper {

    public static func toAcsSkill(skill: AgentSkillsPO): AcsSkill {
        let acs = AcsSkill()
        acs.skillId = skill.id
        acs.skillName = skill.name
        acs.skillDescription = skill.description.getOrDefault({ => "" })
        acs.tags = skill.tags
        acs.inputTypes = skill.parameters
        acs.outputTypes = None<String>
        return acs
    }

    public static func toAgentSkillPO(acs: AcsSkill, agentId: String, creatorId: String): AgentSkillsPO {
        let skill = AgentSkillsPO()
        skill.id = acs.skillId
        skill.name = acs.skillName
        skill.description = if (acs.skillDescription.isEmpty()) { None<String> } else { Some<String>(acs.skillDescription) }
        skill.tags = acs.tags
        skill.parameters = acs.inputTypes
        skill.creator = if (creatorId.isEmpty()) { None<String> } else { Some<String>(creatorId) }
        return skill
    }

    public static func toAcsSkillList(skills: ArrayList<AgentSkillsPO>): ArrayList<AcsSkill> {
        let result = ArrayList<AcsSkill>()
        for (skill in skills) {
            result.add(toAcsSkill(skill))
        }
        return result
    }
}