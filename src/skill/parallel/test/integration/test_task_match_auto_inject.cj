/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test.integration
import magic.skill.parallel.{SkillAutoInjector, SkillInjectionStatus, AutoInjectConfig}

import magic.skill.{BaseSkill, CompositeSkillToolManager}
import std.collection.HashMap

public func testTaskMatchAutoInjectIntegration(): Unit {
    println("=== Integration: Task match auto-inject on user message ===")
    let cangjieMeta = HashMap<String, String>()
    cangjieMeta.add("load_policy", "on_demand")
    let cangjieSkill = BaseSkill(
        name: "cangjie-coder",
        description: "仓颉代码编写技能，用于编写修改重构优化 .cj 仓颉代码文件",
        license: None<String>,
        compatibility: None<String>,
        metadata: cangjieMeta,
        allowedTools: None<String>,
        instructions: "Cangjie coding skill instructions.",
        skillPath: ""
    )
    let sddMeta = HashMap<String, String>()
    sddMeta.add("load_policy", "on_demand")
    let sddSkill = BaseSkill(
        name: "sdd-agent",
        description: "规格驱动开发技能，从需求生成设计文档和任务",
        license: None<String>,
        compatibility: None<String>,
        metadata: sddMeta,
        allowedTools: None<String>,
        instructions: "SDD agent instructions.",
        skillPath: ""
    )
    let manager = CompositeSkillToolManager(toSkillList([cangjieSkill, sddSkill]))
    let injector = SkillAutoInjector.create(manager)

    let result = injector.injectOnUserMessage("编写仓颉代码实现用户登录", "integration-session-2")
    println("status: ${result.status}")
    println("active skills: ${result.activeSkills.size.toString()}")

    if (result.status == SkillInjectionStatus.Success && result.activeSkills.size > 0) {
        println("   ✓ PASS (task match injected skills)")
    } else {
        println("   ✗ FAIL: expected task match to inject skills")
    }
}