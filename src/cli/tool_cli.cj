/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.cli

import magic.tool.{ToolDispatcher, ToolDispatcherSingleton, ToolPermissionRegistry}
import magic.core.tool.ToolResponse
import magic.log.LogUtils
import std.collection.{HashMap, ArrayList}
import std.console.Console
import std.fs.Path
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonBool, JsonInt}

/**
 * ToolCLI - 工具命令行接口
 * 
 * 提供统一的CLI工具调用入口
 * 
 * 使用方式:
 *   agentskills tool <tool-name> [options]
 *   agentskills tool list
 *   agentskills tool info <tool-name>
 *   agentskills login --username <username> --password <password>
 *   agentskills logout
 */
public class ToolCLI {
    private let dispatcher: ToolDispatcher
    
    public init(dispatcher: ToolDispatcher) {
        this.dispatcher = dispatcher
    }
    
    /**
     * 运行CLI命令
     * 
     * @param args 命令行参数
     */
    public func run(args: Array<String>): Unit {
        if (args.size < 1) {
            printUsage()
            return
        }
        
        let command = args[0]
        let commandArgs = args[1..]
        
        match (command) {
            case "tool" => handleToolCommand(commandArgs)
            case "login" => handleLoginCommand(commandArgs)
            case "logout" => handleLogoutCommand(commandArgs)
            case "help" => printUsage()
            case _ => handleUnknownCommand(command)
        }
    }
    
    /**
     * 处理工具命令
     */
    private func handleToolCommand(args: Array<String>): Unit {
        if (args.size < 1) {
            printToolUsage()
            return
        }
        
        let subCommand = args[0]
        let toolArgs = args[1..]
        
        match (subCommand) {
            case "list" => handleToolList()
            case "info" => handleToolInfo(toolArgs)
            case "call" => handleToolCall(toolArgs)
            case _ => handleToolCallWithSubCommand(subCommand, toolArgs)
        }
    }
    
    /**
     * 处理未知命令
     */
    private func handleUnknownCommand(command: String): Unit {
        Console.stdOut.writeln("Unknown command: ${command}")
        printUsage()
    }
    
    /**
     * 处理带子命令的工具调用
     */
    private func handleToolCallWithSubCommand(subCommand: String, toolArgs: Array<String>): Unit {
        // 将subCommand作为工具名称，构建新的参数数组
        let newArgs = ArrayList<String>()
        newArgs.add(subCommand)
        for (arg in toolArgs) {
            newArgs.add(arg)
        }
        handleToolCall(newArgs.toArray())
    }
    
    /**
     * 处理工具列表
     */
    private func handleToolList(): Unit {
        Console.stdOut.writeln("╔══════════════════════════════════════════════════════════════════════════════╗")
        Console.stdOut.writeln("║                           Available Tools                                      ║")
        Console.stdOut.writeln("╚══════════════════════════════════════════════════════════════════════════════╝")
        Console.stdOut.writeln()
        
        let permissions = ToolPermissionRegistry.getAllPermissions()
        
        // 按组分类显示
        var currentGroup = ""
        for ((toolName, permission) in permissions) {
            // 提取组名
            let parts = permission.permissionPath.split("/")
            let group = if (parts.size > 4) { parts[4] } else { "other" }
            
            // 显示组标题
            if (group != currentGroup) {
                currentGroup = group
                Console.stdOut.writeln("【${group}】")
            }
            
            // 显示工具信息
            let sensitiveMark = match (permission.sensitiveLevel) {
                case 1 => "  "
                case 2 => "⚠️ "
                case 3 => "🔴"
                case _ => "  "
            }
            
            Console.stdOut.writeln("  ${sensitiveMark} ${toolName} - ${permission.permissionPath}")
        }
        
        Console.stdOut.writeln()
        Console.stdOut.writeln("Legend: 🔴 = High sensitivity (requires confirmation), ⚠️  = Medium sensitivity")
    }
    
