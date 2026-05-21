package magic.app.services.crontab.executor

import magic.app.services.crontab.model.{CrontabExecutionContext, ExecutionResult}

public interface CrontabExecutor {
    prop scheme: String

    func execute(context: CrontabExecutionContext): ExecutionResult

    func validate(taskUri: String): Bool
}
