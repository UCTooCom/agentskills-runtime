/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.crypto

public interface Encrypter {
    func encryptData(buff: Array<Byte>): Int64
}
