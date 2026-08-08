/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

package charset4cj.charset.japanese

/**
 * ISO-2022-JP japanese encoding charset
 * @author freeonsky
 * @since 0.28.4
 */
public class ISO2022JPCharset <: Charset{
    public static let instance = ISO2022JPCharset()
    /**
     * The Function is init constructor
     *
     * @since 0.28.4
     */
    private init(){
        super("ISO-2022-JP", "ISO-2022-JP",  "csiso2022jp")
    }

    /**
     * The Function is newEncoder
     *
     * @return Type of Encoder
     * @since 0.28.4
     */
    public func newEncoder():Encoder{
        ISO2022JPEncoder()
    }

    /**
     * The Function is newDecoder
     *
     * @return Type of Decoder
     * @since 0.28.4
     */
    public func newDecoder():Decoder{
        ISO2022JPDecoder()
    }
}

/**
 * EUC-JP japanese encoding charset
 * @author freeonsky
 * @since 0.28.4
 */
public class EUCJPCharset <: Charset{
    public static let instance = EUCJPCharset()

    /**
     * The Function is init constructor
     *
     * @since 0.28.4
     */
    private init(){
        super("EUC-JP", "cseucpkdfmtjapanese",  "euc-jp",  "x-euc-jp")
    }

    /**
     * The Function is newEncoder
     *
     * @return Type of Encoder
     * @since 0.28.4
     */
    public func newEncoder():Encoder{
        EUCJPEncoder()
    }

    /**
     * The Function is newDecoder
     *
     * @return Type of Decoder
     * @since 0.28.4
     */
    public func newDecoder():Decoder{
        EUCJPDecoder()
    }
}

/**
 * ShiftJIS japanese encoding charset
 * @author freeonsky
 * @since 0.28.4
 */
public class ShiftJISCharset <: Charset{
    public static let instance = ShiftJISCharset()
    /**
     * The Function is init constructor
     *
     * @since 0.28.4
     */
    private init(){
        super("Shift_JIS", "csshiftjis","ms932","ms_kanji","shift-jis","shift_jis","sjis","windows-31j","x-sjis")
    }

    /**
     * The Function is newEncoder
     *
     * @return Type of Encoder
     * @since 0.28.4
     */
    public func newEncoder():Encoder{
        ShiftJISEncoder()
    }

    /**
     * The Function is newDecoder
     *
     * @return Type of Decoder
     * @since 0.28.4
     */
    public func newDecoder():Decoder{
        ShiftJISDecoder()
    }
}
