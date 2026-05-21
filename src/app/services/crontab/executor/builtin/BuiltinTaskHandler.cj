package magic.app.services.crontab.executor.builtin

import magic.app.services.crontab.model.{CrontabExecutionContext, ExecutionResult}

public interface BuiltinTaskHandler {
    func handle(context: CrontabExecutionContext): ExecutionResult
}
