/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file defines LoggerConfig class.
 */

package logcj.config

/**
 * Model class corresponding to the log configuration file.
 * The main configurations are as follows:
 * Appender configuration, root configuration, logger Congiguration.
 */
public class LoggerConfiguration {
    // Appender configuration list.
    private var appenders = ArrayList<AppenderConfig>()

    // Root configuration, default log level: INFO.
    private var root: RootLoggerConfig = RootLoggerConfig(DEFAULT_LOG_LEVEL.levelName(), ArrayList<AppenderRef>())

    // Logger configuration list.
    private var logger = ArrayList<LoggerConfig>()

    /**
     * Constructor, initialize variables.
     *
     * @param appenders appender configuration list.
     * @param root root configuration.
     * @param logger logger configuration list.
     */
    public init(appenders: ArrayList<AppenderConfig>, root: RootLoggerConfig, logger: ArrayList<LoggerConfig>) {
        this.appenders = appenders
        this.root = root
        this.logger = logger
    }

    /**
     * No-parameter constructor.
     */
    public init() {}

    public func getAppenders(): ArrayList<AppenderConfig> {
        return this.appenders
    }

    public func getRoot(): RootLoggerConfig {
        return this.root
    }

    public func getLogger(): ArrayList<LoggerConfig> {
        return this.logger
    }
}
