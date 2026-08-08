/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */

/**
 * @file
 * This file is about encoder exception
 */

package charset4cj.charset.exception

public class EncoderException <: CharsetException {

    public init(msg: String) {
        super(msg)
    }

    public func toString(): String {
        return "EncoderException: " + message
    }
}
