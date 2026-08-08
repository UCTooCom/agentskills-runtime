/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.crypto.PBKDF2

public abstract class PRF {
    public func initialize(P: Array<Byte>): Unit
    public func doFinal(M: Array<Byte>): Array<Byte>
    public func getHLen(): Int64
}