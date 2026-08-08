/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

public class AESExtraDataRecord <: ZipHeader {
    private var dataSize: Int64

    private var aesVersion: AesVersion

    private var vendorID: String

    private var aesKeyStrength: AesKeyStrength

    private var compressionMethod: CompressionMethod

    public init() {
        dataSize = 7
        aesVersion = AesVersion.TWO
        vendorID = "AE"
        aesKeyStrength = AesKeyStrength.KEY_STRENGTH_256
        compressionMethod = CompressionMethod.DEFLATE
        setSignature(HeaderSignature.AES_EXTRA_DATA_RECORD)
    }

    public func getDataSize(): Int64 {
        return dataSize
    }

    public func setDataSize(dataSize: Int64): Unit {
        this.dataSize = dataSize
    }

    public func getAesVersion(): AesVersion {
        return aesVersion
    }

    public func setAesVersion(aesVersion: AesVersion): Unit {
        this.aesVersion = aesVersion
    }

    public func getVendorID(): String {
        return vendorID
    }

    public func setVendorID(vendorID: String): Unit {
        this.vendorID = vendorID
    }

    public func getAesKeyStrength(): AesKeyStrength {
        return aesKeyStrength
    }

    public func setAesKeyStrength(aesKeyStrength: AesKeyStrength): Unit {
        this.aesKeyStrength = aesKeyStrength
    }

    public func getCompressionMethod(): CompressionMethod {
        return compressionMethod
    }

    public func setCompressionMethod(compressionMethod: CompressionMethod): Unit {
        this.compressionMethod = compressionMethod
    }
}
