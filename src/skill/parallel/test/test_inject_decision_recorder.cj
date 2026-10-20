/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel.test

import magic.skill.parallel.{InjectDecisionRecorder, InjectSource, SkillLoadDecision, ContentLevel}
import std.collection.ArrayList

public func testLogSingleDecision(): Unit {
    println("=== Test InjectDecisionRecorder single decision ===")
    let recorder = InjectDecisionRecorder()
    recorder.logInjectionDecision("skill-a", SkillLoadDecision.Loaded, "always_on", "session-1", InjectSource.AutoInit, ContentLevel.Full)
    let all = recorder.queryAll("session-1")
    println("records count: ${all.size}")
    if (all.size == 1 && all[0].skillName == "skill-a") {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected 1 record for skill-a")
    }
}

public func testLogMultipleDecisions(): Unit {
    println("=== Test InjectDecisionRecorder multiple decisions ===")
    let recorder = InjectDecisionRecorder()
    recorder.logInjectionDecision("skill-a", SkillLoadDecision.Loaded, "always_on", "session-1", InjectSource.AutoInit, ContentLevel.Full)
    recorder.logInjectionDecision("skill-b", SkillLoadDecision.Evicted, "conflict", "session-1", InjectSource.AutoTaskMatch, ContentLevel.Frontmatter)
    recorder.logInjectionDecision("skill-c", SkillLoadDecision.Skipped, "missing_dep", "session-1", InjectSource.AutoDependency, ContentLevel.Full)
    let all = recorder.queryAll("session-1")
    if (all.size == 3) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected 3 records, got ${all.size}")
    }
}

public func testQueryByInjectSource(): Unit {
    println("=== Test queryByInjectSource ===")
    let recorder = InjectDecisionRecorder()
    recorder.logInjectionDecision("skill-a", SkillLoadDecision.Loaded, "always_on", "session-1", InjectSource.AutoInit, ContentLevel.Full)
    recorder.logInjectionDecision("skill-b", SkillLoadDecision.Loaded, "task_match", "session-1", InjectSource.AutoTaskMatch, ContentLevel.Full)
    recorder.logInjectionDecision("skill-c", SkillLoadDecision.Loaded, "always_on", "session-1", InjectSource.AutoInit, ContentLevel.Full)

    let autoInitResults = recorder.queryByInjectSource("session-1", InjectSource.AutoInit)
    println("AutoInit results: ${autoInitResults.size}")
    if (autoInitResults.size == 2) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected 2 AutoInit records")
    }

    let taskMatchResults = recorder.queryByInjectSource("session-1", InjectSource.AutoTaskMatch)
    println("AutoTaskMatch results: ${taskMatchResults.size}")
    if (taskMatchResults.size == 1) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: expected 1 AutoTaskMatch record")
    }
}

public func testCrossSessionQuery(): Unit {
    println("=== Test cross session query ===")
    let recorder = InjectDecisionRecorder()
    recorder.logInjectionDecision("skill-a", SkillLoadDecision.Loaded, "always_on", "session-1", InjectSource.AutoInit, ContentLevel.Full)
    recorder.logInjectionDecision("skill-b", SkillLoadDecision.Loaded, "always_on", "session-2", InjectSource.AutoInit, ContentLevel.Full)

    let s1Results = recorder.queryAll("session-1")
    let s2Results = recorder.queryAll("session-2")
    let emptyResults = recorder.queryAll("session-3")

    if (s1Results.size == 1 && s2Results.size == 1 && emptyResults.size == 0) {
        println("   ✓ PASS")
    } else {
        println("   ✗ FAIL: session isolation incorrect")
    }
}

public func runAllInjectDecisionRecorderTests(): Unit {
    println("========================================")
    println("InjectDecisionRecorder Tests")
    println("========================================")
    testLogSingleDecision()
    println("")
    testLogMultipleDecisions()
    println("")
    testQueryByInjectSource()
    println("")
    testCrossSessionQuery()
    println("")
    println("========================================")
    println("All InjectDecisionRecorder tests completed.")
    println("========================================")
}