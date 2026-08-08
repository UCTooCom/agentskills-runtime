/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.exception

public class ZipException <: Exception {
    private static let serialVersionUID: Int64 = 1
    private var typeEnum: ZipExceptionType = ZipExceptionType.UNKNOWN
    public init(message: String) {
        super(message)
    }

    public init(message: String, typeEnum: ZipExceptionType) {
        super(message)
        this.typeEnum = typeEnum
    }

    public func getType(): ZipExceptionType {
        return typeEnum
    }

    public override func toString(): String {
        if (message == "") {
            return "ZipException"
        } else {
            return "ZipException: ${message}"
        }
    }
}

public class ZipIOException <: Exception {
    public init(message: String) {
        super(message)
    }

    public override func toString(): String {
        if (message == "") {
            return "ZipIOException"
        } else {
            return "ZipIOException: ${message}"
        }
    }
}

public class UnsupportedOperationException <: Exception {
    public init() {
        super()
    }

    public override func toString(): String {
        if (message == "") {
            return "UnsupportedOperationException"
        } else {
            return "UnsupportedOperationException: ${message}"
        }
    }
}

public class BufferUnderflowException <: Exception {
    public init() {
        super()
    }

    public override func toString(): String {
        if (message == "") {
            return "BufferUnderflowException"
        } else {
            return "BufferUnderflowException: ${message}"
        }
    }
}

public enum ZipExceptionType {
    | WRONG_PASSWORD
    | TASK_CANCELLED_EXCEPTION
    | CHECKSUM_MISMATCH
    | UNKNOWN_COMPRESSION_METHOD
    | FILE_NOT_FOUND
    | UNSUPPORTED_ENCRYPTION
    | UNKNOWN
}
