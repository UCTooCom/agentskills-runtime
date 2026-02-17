/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.api

import std.convert.*
import magic.config.Config
import std.fs.Path
import magic.log.LogUtils

/**
 * Main entry point for the CangjieMagic Agent Skill Runtime API
 * This starts the HTTP server and handles API requests
 */
main(args: Array<String>): Unit {
    // Set log level to info
    Config.logLevel = "info"
    
    // Load environment variables from .env file
    let envLoadResult = Config.env.load(Path("./.env"))
    LogUtils.info("Environment loaded: ${envLoadResult}")
    
    let port = if (args.size > 0) {
        try {
            let parsedPort = Int64.parse(args[0])
            if (parsedPort >= Int64(Int32.Min) && parsedPort <= Int64(Int32.Max)) {
                Int32(parsedPort)
            } else {
                Int32(8080)
            }
        } catch (ex: Exception) {
            Int32(8080)  // Default port
        }
    } else {
        Int32(8080)  // Default port
    }
    
    let apiRouter = APIRouter(port)
    apiRouter.start()
}