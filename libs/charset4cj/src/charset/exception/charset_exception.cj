/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */

/**
 * @file
 * This file is about encoder exception
 */

package charset4cj.charset.exception

public open class CharsetException <: Exception {

    public init(msg: String) {
        super(msg)
    }

    public open func toString(): String {
        return "CharsetException: " + message
    }
}
