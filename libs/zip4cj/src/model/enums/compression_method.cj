/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model.enums

public enum CompressionMethod <: Equal<CompressionMethod> {
    | STORE
    | DEFLATE
    | AES_INTERNAL_ONLY

    public func getCode(): Int32 {
        return match (this) {
            case STORE => 0
            case DEFLATE => 8
            case AES_INTERNAL_ONLY => 99
        }
    }

    public static func getCompressionMethodFromCode(code: Int32): CompressionMethod {
        match (code) {
            case 0 => return STORE
            case 8 => return DEFLATE
            case 99 => return AES_INTERNAL_ONLY
            case _ => throw ZipException("Unknown compression method", ZipExceptionType.UNKNOWN_COMPRESSION_METHOD)
        }
    }

    public operator func ==(that: CompressionMethod): Bool {
        return match ((this, that)) {
            case (STORE, STORE) => true
            case (DEFLATE, DEFLATE) => true
            case (AES_INTERNAL_ONLY, AES_INTERNAL_ONLY) => true
            case _ => false
        }
    }
}
