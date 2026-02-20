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
    
    // If skill path is provided via command line, set it as environment variable
    // This must be done BEFORE loading .env file so it takes priority
    if (!skillPath.isEmpty()) {
        setVariable("SKILL_INSTALL_PATH", skillPath)
    }
    
    // Load environment variables from .env file
    // Environment variables already set (including from command line) will NOT be overwritten
    // Try multiple locations for .env file:
    // 1. Current working directory (./.env) - for development mode
    // 2. Parent directory (../.env) - for release mode where exe is in bin/ and .env is in release/
    let envPaths = [Path("./.env"), Path("../.env")]
    for (envPath in envPaths) {
        let result = Config.env.load(envPath)
        if (!result.contains("does not exist")) {
            break
        }
    }
    
    // Set up logging configuration - must be done after loading .env
    // Use environment variables if available, otherwise use defaults
    Config.logLevel = Config.env["LOG_LEVEL"].getOrDefault({ => "debug" })
    Config.logFile = Config.env["LOG_FILE"].getOrDefault({ => "./logs/agentskills-runtime.log" })
    
    // Now we can use LogUtils - it will initialize with the correct log level
    LogUtils.info("Starting agentskills-runtime API server on port ${port}")
    LogUtils.info("Log level set to: ${Config.logLevel}")
    LogUtils.info("Log file set to: ${Config.logFile}")
    
    if (let Some(finalPath) <- getVariable("SKILL_INSTALL_PATH")) {
        LogUtils.info("SKILL_INSTALL_PATH: ${finalPath}")
    } else {
        LogUtils.info("SKILL_INSTALL_PATH not set, using default")
    }
    
    // Pass skillPath directly to APIRouter to ensure it's used correctly
    let apiRouter = APIRouter(port, skillPath: skillPath)
    apiRouter.start()
}