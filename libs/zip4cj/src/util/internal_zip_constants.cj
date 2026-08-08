/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.util

public class InternalZipConstants {
    private InternalZipConstants() {}

    public static let ENDHDR: Int64 = 22 // END header size
    public static let STD_DEC_HDR_SIZE: Int64 = 12
    public static let MAX_COMMENT_SIZE: Int64 = 65536

    public static let AES_AUTH_LENGTH: Int64 = 10
    public static let AES_BLOCK_SIZE: Int64 = 16
    public static let AES_EXTRA_DATA_RECORD_SIZE: Int32 = 11
    public static let AES_MAC_ALGORITHM = HashType.SHA1
    public static let AES_HASH_CHARSET = "ISO-8859-1"
    public static let AES_HASH_ITERATIONS: Int32 = 1000
    public static let AES_PASSWORD_VERIFIER_LENGTH: Int64 = 2

    public static let MIN_SPLIT_LENGTH: Int64 = 65536
    public static let ZIP_64_SIZE_LIMIT: Int64 = 4294967295
    public static let ZIP_64_NUMBER_OF_ENTRIES_LIMIT: Int64 = 65535

    public static let BUFF_SIZE: Int64 = 1024 * 4
    public static let MIN_BUFF_SIZE: Int64 = 512

    public static let UPDATE_LFH_CRC: Int32 = 14

    public static let UPDATE_LFH_COMP_SIZE: Int32 = 18

    public static let UPDATE_LFH_UNCOMP_SIZE: Int32 = 22

    // public static let FILE_SEPARATOR = Path.Separator

    public static let FILE_CURRENT_PATH: Path = Path(getcwd())

    public static let ZIP_FILE_SEPARATOR = "/"

    public static let MAX_ALLOWED_ZIP_COMMENT_LENGTH: Int32 = 0xFFFF

    public static let ZIP_STANDARD_CHARSET_NAME = "Cp437"

    public static let SEVEN_ZIP_SPLIT_FILE_EXTENSION_PATTERN = ".zip.001"

    public static let USE_UTF8_FOR_PASSWORD_ENCODING_DECODING = true

    public static let NULL_BYTE_ARRAY = Array<Byte>()
}
