/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.util

public interface PasswordCallback {
    func getPassword(): Array<Rune>
}
