/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * Single byte character set
 */

package charset4cj.charset.singlebyte

/**
 * Single byte character set
 * @author freeonsky
 * @since 0.28.4
 */
public class SingleByteCharset <: Charset{
    private static let nameMap = HashMap<String, Array<String>>([
        ("IBM866", [
            "866",
            "cp866",
            "csibm866",
            "ibm866"
        ]),
        ("ISO-8859-2", [
            "csisolatin2",
            "iso-8859-2",
            "iso-ir-101",
            "iso8859-2",
            "iso88592",
            "iso_8859-2",
            "iso_8859-2,1987",
            "l2",
            "latin2"
        ]),
        ("ISO-8859-3", [
            "csisolatin3",
            "iso-8859-3",
            "iso-ir-109",
            "iso8859-3",
            "iso88593",
            "iso_8859-3",
            "iso_8859-3,1988",
            "l3",
            "latin3"
        ]),
        ("ISO-8859-4", [
            "csisolatin4",
            "iso-8859-4",
            "iso-ir-110",
            "iso8859-4",
            "iso88594",
            "iso_8859-4",
            "iso_8859-4,1988",
            "l4",
            "latin4"
        ]),
        ("ISO-8859-5", [
            "csisolatincyrillic",
            "cyrillic",
            "iso-8859-5",
            "iso-ir-144",
            "iso8859-5",
            "iso88595",
            "iso_8859-5",
            "iso_8859-5,1988"
        ]),
        ("ISO-8859-6", [
            "arabic",
            "asmo-708",
            "csiso88596e",
            "csiso88596i",
            "csisolatinarabic",
            "ecma-114",
            "iso-8859-6",
            "iso-8859-6-e",
            "iso-8859-6-i",
            "iso-ir-127",
            "iso8859-6",
            "iso88596",
            "iso_8859-6",
            "iso_8859-6,1987"
        ]),
        ("ISO-8859-7", [
            "csisolatingreek",
            "ecma-118",
            "elot_928",
            "greek",
            "greek8",
            "iso-8859-7",
            "iso-ir-126",
            "iso8859-7",
            "iso88597",
            "iso_8859-7",
            "iso_8859-7,1987",
            "sun_eu_greek"
        ]),
        ("ISO-8859-8", [
            "csiso88598e",
            "csisolatinhebrew",
            "hebrew",
            "iso-8859-8",
            "iso-8859-8-e",
            "iso-ir-138",
            "iso8859-8",
            "iso88598",
            "iso_8859-8",
            "iso_8859-8,1988",
            "visual"
        ]),
        // ("ISO-8859-8-I", [
        //     "csiso88598i",
        //     "iso-8859-8-i",
        //     "logical"
        // ]),
        ("ISO-8859-10", [
            "csisolatin6",
            "iso-8859-10",
            "iso-ir-157",
            "iso8859-10",
            "iso885910",
            "l6",
            "latin6"
        ]),
        ("ISO-8859-13", [
            "iso-8859-13",
            "iso8859-13",
            "iso885913"
        ]),
        ("ISO-8859-14", [
            "iso-8859-14",
            "iso8859-14",
            "iso885914"
        ]),
        ("ISO-8859-15", [
            "csisolatin9",
            "iso-8859-15",
            "iso8859-15",
            "iso885915",
            "iso_8859-15",
            "l9"
        ]),
        ("ISO-8859-16", [
            "iso-8859-16"
        ]),
        ("KOI8-R", [
            "cskoi8r",
            "koi",
            "koi8",
            "koi8-r",
            "koi8_r"
        ]),
        ("KOI8-U", [
            "koi8-ru",
            "koi8-u"
        ]),
        ("macintosh", [
            "csmacintosh",
            "mac",
            "macintosh",
            "x-mac-roman"
        ]),
        ("windows-874", [
            "dos-874",
            "iso-8859-11",
            "iso8859-11",
            "iso885911",
            "tis-620",
            "windows-874"
        ]),
        ("windows-1250", [
            "cp1250",
            "windows-1250",
            "x-cp1250"
        ]),
        ("windows-1251", [
            "cp1251",
            "windows-1251",
            "x-cp1251"
        ]),
        ("windows-1252", [
            "ansi_x3.4-1968",
            "ascii",
            "cp1252",
            "cp819",
            "csisolatin1",
            "ibm819",
            "iso-8859-1",
            "iso-ir-100",
            "iso8859-1",
            "iso88591",
            "iso_8859-1",
            "iso_8859-1,1987",
            "l1",
            "latin1",
            "us-ascii",
            "windows-1252",
            "x-cp1252"
        ]),
        ("windows-1253", [
            "cp1253",
            "windows-1253",
            "x-cp1253"
        ]),
        ("windows-1254", [
            "cp1254",
            "csisolatin5",
            "iso-8859-9",
            "iso-ir-148",
            "iso8859-9",
            "iso88599",
            "iso_8859-9",
            "iso_8859-9,1989",
            "l5",
            "latin5",
            "windows-1254",
            "x-cp1254"
        ]),
        ("windows-1255", [
            "cp1255",
            "windows-1255",
            "x-cp1255"
        ]),
        ("windows-1256", [
            "cp1256",
            "windows-1256",
            "x-cp1256"
        ]),
        ("windows-1257", [
            "cp1257",
            "windows-1257",
            "x-cp1257"
        ]),
        ("windows-1258", [
            "cp1258",
            "windows-1258",
            "x-cp1258"
        ]),
        ("x-mac-cyrillic", [
            "x-mac-cyrillic",
            "x-mac-ukrainian"
        ])
    ])
    private static let decodeDic = HashMap<String, Array<UInt32>>([
        ("IBM866", ibm866DecodeMapping),
        ("ISO-8859-2", iso_8859_2DecodeMapping),
        ("ISO-8859-3", iso_8859_3DecodeMapping),
        ("ISO-8859-4", iso_8859_4DecodeMapping),
        ("ISO-8859-5", iso_8859_5DecodeMapping),
        ("ISO-8859-6", iso_8859_6DecodeMapping),
        ("ISO-8859-7", iso_8859_7DecodeMapping),
        ("ISO-8859-8", iso_8859_8DecodeMapping),
        // "ISO-8859-8-I", iso_8859_8_iDecodeMapping),
        ("ISO-8859-10", iso_8859_10DecodeMapping),
        ("ISO-8859-13", iso_8859_13DecodeMapping),
        ("ISO-8859-14", iso_8859_14DecodeMapping),
        ("ISO-8859-15", iso_8859_15DecodeMapping),
        ("ISO-8859-16", iso_8859_16DecodeMapping),
        ("KOI8-R", koi8_rDecodeMapping),
        ("KOI8-U", koi8_uDecodeMapping),
        ("macintosh", macintoshDecodeMapping),
        ("windows-874", windows_874DecodeMapping),
        ("windows-1250", windows_1250DecodeMapping),
        ("windows-1251", windows_1251DecodeMapping),
        ("windows-1252", windows_1252DecodeMapping),
        ("windows-1253", windows_1253DecodeMapping),
        ("windows-1254", windows_1254DecodeMapping),
        ("windows-1255", windows_1255DecodeMapping),
        ("windows-1256", windows_1256DecodeMapping),
        ("windows-1257", windows_1257DecodeMapping),
        ("windows-1258", windows_1258DecodeMapping),
        ("x-mac-cyrillic", x_mac_cyrillicDecodeMapping)
    ])
    private static let encodeDic = HashMap<String, Map<UInt32, UInt32>>([
        ("IBM866", ibm866EncodeMapping),
        ("ISO-8859-2", iso_8859_2EncodeMapping),
        ("ISO-8859-3", iso_8859_3EncodeMapping),
        ("ISO-8859-4", iso_8859_4EncodeMapping),
        ("ISO-8859-5", iso_8859_5EncodeMapping),
        ("ISO-8859-6", iso_8859_6EncodeMapping),
        ("ISO-8859-7", iso_8859_7EncodeMapping),
        ("ISO-8859-8", iso_8859_8EncodeMapping),
        // "ISO-8859-8-I", iso_8859_8_iEncodeMapping),
        ("ISO-8859-10", iso_8859_10EncodeMapping),
        ("ISO-8859-13", iso_8859_13EncodeMapping),
        ("ISO-8859-14", iso_8859_14EncodeMapping),
        ("ISO-8859-15", iso_8859_15EncodeMapping),
        ("ISO-8859-16", iso_8859_16EncodeMapping),
        ("KOI8-R", koi8_rEncodeMapping),
        ("KOI8-U", koi8_uEncodeMapping),
        ("macintosh", macintoshEncodeMapping),
        ("windows-874", windows_874EncodeMapping),
        ("windows-1250", windows_1250EncodeMapping),
        ("windows-1251", windows_1251EncodeMapping),
        ("windows-1252", windows_1252EncodeMapping),
        ("windows-1253", windows_1253EncodeMapping),
        ("windows-1254", windows_1254EncodeMapping),
        ("windows-1255", windows_1255EncodeMapping),
        ("windows-1256", windows_1256EncodeMapping),
        ("windows-1257", windows_1257EncodeMapping),
        ("windows-1258", windows_1258EncodeMapping),
        ("x-mac-cyrillic", x_mac_cyrillicEncodeMapping)
    ])
    // IBM866
    public static let IBM866: Charset = SingleByteCharset("IBM866")
    // ISO-8859-2
    public static let ISO_8859_2: Charset = SingleByteCharset("ISO-8859-2")
    // ISO-8859-3
    public static let ISO_8859_3: Charset = SingleByteCharset("ISO-8859-3")
    // ISO-8859-4
    public static let ISO_8859_4: Charset = SingleByteCharset("ISO-8859-4")
    // ISO-8859-5
    public static let ISO_8859_5: Charset = SingleByteCharset("ISO-8859-5")
    // ISO-8859-6
    public static let ISO_8859_6: Charset = SingleByteCharset("ISO-8859-6")
    // ISO-8859-7
    public static let ISO_8859_7: Charset = SingleByteCharset("ISO-8859-7")
    // ISO-8859-8
    public static let ISO_8859_8: Charset = SingleByteCharset("ISO-8859-8")
    // ISO-8859-10
    public static let ISO_8859_10: Charset = SingleByteCharset("ISO-8859-10")
    // ISO-8859-13
    public static let ISO_8859_13: Charset = SingleByteCharset("ISO-8859-13")
    // ISO-8859-14
    public static let ISO_8859_14: Charset = SingleByteCharset("ISO-8859-14")
    // ISO-8859-15
    public static let ISO_8859_15: Charset = SingleByteCharset("ISO-8859-15")
    // ISO-8859-16
    public static let ISO_8859_16: Charset = SingleByteCharset("ISO-8859-16")
    // KOI8-R
    public static let KOI8_R: Charset = SingleByteCharset("KOI8-R")
    // KOI8-U
    public static let KOI8_U: Charset = SingleByteCharset("KOI8-U")
    // macintosh
    public static let MACINTOSH: Charset = SingleByteCharset("macintosh")
    // windows-874
    public static let WINDOWS_874: Charset = SingleByteCharset("windows-874")
    // windows-1250
    public static let WINDOWS_1250: Charset = SingleByteCharset("windows-1250")
    // windows-1251
    public static let WINDOWS_1251: Charset = SingleByteCharset("windows-1251")
    // windows-1252
    public static let WINDOWS_1252: Charset = SingleByteCharset("windows-1252")
    // windows-1253
    public static let WINDOWS_1253: Charset = SingleByteCharset("windows-1253")
    // windows-1254
    public static let WINDOWS_1254: Charset = SingleByteCharset("windows-1254")
    // windows-1255
    public static let WINDOWS_1255: Charset = SingleByteCharset("windows-1255")
    // windows-1256
    public static let WINDOWS_1256: Charset = SingleByteCharset("windows-1256")
    // windows-1257
    public static let WINDOWS_1257: Charset = SingleByteCharset("windows-1257")
    // windows-1258
    public static let WINDOWS_1258: Charset = SingleByteCharset("windows-1258")
    // x-mac-cyrillic
    public static let X_MAC_CYRILLIC: Charset = SingleByteCharset("x-mac-cyrillic")

    private init(name:String){
        super(name, nameMap[name])
    }
    public func newEncoder():Encoder{
        SingleByteEncoder(encodeDic[name], decodeDic[name])
    }
    public func newDecoder():Decoder{
        SingleByteDecoder(decodeDic[name])
    }
}
