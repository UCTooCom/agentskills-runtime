/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file is about GB18030Charset
 */
package charset4cj.charset.simplechinese

/**
 * The class is GBKCharset inherited from Charset
 * @author freeonsky
 * @since 0.28.4
 */
public class GBKCharset <: Charset{
    public static let instance = GBKCharset()
    /**
     * The Function is init constructor
     *
     * @since 0.28.4
     */
    private init(){
        super("gbk", "chinese", "csgb2312", "csiso58gb231280", "gb2312", "gb_2312", "gb_2312-80", "gbk", "iso-ir-58", "x-gbk")
        // Actual number of characters gbk > gb2312 , for ease of handling,  use gb2312 as gbk
        // this.labels = ["chinese", "csgb2312", "csiso58gb231280", "gb2312", "gb_2312", "gb_2312-80", "gbk", "iso-ir-58", "x-gbk"]
        // this.name = "gbk"
    }

    /**
     * The Function is newEncoder
     *
     * @return Type of Encoder
     * @since 0.28.4
     */
    public func newEncoder():Encoder{
        GB18030Encoder(true)
    }

    /**
     * The Function is newDecoder
     *
     * @return Type of Decoder
     * @since 0.28.4
     */
    public func newDecoder():Decoder{
        GB18030Decoder()
    }
}

/**
 * The class is GB18030Charset inherited from Charset
 * @author freeonsky
 * @since 0.28.4
 */
public class GB18030Charset <: Charset{
    public static let instance = GB18030Charset()
    /**
     * The Function is init constructor
     *
     * @since 0.28.4
     */
    private init(){
        super("gb18030", "gb18030")
        // this.labels = ["gb18030"]
        // this.name = "gb18030"
    }

    /**
     * The Function is newEncoder
     *
     * @return Type of Encoder
     * @since 0.28.4
     */
    public func newEncoder():Encoder{
        GB18030Encoder(false)
    }

    /**
     * The Function is newDecoder
     *
     * @return Type of Decoder
     * @since 0.28.4
     */
    public func newDecoder():Decoder{
        GB18030Decoder()
    }
}
