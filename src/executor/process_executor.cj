/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.executor

import magic.log.LogUtils
import magic.utils.newProcess
import std.collection.{HashMap, ArrayList}
import std.process.SubProcess
import std.sync.Mutex
import std.time.DateTime
import std.core.Duration

public struct ProcessConfig {
    public let command: String
    public let args: Array<String>
    public let cwd: String
    public let env: Array<(String, String)>
    public let timeout: Int64
    public let captureOutput: Bool

    public init(
        command: String,
        args!: Array<String> = [],
        cwd!: String = "",
        env!: Array<(String, String)> = [],
        timeout!: Int64 = 300,
        captureOutput!: Bool = true
    ) {
        this.command = command
        this.args = args
        this.cwd = cwd
        this.env = env
        this.timeout = timeout
        this.captureOutput = captureOutput
    }
}

public struct ProcessResult {
    public let pid: Int64
    public let exitCode: Int64
    public let stdout: String
    public let stderr: String
    public let success: Bool
    public let durationMs: Int64

    public init(pid: Int64, exitCode: Int64, stdout: String, stderr: String, durationMs: Int64) {
        this.pid = pid
        this.exitCode = exitCode
        this.stdout = stdout
        this.stderr = stderr
        this.success = exitCode == 0
        this.durationMs = durationMs
    }
}

public class ProcessExecutor {
    private let mutex = Mutex()
    private var processes = HashMap<Int64, SubProcess>()
    private var active = true

    public init() {
    }

    public func execute(config: ProcessConfig): ProcessResult {
        if (!this.active) {
            throw Exception("ProcessExecutor is already shutdown")
        }

        let startTime = DateTime.now()

        LogUtils.info("[ProcessExecutor] Executing: ${config.command}")

        try {
            let subProcess = newProcess(config.command, config.args)
            
            synchronized(mutex) {
                processes[subProcess.pid] = subProcess
            }

            let exitCode = subProcess.wait()

            synchronized(mutex) {
                processes.remove(subProcess.pid)
            }

            let endTime = DateTime.now()
            let durationMs = (endTime - startTime).toMilliseconds()

            LogUtils.info("[ProcessExecutor] Process ${subProcess.pid} completed with exit code ${exitCode} in ${durationMs}ms")

            return ProcessResult(
                subProcess.pid,
                exitCode,
                "",
                "",
                durationMs
            )
        } catch (ex: Exception) {
            let endTime = DateTime.now()
            let durationMs = (endTime - startTime).toMilliseconds()
            
            LogUtils.error("[ProcessExecutor] Failed to execute: ${ex.message}")
            
            return ProcessResult(
                -1,
                -1,
                "",
                ex.message,
                durationMs
            )
        }
    }

    public func executeAll(configs: Array<ProcessConfig>): Array<ProcessResult> {
        let results = ArrayList<ProcessResult>()
        
        for (config in configs) {
            let result = execute(config)
            results.add(result)
        }
        
        return results.toArray()
    }

    public func terminateAll(): Unit {
        synchronized(mutex) {
            for ((pid, process) in processes) {
                try {
                    process.terminate(force: true)
                    LogUtils.info("[ProcessExecutor] Terminated process ${pid}")
                } catch (ex: Exception) {
                    LogUtils.info("[ProcessExecutor] Failed to terminate process ${pid}: ${ex.message}")
                }
            }
            processes.clear()
        }
    }

    public func shutdown(): Unit {
        this.active = false
        this.terminateAll()
        LogUtils.info("[ProcessExecutor] Shutdown complete")
    }

    public func getActiveProcessCount(): Int {
        synchronized(mutex) {
            return processes.size
        }
    }
}
