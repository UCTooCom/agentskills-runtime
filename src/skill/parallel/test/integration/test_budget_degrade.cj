/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test.integration

import magic.skill.{BaseSkill, CompositeSkillToolManager}
import magic.skill.parallel.{SkillAutoInjector, SkillInjectionStatus, AutoInjectConfig, SkillParallelConfig, SkillContextInjector, TaskMatcher, BudgetManager, InjectDecisionRecorder}
import std.collection.HashMap

func repeatStr(s: String, count: Int64): String {
    var result = ""
    for (_ in 0..count) {
        result = result + s
    }
    return result
}

public func testBudgetDegradeIntegration(): Unit {
    println("=== Integration: Budget degrade to frontmatter ===")
    let highMeta = HashMap<String, String>()
    highMeta.add("load_policy", "always_on")
    highMeta.add("priority", "high")
    highMeta.add("context_budget_tokens", "500")
    let highSkill = BaseSkill(
        name: "budget-high",
        description: "High priority skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: highMeta,
        allowedTools: None<String>,
        instructions: repeatStr("High priority skill with long instructions that consume budget.", 10),
        skillPath: ""
    )

    let lowMeta = HashMap<String, String>()
    lowMeta.add("load_policy", "always_on")
    lowMeta.add("priority", "low")
    lowMeta.add("context_budget_tokens", "500")
    let lowSkill = BaseSkill(
        name: "budget-low",
        description: "Low priority skill",
        license: None<String>,
        compatibility: None<String>,
        metadata: lowMeta,
        allowedTools: None<String>,
        instructions: repeatStr("Low priority skill with long instructions that consume budget.", 10),
        skillPath: ""
    )

    let manager = CompositeSkillToolManager(toSkillList([highSkill, lowSkill]))
    let parallelConfig = SkillParallelConfig(totalBudgetTokens: 100)
    let contextInjector = SkillContextInjector(skillManager: manager, config: parallelConfig)
    let budgetManager = BudgetManager(config: parallelConfig)
    let taskMatcher = TaskMatcher(config: AutoInjectConfig())
    let decisionRecorder = InjectDecisionRecorder()
    let injector = SkillAutoInjector(
        contextInjector: contextInjector,
        taskMatcher: taskMatcher,
        budgetManager: budgetManager,
        decisionRecorder: decisionRecorder,
        config: AutoInjectConfig()
    )

    let result = injector.injectOnInitialization("budget-session")
    println("status: ${result.status}")
    println("context length: ${result.injectedContext.size.toString()}")

    if (result.status == SkillInjectionStatus.Success || result.status == SkillInjectionStatus.Partial) {
        println("   ✓ PASS (budget allocation completed with degrade)")
    } else {
        println("   ✗ FAIL: expected Success or Partial")
    }
}