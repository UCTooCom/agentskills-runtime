package magic.app.services.crontab.model

public class ExecutionResult {
    public var success: Bool = false
    public var exitCode: Int32 = 0
    public var output: String = ""
    public var errorOutput: String = ""
    public var duration: Int64 = 0
    public var resultSummary: String = ""

    public init() {}

    public init(success!: Bool, exitCode!: Int32, output!: String, errorOutput!: String, duration!: Int64, resultSummary!: String) {
        this.success = success
        this.exitCode = exitCode
        this.output = output
        this.errorOutput = errorOutput
        this.duration = duration
        this.resultSummary = resultSummary
    }

    public static func successResult(output: String, duration: Int64, summary: String): ExecutionResult {
        let r = ExecutionResult()
        r.success = true
        r.exitCode = 0
        r.output = output
        r.duration = duration
        r.resultSummary = summary
        r
    }

    public static func failureResult(errorOutput: String, duration: Int64, exitCode: Int32): ExecutionResult {
        let r = ExecutionResult()
        r.success = false
        r.exitCode = exitCode
        r.errorOutput = errorOutput
        r.duration = duration
        r
    }
}
