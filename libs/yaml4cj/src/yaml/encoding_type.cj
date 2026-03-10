/**
 * @file
 * This file is about yaml encoding.
 */

package yaml4cj.yaml

enum EncodingT <: Hashable {
    | EncodingT_ANY_ENCODING
    | EncodingT_UTF8_ENCODING
    | EncodingT_UTF16LE_ENCODING
    | EncodingT_UTF16BE_ENCODING

    /**
     * The Function is hashCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    public func hashCode(): Int64 {
        match (this) {
            case EncodingT_ANY_ENCODING => 0
            case EncodingT_UTF8_ENCODING => 1
            case EncodingT_UTF16LE_ENCODING => 2
            case EncodingT_UTF16BE_ENCODING => 3
        }
    }

    /**
     * The Function is ==
     *
     * @param b of EncodingT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func ==(b: EncodingT): Bool {
        eq(this, b)
    }

    /**
     * The Function is !=
     *
     * @param b of EncodingT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    /*public operator func !=(b: EncodingT): Bool {
        ne(this, b)
    }

    /**
     * The Function is toString
     *
     * @return Type of String
     * @since 0.30.4
     */
    public func toString(): String {
        match (this) {
            case EncodingT_ANY_ENCODING => "EncodingT_ANY_ENCODING"
            case EncodingT_UTF8_ENCODING => "EncodingT_UTF8_ENCODING"
            case EncodingT_UTF16LE_ENCODING => "EncodingT_UTF16LE_ENCODING"
            case EncodingT_UTF16BE_ENCODING => "EncodingT_UTF16BE_ENCODING"
        }
    }*/
}
