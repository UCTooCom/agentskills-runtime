/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.inputstream

class ZipStandardCipherInputStream <: CipherInputStream<StandardDecrypter> {
    public init(
        zipEntryInputStream: ZipEntryInputStream,
        localFileHeader: LocalFileHeader,
        password: ?Array<Rune>,
        bufferSize: Int64,
        useUtf8ForPassword: Bool
    ) {
        super(zipEntryInputStream, localFileHeader, password, bufferSize, useUtf8ForPassword)
        this.decrypter = initializeDecrypter(this.localFileHeader, this.password, this.useUtf8ForPassword) 
    }

    protected override func initializeDecrypter(
        localFileHeader: LocalFileHeader,
        password: ?Array<Rune>,
        useUtf8ForPassword: Bool
    ): StandardDecrypter {
        return StandardDecrypter(password, localFileHeader.getCrc(), localFileHeader.getLastModifiedTime(),
            getStandardDecrypterHeaderBytes(), useUtf8ForPassword)
    }

    private func getStandardDecrypterHeaderBytes(): Array<Byte> {
        var headerBytes: Array<Byte> = Array<Byte>(InternalZipConstants.STD_DEC_HDR_SIZE, repeat: 0)
        readRaw(headerBytes)
        return headerBytes
    }
}
