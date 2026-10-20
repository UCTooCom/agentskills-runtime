/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

import magic.log.LogUtils
import std.collection.ArrayList
import std.time.DateTime

public class InjectDecisionRecorder {
    private var _records: ArrayList<InjectionDecisionRecord>

    public init() {
        _records = ArrayList<InjectionDecisionRecord>()
    }

    public func logInjectionDecision(
        skillName: String,
        decision: SkillLoadDecision,
        reason: String,
        sessionId: String,
        injectSource: InjectSource,
        contentLevel: ContentLevel
    ): Unit {
        let record = InjectionDecisionRecord(
            skillName: skillName,
            decision: decision,
            reason: reason,
            sessionId: sessionId,
            timestamp: (DateTime.now() - DateTime.UnixEpoch).toMilliseconds(),
            injectSource: injectSource,
            contentLevel: contentLevel
        )
        _records.add(record)
        LogUtils.info("[InjectDecision] skill=${skillName}, decision=${decision}, reason=${reason}, session=${sessionId}, source=${injectSource}, level=${contentLevel}")
    }

    public func queryByInjectSource(sessionId: String, injectSource: InjectSource): ArrayList<InjectionDecisionRecord> {
        let result = ArrayList<InjectionDecisionRecord>()
        for (record in _records) {
            if (record.sessionId == sessionId && record.injectSource == injectSource) {
                result.add(record)
            }
        }
        return result
    }

    public func queryAll(sessionId: String): ArrayList<InjectionDecisionRecord> {
        let result = ArrayList<InjectionDecisionRecord>()
        for (record in _records) {
            if (record.sessionId == sessionId) {
                result.add(record)
            }
        }
        return result
    }
}