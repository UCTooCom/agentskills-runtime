/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

/*
 * RSA Public/Private Key provider.
 */
public interface RSAKeyProvider<U, R> <: KeyProvider<U, R> {
    mut prop padType: PadOption {
        get() {
            PKCS1
        }
        set(_) {}
    }
}
