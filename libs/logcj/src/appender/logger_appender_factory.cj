/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file defines LoggerAppenderFactory class.
 */

package logcj.appender

/**
 * LoggerAppender factory class, mainly used to register or get the specific implementation object of LoggerAppender according to name or type.
 */
public class LoggerAppenderFactory {
    private var appenderNames = ArrayList<String>()
    private var appenderValues = ArrayList<LoggerAppender>()
    private var typeNames = ArrayList<String>()
    private var typeValues = ArrayList<LoggerAppender>()
    private var typeLock: ReentrantMutex = ReentrantMutex()

    /**
     * Constructor, initialize variables.
     */
    public init(
        appenderNames: ArrayList<String>,
        appenderValues: ArrayList<LoggerAppender>,
        typeNames: ArrayList<String>,
        typeValues: ArrayList<LoggerAppender>,
        typeLock: ReentrantMutex
    ) {
        this.appenderNames = appenderNames
        this.appenderValues = appenderValues
        this.typeNames = typeNames
        this.typeValues = typeValues
        this.typeLock = typeLock
    }

    /**
     * No-parameter constructor.
     */
    public init() {}

    /**
     * Clear logger appender.
     *
     * @return new object of this class.
     */
    public func new(): LoggerAppenderFactory {
        this.typeLock.lock()
        if (this.appenderValues.size > 0 && this.appenderNames.size > 0) {
            var index: Int64 = 0
            while (index < appenderValues.size) {
                appenderValues.get(index).getOrThrow().close()
                index++
            }
        }
        this.appenderNames = ArrayList<String>()
        this.appenderValues = ArrayList<LoggerAppender>()
        this.typeLock.unlock()
        return this
    }

    /**
     * Register logger appender.
     *
     * @param typeName logger appender type name.
     * @param typeClz logger appender type class.
     * @return new object of this class.
     */
    public func registryType(typeName: String, typeClz: LoggerAppender): LoggerAppenderFactory {
        this.typeLock.lock()
        if (typeClz is LoggerAppender) {
            typeNames.add(typeName.toAsciiLower())
            typeValues.add(typeClz)
        }
        this.typeLock.unlock()
        return this
    }

    /**
     * Get logger appender by type name.
     *
     * @param typeName appender logger type name.
     * @return implementation class of LoggerAppender. if typeName doesn't meet the condtion, return console appender logger.
     */
    public func getAppenderByType(typeName: String): LoggerAppender {
        if (this.typeNames.contains(typeName.toAsciiLower().replace("\"", ""))) {
            var index: Int64 = 0
            while (index < typeNames.size) {
                if (typeNames.get(index).getOrThrow() == typeName.toAsciiLower().replace("\"", "")) {
                    return typeValues.get(index).getOrThrow()
                }
                index++
            }
        }
        return ConsoleLoggerAppender()
    }

    /**
     * Get logger appender by name.
     *
     * @param name  appender name.
     * @return implementation class of LoggerAppender. if typeName doesn't meet the condtion, return console appender logger.
     */
    public func getAppenderByName(name: String): LoggerAppender {
        if (this.appenderNames.contains(name.toAsciiLower())) {
            var index: Int64 = 0
            while (index < appenderNames.size) {
                if (appenderNames.get(index).getOrThrow() == (name.toAsciiLower().replace("\"", ""))) {
                    return appenderValues.get(index).getOrThrow()
                }
                index++
            }
        }
        return ConsoleLoggerAppender()
    }

    /**
     * Register logger appender.
     *
     * @param name  appender name.
     * @param typename  appender type name
     * @param pattern  log pattern.
     * @param properties appender preperties.
     * @return new object of this class.
     */
    public func registerLoggerAppender(
        name: String,
        typename: String,
        pattern: String,
        properties: ArrayList<AppenderProperty>
    ): LoggerAppenderFactory {
        this.typeLock.lock()
        var appenderName = name.toAsciiLower()
        if (this.typeNames.size == 0 || this.typeValues.size == 0) {
            println("AppenderType is empty, please RegistryType at first")
            this.typeLock.unlock()

            //Error handling should return null
            return LoggerAppenderFactory()
        }

        var newObj = getAppenderByType(typename)
        newObj.initAppender(pattern, properties)
        newObj.start()
        this.appenderNames.add(appenderName)
        this.appenderValues.add(newObj)
        this.typeLock.unlock()
        return this
    }
}