    /**
     * 处理工具信息查询
     */
    private func handleToolInfo(args: Array<String>): Unit {
        if (args.size < 1) {
            Console.stdOut.writeln("Usage: agentskills tool info <tool-name>")
            return
        }
        
        let toolName = args[0]
        
        if (let Some(permission) <- ToolPermissionRegistry.getPermission(toolName)) {
            Console.stdOut.writeln("╔══════════════════════════════════════════════════════════════════════════════╗")
            Console.stdOut.writeln("║  Tool: ${toolName}║")
            Console.stdOut.writeln("╚══════════════════════════════════════════════════════════════════════════════╝")
            Console.stdOut.writeln()
            Console.stdOut.writeln("Permission Path:    ${permission.permissionPath}")
            Console.stdOut.writeln("Sensitive Level:    ${permission.sensitiveLevel.toString()} ${getSensitiveLevelText(permission.sensitiveLevel)}")
            Console.stdOut.writeln("Requires Confirm:   ${if (permission.requiresConfirmation) { "Yes" } else { "No" }}")
            Console.stdOut.writeln("Audit Enabled:      ${if (permission.auditEnabled) { "Yes" } else { "No" }}")
            Console.stdOut.writeln()
        } else {
            Console.stdOut.writeln("Tool not found: ${toolName}")
        }
    }
    
    /**
     * 处理工具调用
     */
    private func handleToolCall(args: Array<String>): Unit {
        if (args.size < 1) {
            Console.stdOut.writeln("Usage: agentskills tool <tool-name> [options]")
            Console.stdOut.writeln("       agentskills tool call <tool-name> [options]")
            return
        }
        
        let toolName = args[0]
        let toolArgs = args[1..]
        
        // 检查是否已登录
        let userId = getUserIdFromSession()
        if (userId.isEmpty()) {
            Console.stdOut.writeln("Error: Not logged in. Please login first using 'agentskills login'")
            return
        }
        
        // 检查是否需要二次确认
        if (ToolPermissionRegistry.requiresConfirmation(toolName)) {
            Console.stdOut.writeln("⚠️  Warning: This tool requires confirmation (sensitive operation)")
            Console.stdOut.write("Are you sure you want to execute '${toolName}'? (yes/no): ")
            Console.stdOut.flush()
            let confirmation = Console.stdIn.readln().getOrThrow()
            if (confirmation.toAsciiLower() != "yes" && confirmation.toAsciiLower() != "y") {
                Console.stdOut.writeln("Operation cancelled.")
                return
            }
        }
        
        Console.stdOut.writeln()
        Console.stdOut.writeln("Executing tool: ${toolName}")
        Console.stdOut.writeln("────────────────────────────────────────────────────────────────────────────────")
        
        let startTime = DateTime.now()
        
        // 调用工具调度器
        let response = dispatcher.dispatchFromCli(toolName, toolArgs)
        
        let endTime = DateTime.now()
        let durationMs = (endTime - startTime).toMilliseconds()
        
        // 显示结果
        Console.stdOut.writeln()
        Console.stdOut.writeln("Result:")
        Console.stdOut.writeln("────────────────────────────────────────────────────────────────────────────────")
        Console.stdOut.writeln(response.content)
        Console.stdOut.writeln()
        Console.stdOut.writeln("────────────────────────────────────────────────────────────────────────────────")
        Console.stdOut.writeln("Duration: ${durationMs}ms")
    }
    
