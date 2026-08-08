/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file defines AppenderRef class.
 */

package logcj.config

/**
 * Appender reference model class of log file.
 * The configuration is similar to the following:
 * <root>
 * <level>info</level>
 * <appender-ref ref="console" />
 * <appender-ref ref="logstash" />
 * <appender-ref ref="file" />
 * </root>
 */
public class AppenderRef {
    // Appender-ref value.
    private var ref: String = ""

    public init() {}

    /**
     * Constructor, initialize variables.
     *
     * @param ref appender-ref.
     */
    public init(ref: String) {
        this.ref = ref
    }

    /**
     * No-parameter constructor.
     */
    public func getRef(): String {
        return this.ref
    }
}
