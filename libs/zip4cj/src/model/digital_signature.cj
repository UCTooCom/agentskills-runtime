/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

public class DigitalSignature <: ZipHeader {
    private var sizeOfData: Int32 = 0

    private var signatureData: ?String = None

    public func getSizeOfData(): Int32 {
        return sizeOfData
    }

    public func setSizeOfData(sizeOfData: Int32): Unit {
        this.sizeOfData = sizeOfData
    }

    public func getSignatureData(): ?String {
        return signatureData
    }

    public func setSignatureData(signatureData: String): Unit {
        this.signatureData = signatureData
    }
}
