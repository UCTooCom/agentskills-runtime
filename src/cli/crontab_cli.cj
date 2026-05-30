/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.cli

import std.env.getStdOut
import std.convert.*
import std.collection.ArrayList
import magic.app.services.uctoo.{CrontabService, CrontabLogService}
import magic.app.services.crontab.{SchedulerEngine, SchedulerService}
import magic.app.services.crontab.model.TriggerType
import magic.app.models.uctoo.CrontabPO
import magic.log.LogUtils
import f_orm.*

public class CrontabCLI {
    private let crontabService: CrontabService
    private let logService: CrontabLogService
    private let schedulerService: SchedulerService

    public init() {
        crontabService = CrontabService()
        logService = CrontabLogService()
        schedulerService = SchedulerService()
    }

    public func execute(args: Array<String>): Unit {
        if (args.size == 0) {
            printUsage()
            return
        }

        match (args[0]) {
            case "list"      => listCommand()
            case "show"      => showCommand(args)
            case "trigger"   => triggerCommand(args)
            case "pause"     => pauseCommand(args)
            case "resume"    => resumeCommand(args)
            case "reload"    => reloadCommand()
            case "status"    => statusCommand()
            case "logs"      => logsCommand(args)
            case "executors" => executorsCommand()
            case "help"      => printUsage()
            case "--help"    => printUsage()
            case "-h"        => printUsage()
            case _           => getStdOut().writeln("Unknown command: ${args[0]}"); printUsage()
        }
    }

    private func listCommand(): Unit {
        let (tasks, _) = crontabService.getList(1, 100)
        getStdOut().writeln("Crontab Tasks (${tasks.size}):")
        getStdOut().writeln("  ID                                   | Name                | Group | Status | Cron              | Task")
        getStdOut().writeln("  ------------------------------------------------------------------------------------------------------------------------")
        for (task in tasks) {
            let statusStr = if (task.status == 1) { "Active" } else { "Disabled" }
            getStdOut().writeln("  ${task.id} | ${task.name} | ${task.groupName}     | ${statusStr}  | ${task.cron} | ${task.task}")
        }
    }

    private func showCommand(args: Array<String>): Unit {
        if (args.size < 2) {
            getStdOut().writeln("Usage: crontab show <id>")
            return
        }
        let id = args[1]
        let result = crontabService.getById(id)
        if (result.success) {
            if (let Some(task) <- result.data) {
                getStdOut().writeln("Task Detail:")
                getStdOut().writeln("  ID:        ${task.id}")
                getStdOut().writeln("  Name:      ${task.name}")
                getStdOut().writeln("  Group:     ${task.groupName}")
                getStdOut().writeln("  Status:    ${if (task.status == 1) {"Active"} else {"Disabled"}}")
                getStdOut().writeln("  Cron:      ${task.cron}")
                getStdOut().writeln("  Task:      ${task.task}")
                getStdOut().writeln("  Tactics:   ${task.tactics}")
                getStdOut().writeln("  Remark:    ${task.remark}")
            }
        } else {
            getStdOut().writeln("Task not found: ${id}")
        }
    }

    private func triggerCommand(args: Array<String>): Unit {
        if (args.size < 2) {
            getStdOut().writeln("Usage: crontab trigger <id>")
            return
        }
        let id = args[1]
        let result = crontabService.triggerTask(id)
        if (result.success) {
            getStdOut().writeln("Task triggered: ${id}")
        } else {
            let reason = result.reason ?? "trigger failed"
            getStdOut().writeln("Trigger failed: ${reason}")
        }
    }

    private func pauseCommand(args: Array<String>): Unit {
        if (args.size < 2) {
            getStdOut().writeln("Usage: crontab pause <id>")
            return
        }
        let id = args[1]
        let result = crontabService.pauseTask(id)
        if (result.success) {
            getStdOut().writeln("Task paused: ${id}")
        } else {
            let reason = result.reason ?? "pause failed"
            getStdOut().writeln("Pause failed: ${reason}")
        }
    }

