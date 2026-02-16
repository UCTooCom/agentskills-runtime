/*
 * Copyright (c) 2026. All rights reserved.
 */
package magic.examples.find_skills_skill

import magic.examples.find_skills_skill.src.FindSkillsSkill
import magic.skill.domain.models.SkillManifest
import std.collection.HashMap
import stdx.encoding.json.JsonValue

main() {
    println("FindSkills Skill - Standalone Test")
    println("====================================")
    
    let manifest = SkillManifest(
        name: "find-skills",
        description: "Helps users discover and install agent skills",
        license: Some("MIT"),
        compatibility: Some("Requires Node.js and npm"),
        metadata: HashMap<String, String>(),
        allowedTools: Some("Bash(npx:*)"),
        instructions: "This skill helps you discover and install skills from the open agent skills ecosystem.",
        skillPath: "./src/examples/find_skills_skill",
        scriptsDirExists: false,
        referencesDirExists: false,
        assetsDirExists: false,
        parameters: []
    )
    
    let skill = FindSkillsSkill(manifest)
    
    println("Skill Name: ${skill.name}")
    println("Skill Description: ${skill.description}")
    println("")
    
    let args = HashMap<String, JsonValue>()
    args.add("query", JsonValue.fromStr("\"react testing\""))
    
    println("Executing skill with query: 'react testing'")
    println("----------------------------------------")
    let result = skill.execute(args)
    println(result)
}
