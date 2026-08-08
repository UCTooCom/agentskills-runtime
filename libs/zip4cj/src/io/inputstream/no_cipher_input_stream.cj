/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.inputstream

class NoDecrypter <: Decrypter {

    static let INSTANCE = NoDecrypter()

    public override func decryptData(buff: Array<Byte>): Int64 {
        return buff.size
    }
}

class NoCipherInputStream <: CipherInputStream<NoDecrypter> {
    public init(
        zipEntryInputStream: ZipEntryInputStream,
        localFileHeader: LocalFileHeader,
        password: ?Array<Rune>,
        bufferSize: Int64
    ) {
        super(zipEntryInputStream, localFileHeader, password, bufferSize, true)
        this.decrypter = initializeDecrypter(localFileHeader, password, true)
    }

    protected func initializeDecrypter(localFileHeader: LocalFileHeader, password: ?Array<Rune>, useUtf8ForPassword: Bool): NoDecrypter {
        NoDecrypter.INSTANCE
    }
}
