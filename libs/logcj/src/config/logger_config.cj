/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file defines LoggerConfig class.
 */

package logcj.config

/**
 * Logger configuration model class of log file,
 * By default, inherit root configuration, the configuration is similar to the following:
 * <logger name="Sample">
 * <level>info</level>
 * <appender-ref ref="console" />
 * <appender-ref ref="file" />
 * </logger>
 */
public class LoggerConfig {
    // Logger name.
    private var name: String

    // Logger level.
    private var level: String

    // Appender-ref list.
    private var appenderRefList: ArrayList<AppenderRef>

    /**
     * Constructor, initialize variables.
     */
    public init() {
        this.name = ""
        this.level = ""
        this.appenderRefList = ArrayList<AppenderRef>()
    }

    /**
     * Constructor, initialize variables.
     *
     * @param name logger name.
     * @param level logger level.
     * @param appenderRefList appender-ref list.
     */
    public init(name: String, level: String, appenderRefList: ArrayList<AppenderRef>) {
        this.name = name
        this.level = level
        this.appenderRefList = appenderRefList
    }

    public func getName(): String {
        return this.name
    }

    public func setName(name: String): Unit {
        this.name = name
    }

    public func getLevel(): String {
        return this.level
    }

    public func setLevel(level: String): Unit {
        this.level = level
    }

    public func getAppenderRefList(): ArrayList<AppenderRef> {
        return this.appenderRefList
    }

    public func setAppenderRefList(appenderRefList: ArrayList<AppenderRef>): Unit {
        this.appenderRefList = appenderRefList
    }
}
