/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file defines RootLoggerConfig class.
 */

package logcj.config

/**
 * Root configuration model class of log file,
 * The configuration is similar to the following:
 * <root>
 * <level>info</level>
 * <appender-ref ref="console" />
 * <appender-ref ref="file" />
 * </root>
 */
public class RootLoggerConfig {
    // Root level.
    private var level: String

    // Root appender-ref list. 
    private var appenderRefList: ArrayList<AppenderRef>

    /**
     * Constructor, initialize variables.
     */
    public init() {
        this.level = ""
        this.appenderRefList = ArrayList<AppenderRef>()
    }

    /**
     * Constructor, initialize variables.
     *
     * @param level root level.
     * @param appenderRefList root appender-ref list.
     */
    public init(level: String, appenderRefList: ArrayList<AppenderRef>) {
        this.level = level
        this.appenderRefList = appenderRefList
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