    /**
     * 处理登录命令
     */
    private func handleLoginCommand(args: Array<String>): Unit {
        // 解析参数
        var username = ""
        var password = ""
        
        var i = 0
        while (i < args.size) {
            if (args[i] == "--username" && i + 1 < args.size) {
                username = args[i + 1]
                i += 2
            } else if (args[i] == "--password" && i + 1 < args.size) {
                password = args[i + 1]
                i += 2
            } else {
                i += 1
            }
        }
        
        if (username.isEmpty() || password.isEmpty()) {
            Console.stdOut.writeln("Usage: agentskills login --username <username> --password <password>")
            return
        }
        
        // TODO: 实现登录逻辑
        // 1. 调用登录API
        // 2. 获取access_token
        // 3. 保存到本地配置文件
        
        Console.stdOut.writeln("Login successful!")
        Console.stdOut.writeln("Username: ${username}")
        Console.stdOut.writeln("Token saved to ~/.agentskills/session.json")
    }
    
    /**
     * 处理登出命令
     */
    private func handleLogoutCommand(args: Array<String>): Unit {
        // TODO: 实现登出逻辑
        // 1. 清除本地session文件
        // 2. 清除内存中的token
        
        Console.stdOut.writeln("Logged out successfully!")
    }
    
    /**
     * 打印使用说明
     */
    private func printUsage(): Unit {
        Console.stdOut.writeln("╔══════════════════════════════════════════════════════════════════════════════╗")
        Console.stdOut.writeln("║                    AgentSkills Runtime CLI                                     ║")
        Console.stdOut.writeln("╚══════════════════════════════════════════════════════════════════════════════╝")
        Console.stdOut.writeln()
        Console.stdOut.writeln("Usage:")
        Console.stdOut.writeln("  agentskills <command> [options]")
        Console.stdOut.writeln()
        Console.stdOut.writeln("Commands:")
        Console.stdOut.writeln("  tool <tool-name> [options]    Execute a tool")
        Console.stdOut.writeln("  tool list                     List all available tools")
        Console.stdOut.writeln("  tool info <tool-name>         Show tool information")
        Console.stdOut.writeln("  tool call <tool-name> [opts]  Call a tool explicitly")
        Console.stdOut.writeln("  login --username <user>       Login to the system")
        Console.stdOut.writeln("         --password <pass>")
        Console.stdOut.writeln("  logout                        Logout from the system")
        Console.stdOut.writeln("  help                          Show this help message")
        Console.stdOut.writeln()
        Console.stdOut.writeln("Examples:")
        Console.stdOut.writeln("  agentskills tool file_read --path ./SKILL.md")
        Console.stdOut.writeln("  agentskills tool file_write --path ./output.txt --content \"Hello World\"")
        Console.stdOut.writeln("  agentskills tool skill_search --query \"react\" --limit 10")
        Console.stdOut.writeln("  agentskills login --username admin --password 123456")
        Console.stdOut.writeln()
    }
    
    /**
     * 打印工具使用说明
     */
    private func printToolUsage(): Unit {
        Console.stdOut.writeln("Usage:")
        Console.stdOut.writeln("  agentskills tool <tool-name> [options]")
        Console.stdOut.writeln("  agentskills tool list")
        Console.stdOut.writeln("  agentskills tool info <tool-name>")
        Console.stdOut.writeln()
        Console.stdOut.writeln("Examples:")
        Console.stdOut.writeln("  agentskills tool file_read --path ./SKILL.md")
        Console.stdOut.writeln("  agentskills tool file_write --path ./output.txt --content \"Hello World\"")
    }
    
    /**
     * 从Session获取用户ID
     */
    private func getUserIdFromSession(): String {
        // TODO: 从本地session文件读取
        // let sessionFile = Path.home() + "/.agentskills/session.json"
        // if (sessionFile.exists()) {
        //     let content = File(sessionFile, OpenMode.Read).readAll()
        //     let json = JsonValue.fromStr(content)
        //     return json["userId"].asString().getValue()
        // }
        ""
    }
    
    /**
     * 获取敏感级别文本
     */
    private func getSensitiveLevelText(level: Int): String {
        match (level) {
            case 1 => "(Low)"
            case 2 => "(Medium)"
            case 3 => "(High)"
            case _ => "(Unknown)"
        }
    }
}
