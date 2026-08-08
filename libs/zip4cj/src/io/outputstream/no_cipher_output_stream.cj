/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.outputstream

class NoEncrypter <: Encrypter {

    static let INSTANCE = NoEncrypter()

    public func encryptData(buff: Array<Byte>): Int64 {
        return encryptData(buff, 0, buff.size)
    }
    func encryptData(buff: Array<Byte>, start: Int64, len: Int64): Int64 {
        (buff, start)
        return len
    }
}

class NoCipherOutputStream <: CipherOutputStream<NoEncrypter> {
    public init(zipEntryOutputStream: ZipEntryOutputStream, zipParameters: ZipParameters, password: ?Array<Rune>) {
        super(zipEntryOutputStream, zipParameters, password, true)
        this.encrypter = initializeEncrypter(zipEntryOutputStream, zipParameters, password, true)
    }


    protected func initializeEncrypter(
        outputStream: OutputStream,
        zipParameters: ZipParameters,
        password: ?Array<Rune>,
        useUtf8ForPassword: Bool
    ): NoEncrypter {
        NoEncrypter.INSTANCE
    }
}