    private func resumeCommand(args: Array<String>): Unit {
        if (args.size < 2) {
            getStdOut().writeln("Usage: crontab resume <id>")
            return
        }
        let id = args[1]
        let result = crontabService.resumeTask(id)
        if (result.success) {
            getStdOut().writeln("Task resumed: ${id}")
        } else {
            let reason = result.reason ?? "resume failed"
            getStdOut().writeln("Resume failed: ${reason}")
        }
    }

    private func reloadCommand(): Unit {
        schedulerService.reloadAllTasks()
        getStdOut().writeln("All tasks reloaded")
    }

    private func statusCommand(): Unit {
        let status = schedulerService.getSchedulerStatus()
        getStdOut().writeln("Scheduler Status:")
        getStdOut().writeln("  Running:      ${status.isRunning}")
        getStdOut().writeln("  Total Tasks:  ${status.totalTasks}")
        getStdOut().writeln("  Active Tasks: ${status.activeTasks}")
        getStdOut().writeln("  Running Now:  ${status.runningTasks}")

        if (status.isRunning) {
            let runningIds = schedulerService.getRunningTasks()
            if (runningIds.size > 0) {
                getStdOut().writeln("  Running IDs:  ${runningIds}")
            }
        }
    }

    private func logsCommand(args: Array<String>): Unit {
        var limit: Int64 = 20
        if (args.size >= 2) {
            limit = Int64.parse(args[1])
        }

        let logs = logService.getRecentLogs(limit)
        getStdOut().writeln("Recent Logs (${logs.size}):")
        getStdOut().writeln("  CrontabID                           | Status | Time(ms) | TriggerType | Message")
        getStdOut().writeln("  ------------------------------------------------------------------------------------------------------------------------")
        for (log in logs) {
            let statusStr = if (log.status == 1) { "OK" } else { "FAIL" }
            let triggerType = match (log.triggerType) { case Some(v) => v; case None => "cron" }
            let errMsg = if (log.errorMessage.size > 40) { log.errorMessage[0..40] } else { log.errorMessage }
            getStdOut().writeln("  ${log.crontabId} | ${statusStr}   | ${log.usedTime}       | ${triggerType}    | ${errMsg}")
        }
    }

    private func executorsCommand(): Unit {
        getStdOut().writeln("Registered Executors:")
        getStdOut().writeln("  script  - Script Executor (script://)")
        getStdOut().writeln("  http    - HTTP Callback Executor (http://)")
        getStdOut().writeln("  builtin - Builtin Executor (builtin://)")
        getStdOut().writeln("")
        getStdOut().writeln("Builtin Tasks:")
        getStdOut().writeln("  database-cleanup  - Clean expired data")
        getStdOut().writeln("  cache-refresh     - Refresh cache")
        getStdOut().writeln("  log-rotation      - Log rotation")
        getStdOut().writeln("  health-check      - Health check")
        getStdOut().writeln("  metrics-report    - Metrics report")
    }

    private func printUsage(): Unit {
        getStdOut().writeln("Crontab Scheduler CLI")
        getStdOut().writeln("")
        getStdOut().writeln("Usage:")
        getStdOut().writeln("  skill crontab <command> [options]")
        getStdOut().writeln("")
        getStdOut().writeln("Commands:")
        getStdOut().writeln("  list                            List all crontab tasks")
        getStdOut().writeln("  show <id>                       Show task detail")
        getStdOut().writeln("  trigger <id>                    Manually trigger a task")
        getStdOut().writeln("  pause <id>                      Pause a task (group=2 forbidden)")
        getStdOut().writeln("  resume <id>                     Resume a paused task")
        getStdOut().writeln("  reload                          Reload all tasks into scheduler")
        getStdOut().writeln("  status                          Show scheduler status")
        getStdOut().writeln("  logs [limit]                    Show recent execution logs (default 20)")
        getStdOut().writeln("  executors                       List registered executors")
        getStdOut().writeln("  help                            Show this help message")
    }
}
