package magic.skill.parallel.test

import magic.skill.parallel.{ProfileMigration, ProfileSkillSpec}
import magic.memory.workspace.{AgentWorkspace, WorkspaceFile, WorkspaceFileType}
import std.collection.ArrayList

public func testProfileMigrationMigrate(): Unit {
    println("=== Test ProfileMigration.migrate (T105) ===")
    let soul = WorkspaceFile.create(WorkspaceFileType.Soul, "soul.md").withContent("I am the soul.")
    let mem = WorkspaceFile.create(WorkspaceFileType.Memory, "mem.md").withContent("Remember this.")
    // 位置参数顺序：workspacePath, agentsFile, soulFile, toolsFile, identityFile, userFile, memoryFile, heartbeatFile, dailyMemoryFiles
    let ws = AgentWorkspace("/tmp/ws", None, soul, None, None, None, mem, None, ArrayList())
    let specs = ProfileMigration().migrate(ws)
    println("spec count: ${specs.size}")
    var hasSoul = false
    var hasMem = false
    for (s in specs) {
        if (s.name == "profile-soul") { hasSoul = true }
        if (s.name == "profile-memory") { hasMem = true }
    }
    if (specs.size == 2 && hasSoul && hasMem) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected 2 specs (soul, memory)")
    }
}

public func testProfileMigrationEmpty(): Unit {
    println("=== Test ProfileMigration.migrate (empty, backward-compat) ===")
    let ws = AgentWorkspace.createEmpty("/tmp/empty")
    let specs = ProfileMigration().migrate(ws)
    if (specs.size == 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected 0 specs")
    }
}

public func testProfileSkillSpecMarkdown(): Unit {
    println("=== Test ProfileSkillSpec.toSkillMarkdown (T105) ===")
    let spec = ProfileSkillSpec("profile-soul", "skill_type: profile\nname: profile-soul\n", "body text")
    let md = spec.toSkillMarkdown()
    let ok = md.contains("skill_type: profile") && md.contains("body text") && md.contains("---")
    if (ok) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: markdown frontmatter/body missing")
    }
}

public func runAllProfileMigrationTests(): Unit {
    testProfileMigrationMigrate()
    println("")
    testProfileMigrationEmpty()
    println("")
    testProfileSkillSpecMarkdown()
    println("")
}
