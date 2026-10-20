/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test.perf

import magic.core.skill.Skill
import magic.skill.{BaseSkill, CompositeSkillToolManager}
import magic.skill.parallel.SkillAutoInjector
import std.collection.{ArrayList, HashMap}
import std.time.DateTime

func toSkillList(skills: Array<BaseSkill>): ArrayList<Skill> {
    let result = ArrayList<Skill>()
    for (s in skills) {
        result.add(s)
    }
    return result
}

public func testAutoInjectLatencyPerf(): Unit {
    println("=== Perf: Auto-inject latency ===")

    let skills = ArrayList<BaseSkill>()
    for (i in 0..50) {
        let meta = HashMap<String, String>()
        meta.add("load_policy", if (i % 2 == 0) { "always_on" } else { "on_demand" })
        meta.add("priority", if (i < 10) { "high" } else if (i < 30) { "medium" } else { "low" })
        skills.add(BaseSkill(
            name: "perf-skill-${i.toString()}",
            description: "Performance test skill ${i.toString()} for keyword matching latency",
            license: None<String>,
            compatibility: None<String>,
            metadata: meta,
            allowedTools: None<String>,
            instructions: "Instructions for perf skill ${i.toString()}.",
            skillPath: ""
        ))
    }

    let manager = CompositeSkillToolManager(toSkillList(skills.toArray()))
    let injector = SkillAutoInjector.create(manager)

    let start1 = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
    let initResult = injector.injectOnInitialization("perf-session")
    let end1 = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
    let initLatency = end1 - start1
    println("init injection latency: ${initLatency.toString()}ms")

    let start2 = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
    let taskResult = injector.injectOnUserMessage("keyword matching test", "perf-session")
    let end2 = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
    let taskLatency = end2 - start2
    println("task match latency: ${taskLatency.toString()}ms")

    let start3 = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
    let _ = injector.isSkillInjected("perf-skill-0")
    let end3 = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
    let dedupLatency = end3 - start3
    println("dedup check latency: ${dedupLatency.toString()}ms")

    if (initLatency < 1000 && taskLatency < 1000 && dedupLatency < 100) {
        println("   ✓ PASS (latency within acceptable bounds)")
    } else {
        println("   ⚠ WARN: latency exceeds target (init<1000ms, task<1000ms, dedup<100ms)")
    }
}