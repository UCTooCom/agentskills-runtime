/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

public class CentralDirectory {
    private var fileHeaders: ArrayList<FileHeader> = ArrayList<FileHeader>()

    private var digitalSignature: DigitalSignature = DigitalSignature()

    public func getFileHeaders(): ArrayList<FileHeader> {
        return fileHeaders
    }

    public func setFileHeaders(fileHeaders: ArrayList<FileHeader>): Unit {
        this.fileHeaders = fileHeaders
    }

    public func getDigitalSignature(): DigitalSignature {
        return digitalSignature
    }

    public func setDigitalSignature(digitalSignature: DigitalSignature): Unit {
        this.digitalSignature = digitalSignature
    }
}
