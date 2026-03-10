/**
 * @file
 * This file is about yaml token.
 */

package yaml4cj.yaml

/**
 * The class is TokenT inherited from ToString
 * @author changeden
 * @since 0.30.4
 */
class TokenT {
    var typ: TokenTypeT = TokenTypeT_NO_TOKEN
    var startMark: MarkT = MarkT()
    var endMark: MarkT = MarkT()

    var encoding: EncodingT = EncodingT_ANY_ENCODING

    var value: Array<UInt8> = Array<UInt8>()

    var suffix: Array<UInt8> = Array<UInt8>()

    var prefix: Array<UInt8> = Array<UInt8>()

    var style: ScalarStyleT = ScalarStyleT_ANY_SCALAR_STYLE

    var major: Int8 = 0
    var minor: Int8 = 0

    /**
     * The Function is toString
     *
     * @return Type of String
     * @since 0.30.4
     */
    /*public func toString(): String {
        """
        {
            typ=${typ}
            startMark=${startMark}
            endMark=${endMark}
            encoding=${encoding}
            value=${value}
            suffix=${suffix}
            prefix=${prefix}
            style=${style}
            major=${major}
            minor=${minor}
        }
        """
    }*/
}
