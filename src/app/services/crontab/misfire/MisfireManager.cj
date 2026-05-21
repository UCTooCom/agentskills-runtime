package magic.app.services.crontab.misfire

import std.time.DateTime
import magic.log.LogUtils
import magic.app.models.uctoo.CrontabPO
import magic.app.services.crontab.model.dateTimeToEpochMs

public enum MisfireAction {
    | ExecuteNow
    | ExecuteOnce
    | Skip
}

public class MisfireManager {
    public func checkAndHandle(crontab: CrontabPO, now: DateTime): MisfireAction {
        let policy = misfirePolicyFromTactics(crontab.tactics)

        let lastExecOpt = crontab.lastExecutedAt
        let nextExecOpt = crontab.nextExecutedAt

        var isMisfire = false
        match (nextExecOpt) {
            case Some(nextExec) =>
                let nowMs = dateTimeToEpochMs(now)
                let nextMs = dateTimeToEpochMs(nextExec)
                if (nowMs > nextMs + getThresholdSeconds(crontab) * 1000) {
                    isMisfire = true
                }
            case None =>
                isMisfire = false
        }

        if (!isMisfire) {
            return MisfireAction.Skip
        }

        match (policy) {
            case FireNow =>
                LogUtils.info("MisfireManager", "错过执行, 策略=FireNow, 任务=${crontab.name}")
                return MisfireAction.ExecuteNow
            case FireOnce =>
                LogUtils.info("MisfireManager", "错过执行, 策略=FireOnce, 任务=${crontab.name}")
                return MisfireAction.ExecuteOnce
            case Ignore =>
                LogUtils.info("MisfireManager", "错过执行, 策略=Ignore, 任务=${crontab.name}")
                return MisfireAction.Skip
        }
    }

    private func getThresholdSeconds(crontab: CrontabPO): Int64 {
        match (crontab.misfireThreshold) {
            case Some(t) => if (t > 0) { Int64(t) } else { 0 }
            case None => 0
        }
    }
}
