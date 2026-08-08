/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * Constant definitions for all the supported Charsets.
 */

package charset4cj.charset

/**
 * Constant definitions for all the supported Charsets.
 * @author freeonsky
 * @since 0.28.4
 */
public class Charsets {

    // UTF-8
    public static let UTF8: Charset = UTF8Charset.instance
    // utf-16 be
    public static let UTF16BE: Charset = UTF16Charset.beInstance
    // utf16 le
    public static let UTF16LE: Charset = UTF16Charset.leInstance
    // utf32 be
    public static let UTF32BE: Charset = UTF32Charset.beInstance
    // utf32 le
    public static let UTF32LE: Charset = UTF32Charset.leInstance
    // gb18030
    public static let GB18030: Charset = GB18030Charset.instance
    // gbk
    public static let GBK: Charset = GBKCharset.instance
    // EUC-KR
    public static let EUCKR: Charset = EUCKRCharset.instance
    // EUC-JP
    public static let EUCJP: Charset = EUCJPCharset.instance
    // ShiftJIS
    public static let SHIFT_JIS: Charset = ShiftJISCharset.instance
    // ISO-2022-JP
    public static let ISO_2022_JP: Charset = ISO2022JPCharset.instance
    // Big5
    public static let BIG5: Charset = BIG5Charset.instance
    // Big5-hkscs
    public static let BIG5_HKSCS: Charset = BIG5HKSCSCharset.instance
    // IBM866
    public static let IBM866: Charset = SingleByteCharset.IBM866
    // ISO-8859-2
    public static let ISO_8859_2: Charset = SingleByteCharset.ISO_8859_2
    // ISO-8859-3
    public static let ISO_8859_3: Charset = SingleByteCharset.ISO_8859_3
    // ISO-8859-4
    public static let ISO_8859_4: Charset = SingleByteCharset.ISO_8859_4
    // ISO-8859-5
    public static let ISO_8859_5: Charset = SingleByteCharset.ISO_8859_5
    // ISO-8859-6
    public static let ISO_8859_6: Charset = SingleByteCharset.ISO_8859_6
    // ISO-8859-7
    public static let ISO_8859_7: Charset = SingleByteCharset.ISO_8859_7
    // ISO-8859-8
    public static let ISO_8859_8: Charset = SingleByteCharset.ISO_8859_8
    // ISO-8859-10
    public static let ISO_8859_10: Charset = SingleByteCharset.ISO_8859_10
    // ISO-8859-13
    public static let ISO_8859_13: Charset = SingleByteCharset.ISO_8859_13
    // ISO-8859-14
    public static let ISO_8859_14: Charset = SingleByteCharset.ISO_8859_14
    // ISO-8859-15
    public static let ISO_8859_15: Charset = SingleByteCharset.ISO_8859_15
    // ISO-8859-16
    public static let ISO_8859_16: Charset = SingleByteCharset.ISO_8859_16
    // KOI8-R
    public static let KOI8_R: Charset = SingleByteCharset.KOI8_R
    // KOI8-U
    public static let KOI8_U: Charset = SingleByteCharset.KOI8_U
    // macintosh
    public static let MACINTOSH: Charset = SingleByteCharset.MACINTOSH
    // windows-874
    public static let WINDOWS_874: Charset = SingleByteCharset.WINDOWS_874
    // windows-1250
    public static let WINDOWS_1250: Charset = SingleByteCharset.WINDOWS_1250
    // windows-1251
    public static let WINDOWS_1251: Charset = SingleByteCharset.WINDOWS_1251
    // windows-1252
    public static let WINDOWS_1252: Charset = SingleByteCharset.WINDOWS_1252
    // windows-1253
    public static let WINDOWS_1253: Charset = SingleByteCharset.WINDOWS_1253
    // windows-1254
    public static let WINDOWS_1254: Charset = SingleByteCharset.WINDOWS_1254
    // windows-1255
    public static let WINDOWS_1255: Charset = SingleByteCharset.WINDOWS_1255
    // windows-1256
    public static let WINDOWS_1256: Charset = SingleByteCharset.WINDOWS_1256
    // windows-1257
    public static let WINDOWS_1257: Charset = SingleByteCharset.WINDOWS_1257
    // windows-1258
    public static let WINDOWS_1258: Charset = SingleByteCharset.WINDOWS_1258
    // x-mac-cyrillic
    public static let X_MAC_CYRILLIC: Charset = SingleByteCharset.X_MAC_CYRILLIC

    private static let cache = HashMap<String, Charset>()
    static init() {
        let charsets = [
            UTF8,
            UTF16BE,
            UTF16LE,
            UTF32BE,
            UTF32LE,
            GB18030,
            GBK,
            EUCKR,
            BIG5,
            BIG5_HKSCS,
            EUCJP,
            SHIFT_JIS,
            ISO_2022_JP,
            IBM866,
            ISO_8859_2,
            ISO_8859_3,
            ISO_8859_4,
            ISO_8859_5,
            ISO_8859_6,
            ISO_8859_7,
            ISO_8859_8,
            ISO_8859_10,
            ISO_8859_13,
            ISO_8859_14,
            ISO_8859_15,
            ISO_8859_16,
            KOI8_R,
            KOI8_U,
            MACINTOSH,
            WINDOWS_874,
            WINDOWS_1250,
            WINDOWS_1251,
            WINDOWS_1252,
            WINDOWS_1253,
            WINDOWS_1254,
            WINDOWS_1255,
            WINDOWS_1256,
            WINDOWS_1257,
            WINDOWS_1258,
            X_MAC_CYRILLIC
        ]
        for(cs in charsets){
            for(label in cs.labels()){
                cache[label] = cs
                cache[label.toAsciiLower()] = cs
                cache[label.toAsciiUpper()] = cs
            }
        }
    }

    /**
     * Gets the character encoding type based on the character set name
     *
     * @param name of String
     *
     * @return Type of Option<Charset>
     * @since 0.28.4
     */
    public static func forName(n: String): ?Charset {
        cache.get(n)
    }
}
