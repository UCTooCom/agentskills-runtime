/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

public abstract class ZipHeader {
    private var signature: ?HeaderSignature = None

    public func getSignature(): ?HeaderSignature {
        return signature
    }

    public func setSignature(signature: HeaderSignature): Unit {
        this.signature = signature
    }
}
