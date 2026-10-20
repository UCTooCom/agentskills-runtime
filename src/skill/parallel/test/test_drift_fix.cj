/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test

import magic.core.skill.Skill
import magic.skill.{BaseSkill, CompositeSkillToolManager}
import magic.skill.parallel.{SkillAutoInjector, AutoInjectConfig, SkillInjectionStatus}
import std.collection.{ArrayList, HashMap}

func toSkillList(skills: Array<BaseSkill>): ArrayList<Skill> {
    let result = ArrayList<Skill>()
    for (s in skills) {
        result.add(s)
    }
    return result
}

func createDriftFixSkills(): Array<BaseSkill> {
    let alwaysOnMeta = HashMap<String, String>()
    alwaysOnMeta.add("load_policy", "always_on")
    let alwaysOnSkill = BaseSkill(
        name: "drift-always-on",
        description: "Always on skill for drift fix test",
        license: None<String>,
        compatibility: None<String>,
        metadata: alwaysOnMeta,
        allowedTools: None<String>,
        instructions: "Always on instructions for drift fix.",
        skillPath: ""
    )

    let onDemandMeta = HashMap<String, String>()
    onDemandMeta.add("load_policy", "on_demand")
    let onDemandSkill = BaseSkill(
        name: "drift-on-demand",
        description: "On demand skill for cangjie coding",
        license: None<String>,
        compatibility: None<String>,
        metadata: onDemandMeta,
        allowedTools: None<String>,
        instructions: "On demand instructions.",
        skillPath: ""
    )

    return [alwaysOnSkill, onDemandSkill]
}

func createDriftFixInjector(): SkillAutoInjector {
    createDriftFixInjector(AutoInjectConfig())
}

func createDriftFixInjector(config: AutoInjectConfig): SkillAutoInjector {
    let skills = createDriftFixSkills()
    let manager = CompositeSkillToolManager(toSkillList(skills))
    return SkillAutoInjector.create(manager, config)
}

public func testDriftFixAlwaysOnAutoInject(): Unit {
    println("=== Drift Fix: AlwaysOn skill auto-injected on initialization ===")
    let injector = createDriftFixInjector()
    let result = injector.injectOnInitialization("drift-session-1")
    println("status: ${result.status}, context length: ${result.injectedContext.size}")
    if (result.status == SkillInjectionStatus.Success && result.injectedContext.contains("<skill_content") && result.injectedContext.contains("drift-always-on")) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected Success with skill_content for always_on skill")
    }
}

public func testDriftFixAutoInjectDisabled(): Unit {
    println("=== Drift Fix: autoInjectEnabled=false returns empty (backward compat) ===")
    let config = AutoInjectConfig(autoInjectEnabled: false)
    let injector = createDriftFixInjector(config)
    let result = injector.injectOnInitialization("drift-session-2")
    println("status: ${result.status}, context length: ${result.injectedContext.size}")
    if (result.injectedContext.isEmpty()) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected empty context when autoInjectEnabled=false")
    }
}

public func testDriftFixTaskMatchInject(): Unit {
    println("=== Drift Fix: Task match auto-inject on user message ===")
    let injector = createDriftFixInjector()
    let result = injector.injectOnUserMessage("编写仓颉代码实现用户登录", "drift-session-3")
    println("status: ${result.status}, context length: ${result.injectedContext.size}")
    if (result.status == SkillInjectionStatus.Success) {
        println("   ✓ PASS (task match injection completed)")
    } else {
        println("   ✗ FAIL: expected Success for task match injection")
    }
}

public func testDriftFixExplicitInject(): Unit {
    println("=== Drift Fix: Explicit /skill-name injection ===")
    let injector = createDriftFixInjector()
    let result = injector.injectExplicit("drift-on-demand", "drift-session-4")
    println("status: ${result.status}, context length: ${result.injectedContext.size}")
    if (result.status == SkillInjectionStatus.Success && result.injectedContext.contains("drift-on-demand")) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected Success with skill content for explicit injection")
    }
}

public func testDriftFixNoMatchNoInject(): Unit {
    println("=== Drift Fix: No match returns empty ===")
    let injector = createDriftFixInjector()
    let result = injector.injectOnUserMessage("xyzqwerty nomatch", "drift-session-5")
    println("status: ${result.status}, context length: ${result.injectedContext.size}")
    if (result.injectedContext.isEmpty()) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected empty context for non-matching task")
    }
}

public func testDriftFixDedupAfterInject(): Unit {
    println("=== Drift Fix: isSkillInjected returns true after injection ===")
    let injector = createDriftFixInjector()
    injector.injectOnInitialization("drift-session-6")
    let isInjected = injector.isSkillInjected("drift-always-on")
    println("isSkillInjected: ${isInjected.toString()}")
    if (isInjected) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected isSkillInjected=true after injection")
    }
}

public func testDriftFixDedupBeforeInject(): Unit {
    println("=== Drift Fix: isSkillInjected returns false before injection ===")
    let injector = createDriftFixInjector()
    let isInjected = injector.isSkillInjected("drift-always-on")
    println("isSkillInjected: ${isInjected.toString()}")
    if (!isInjected) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected isSkillInjected=false before injection")
    }
}

public func testDriftFixDedupDisabled(): Unit {
    println("=== Drift Fix: dedupOnReinject=false skips dedup ===")
    let config = AutoInjectConfig(dedupOnReinject: false)
    let injector = createDriftFixInjector(config)
    injector.injectOnInitialization("drift-session-7")
    let isInjected = injector.isSkillInjected("drift-always-on")
    println("isSkillInjected: ${isInjected.toString()}")
    if (!isInjected) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected isSkillInjected=false when dedupOnReinject=false")
    }
}

public func testDriftFixFactoryCreate(): Unit {
    println("=== Drift Fix: SkillAutoInjector.create factory ===")
    let skills = createDriftFixSkills()
    let manager = CompositeSkillToolManager(toSkillList(skills))
    let injector = SkillAutoInjector.create(manager)
    let result = injector.injectOnInitialization("drift-session-8")
    println("status: ${result.status}, context length: ${result.injectedContext.size}")
    if (result.status == SkillInjectionStatus.Success && result.injectedContext.contains("<skill_content")) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected Success with skill_content from factory-created injector")
    }
}

public func testDriftFixAll(): Unit {
    println("============ Drift Fix Tests ============")
    testDriftFixAlwaysOnAutoInject()
    testDriftFixAutoInjectDisabled()
    testDriftFixTaskMatchInject()
    testDriftFixExplicitInject()
    testDriftFixNoMatchNoInject()
    testDriftFixDedupAfterInject()
    testDriftFixDedupBeforeInject()
    testDriftFixDedupDisabled()
    testDriftFixFactoryCreate()
    println("============ Drift Fix Tests Done ============")
}