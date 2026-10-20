package magic.skill.parallel.test

import magic.skill.parallel.ProfileSkillResolver
import magic.core.skill.{Skill, SkillManager}
import magic.skill.BaseSkill
import std.collection.{ArrayList, HashMap}

// 极简 SkillManager mock：仅实现 resolver 所需方法，其余为 no-op
class MockSkillManager <: SkillManager {
    private let skills: HashMap<String, Skill>
    public init(skills: Array<Skill>) {
        this.skills = HashMap<String, Skill>()
        for (s in skills) {
            this.skills.add(s.name, s)
        }
    }
    public prop availableSkills: HashMap<String, Skill> {
        get() { this.skills }
    }
    public prop enabledSkills: Array<String> {
        get() {
            let arr = ArrayList<String>()
            for ((k, v) in this.skills) { arr.add(k) }
            return arr.toArray()
        }
    }
    public func addSkill(skill: Skill): Unit {}
    public func delSkill(skill: Skill): Unit {}
    public func removeSkill(skillName: String): Unit {}
    public func enableSkill(skillName: String): Unit {}
    public func disableSkill(skillName: String): Unit {}
    public func getSkill(skillName: String): Option<Skill> {
        return this.skills.get(skillName)
    }
    public func isSkillEnabled(skillName: String): Bool {
        if (let Some(_) <- this.skills.get(skillName)) {
            return true
        }
        return false
    }
}

func makeSkill(name: String, profile: Bool): Skill {
    let metadata = HashMap<String, String>()
    if (profile) {
        metadata.add("skill_type", "profile")
    }
    return BaseSkill(
        name: name,
        description: name,
        license: None<String>,
        compatibility: None<String>,
        metadata: metadata,
        allowedTools: None<String>,
        instructions: "instructions of ${name}",
        skillPath: ""
    )
}

public func testProfileSkillResolverResolve(): Unit {
    println("=== Test ProfileSkillResolver.resolve (T100) ===")
    let manager = MockSkillManager([makeSkill("p1", true), makeSkill("c1", false)])
    let resolver = ProfileSkillResolver()
    let resolved = resolver.resolve(ArrayList<String>(["p1", "missing"]), manager)
    println("resolved size: ${resolved.size}")
    if (resolved.size == 1 && resolved[0].name == "p1") {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected 1 resolved skill named p1")
    }
}

public func runAllProfileSkillResolverTests(): Unit {
    testProfileSkillResolverResolve()
    println("")
}
