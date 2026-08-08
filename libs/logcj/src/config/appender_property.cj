/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file defines AppenderProperty class.
 */

package logcj.config

/**
 * Appender property model class of log file.
 * The configuration is similar to the following:
 * <appender enabled="true" name="file">
 * ...
 * <property name="filename">test.log</property>
 * ...
 * </appender>
 */
public class AppenderProperty {
    // Property name.
    private var name: String = ""

    // Property value.
    private var value: String = ""

    /**
     * Constructor, initialize variables.
     *
     * @param name property name.
     * @param value property value.
     */
    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }

    /**
     * No-parameter constructor.
     */
    public init() {}

    public func getName(): String {
        return this.name
    }

    public func setName(name: String): Unit {
        this.name = name
    }

    public func getValue(): String {
        return this.value
    }

    public func setValue(value: String): Unit {
        this.value = value
    }
}
