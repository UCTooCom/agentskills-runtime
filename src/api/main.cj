/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.api

import std.convert.*
import std.env.{setVariable, getVariable}
import magic.config.Config
import std.fs.Path
import magic.log.LogUtils

/**
 * Main entry point for the CangjieMagic Agent Skill Runtime API
 * This starts the HTTP server and handles API requests
 */
main(args: Array<String>): Unit {
    eprintln("[DEBUG] Starting runtime with args: ${args.toString()}")
    
    // Parse command line arguments
    // Format: agentskills-runtime <port> [--skill-path <path>]
    var port = Int32(8080)
    var skillPath = ""
    
    var i = 0
    while (i < args.size) {
        if (args[i] == "--skill-path" && i + 1 < args.size) {
            skillPath = args[i + 1]
            i += 2
        } else if (i == 0) {
            // First argument is port
            try {
                let parsedPort = Int64.parse(args[0])
                if (parsedPort >= Int64(Int32.Min) && parsedPort <= Int64(Int32.Max)) {
                    port = Int32(parsedPort)
                }
            } catch (ex: Exception) {
                () // Use default port
            }
            i += 1
        } else {
            i += 1
        }
    }
    
    eprintln("[DEBUG] Parsed port: ${port.toString()}, skillPath: ${skillPath}")
    
    // If skill path is provided via command line, set it as environment variable
    // This must be done BEFORE loading .env file so it takes priority
    if (!skillPath.isEmpty()) {
        setVariable("SKILL_INSTALL_PATH", skillPath)
        eprintln("[DEBUG] Set SKILL_INSTALL_PATH to: ${skillPath}")
    }
    
    // Verify environment variable is set
    if (let Some(skillInstallPath) <- getVariable("SKILL_INSTALL_PATH")) {
        eprintln("[DEBUG] SKILL_INSTALL_PATH verified: ${skillInstallPath}")
    } else {
        eprintln("[DEBUG] SKILL_INSTALL_PATH not set")
    }
    
    // Load environment variables from .env file
    // Environment variables already set (including from command line) will NOT be overwritten
    // Try multiple locations for .env file:
    // 1. Current working directory (./.env) - for development mode
    // 2. Parent directory (../.env) - for release mode where exe is in bin/ and .env is in release/
    let envPaths = [Path("./.env"), Path("../.env")]
    var envLoadResult = ""
    for (envPath in envPaths) {
        eprintln("[DEBUG] Trying to load .env from: ${envPath}")
        let result = Config.env.load(envPath)
        eprintln("[DEBUG] Load result: ${result}")
        if (!result.contains("does not exist")) {
            envLoadResult = result
            LogUtils.info("Loaded .env from: ${envPath}")
            break
        } else {
            envLoadResult = result
        }
    }
    
    // Set log level from environment variable or default to info
    let logLevel = Config.env["LOG_LEVEL"].getOrDefault({ => "info" })
    Config.logLevel = logLevel
    
    LogUtils.info("Environment loaded: ${envLoadResult}")
    LogUtils.info("Log level set to: ${Config.logLevel}")
    
    // Final verification
    if (let Some(finalPath) <- getVariable("SKILL_INSTALL_PATH")) {
        LogUtils.info("Final SKILL_INSTALL_PATH: ${finalPath}")
    } else {
        LogUtils.info("SKILL_INSTALL_PATH not set after loading .env")
    }
    
    // Pass skillPath directly to APIRouter to ensure it's used correctly
    let apiRouter = APIRouter(port, skillPath: skillPath)
    apiRouter.start()
}