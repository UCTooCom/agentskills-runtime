/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.cli

import std.env.getStdOut
import std.collection.ArrayList
import std.fs.File
import magic.app.services.uctoo.{ConfigService, ConfigSyncHandler}
import magic.log.LogUtils
import f_orm.*

public class ConfigCLI {
    private let configService: ConfigService
    private let syncHandler: ConfigSyncHandler

    public init() {
        configService = ConfigService()
        syncHandler = ConfigSyncHandler()
    }

    public func execute(args: Array<String>): Unit {
        if (args.size == 0) {
            printUsage()
            return
        }

        match (args[0]) {
            case "get"     => getCommand(args)
            case "list"    => listCommand(args)
            case "set"     => setCommand(args)
            case "unset"   => unsetCommand(args)
            case "export"  => exportCommand(args)
            case "import"  => importCommand(args)
            case "sync"    => syncCommand(args)
            case "help"    => printUsage()
            case "--help"  => printUsage()
            case "-h"      => printUsage()
            case _         => getStdOut().writeln("Unknown command: ${args[0]}"); printUsage()
        }
    }

    private func getCommand(args: Array<String>): Unit {
        if (args.size < 2) {
            getStdOut().writeln("Usage: config get <key>")
            return
        }
        let key = args[1]
        let result = configService.getConfigByKey(key)
        if (result.success) {
            match (result.data) {
                case Some(config) =>
                    getStdOut().writeln("Config: ${key}")
                    getStdOut().writeln("  Value:    ${config.value ?? ""}")
                    getStdOut().writeln("  Group:    ${config.configGroup ?? "other"}")
                    getStdOut().writeln("  Type:     ${config.configType ?? "string"}")
                    getStdOut().writeln("  Editable: ${match (config.editable) { case Some(v) => v; case None => true }}")
                case None =>
                    getStdOut().writeln("Config not found: ${key}")
            }
        } else {
            let reason = result.reason ?? "query failed"
            getStdOut().writeln("Error: ${reason}")
        }
    }

    private func listCommand(args: Array<String>): Unit {
        var group = ""
        var i = 1
        while (i < args.size) {
            if (args[i] == "--group" && i + 1 < args.size) {
                group = args[i + 1]
                i += 2
            } else {
                i++
            }
        }

        let result = if (group.isEmpty()) {
            configService.getAllConfigs()
        } else {
            configService.getConfigsByGroup(group)
        }

        if (result.success) {
            match (result.data) {
                case Some(configs) =>
                    getStdOut().writeln("Config Items (${configs.size}):")
                    getStdOut().writeln("  EnvKey                              | Value                    | Group        | Type    | Sensitive")
                    getStdOut().writeln("  ------------------------------------------------------------------------------------------------------------------------")
                    for (config in configs) {
                        let envKey = config.envKey ?? ""
                        let value = match (config.value) {
                            case Some(v) => if (v.size > 25) { v[0..25] + "..." } else { v }
                            case None => ""
                        }
                        let configGroup = config.configGroup ?? "other"
                        let configType = config.configType ?? "string"
                        let isSensitive = match (config.isSensitive) { case Some(v) => v; case None => false }
                        getStdOut().writeln("  ${envKey} | ${value} | ${configGroup} | ${configType} | ${isSensitive}")
                    }
                case None =>
                    getStdOut().writeln("No configs found")
            }
        } else {
            let reason = result.reason ?? "query failed"
            getStdOut().writeln("Error: ${reason}")
        }
    }

    private func setCommand(args: Array<String>): Unit {
        if (args.size < 3) {
            getStdOut().writeln("Usage: config set <key> <value>")
            return
        }
        let key = args[1]
        let value = args[2]
        let result = configService.updateConfigByKey(key, value, "cli", "cli")
        if (result.success) {
            getStdOut().writeln("Config ${key} updated successfully")
        } else {
            let reason = result.reason ?? "update failed"
            getStdOut().writeln("Error: ${reason}")
        }
    }

    private func unsetCommand(args: Array<String>): Unit {
        if (args.size < 2) {
            getStdOut().writeln("Usage: config unset <key>")
            return
        }
        let key = args[1]
        let result = configService.updateConfigByKey(key, "", "cli", "cli")
        if (result.success) {
            getStdOut().writeln("Config ${key} unset successfully")
        } else {
            let reason = result.reason ?? "unset failed"
            getStdOut().writeln("Error: ${reason}")
        }
    }

    private func exportCommand(args: Array<String>): Unit {
        var format = "env"
        var i = 1
        while (i < args.size) {
            if (args[i] == "--format" && i + 1 < args.size) {
                format = args[i + 1]
                i += 2
            } else {
                i++
            }
        }

        let result = configService.exportConfig(format)
        if (result.success) {
            match (result.data) {
                case Some(data) => getStdOut().writeln(data)
                case None => getStdOut().writeln("No data to export")
            }
        } else {
            let reason = result.reason ?? "export failed"
            getStdOut().writeln("Error: ${reason}")
        }
    }

    private func importCommand(args: Array<String>): Unit {
        var filePath = ""
        var format = "env"
        var i = 1
        while (i < args.size) {
            if (args[i] == "--file" && i + 1 < args.size) {
                filePath = args[i + 1]
                i += 2
            } else if (args[i] == "--format" && i + 1 < args.size) {
                format = args[i + 1]
                i += 2
            } else {
                i++
            }
        }

        if (filePath.isEmpty()) {
            getStdOut().writeln("Usage: config import --file <path> [--format env|json]")
            return
        }

        try {
            let content = String.fromUtf8(File.readFrom(filePath))
            let result = configService.importConfig(content, format, "cli")
            if (result.success) {
                getStdOut().writeln("Config imported successfully from ${filePath}")
            } else {
                let reason = result.reason ?? "import failed"
                getStdOut().writeln("Error: ${reason}")
            }
        } catch (e: Exception) {
            getStdOut().writeln("Error reading file ${filePath}: ${e.message}")
        }
    }

    private func syncCommand(args: Array<String>): Unit {
        var direction = "from-env"
        if (args.size >= 2) {
            direction = args[1]
        }

        match (direction) {
            case "from-env" =>
                let result = syncHandler.manualSyncFromEnv()
                getStdOut().writeln("Sync from .env completed: ${result.successCount}/${result.totalCount} succeeded, ${result.failedCount} failed")
                for (detail in result.details) {
                    if (!detail.success) {
                        getStdOut().writeln("  Failed: ${detail.envKey} - ${detail.errorMessage ?? "unknown error"}")
                    }
                }
            case _ =>
                getStdOut().writeln("Unknown sync direction: ${direction}")
                getStdOut().writeln("Usage: config sync [from-env]")
        }
    }

    private func printUsage(): Unit {
        getStdOut().writeln("System Config CLI")
        getStdOut().writeln("")
        getStdOut().writeln("Usage:")
        getStdOut().writeln("  skill config <command> [options]")
        getStdOut().writeln("")
        getStdOut().writeln("Commands:")
        getStdOut().writeln("  get <key>                       Get config value by env key")
        getStdOut().writeln("  list [--group <group>]          List all configs, optionally filtered by group")
        getStdOut().writeln("  set <key> <value>               Set config value")
        getStdOut().writeln("  unset <key>                     Unset config value (set to empty)")
        getStdOut().writeln("  export [--format env|json]      Export configs (default: env)")
        getStdOut().writeln("  import --file <path> [--format] Import configs from file")
        getStdOut().writeln("  sync [from-env]                 Sync configs from .env file to database")
        getStdOut().writeln("  help                            Show this help message")
    }
}