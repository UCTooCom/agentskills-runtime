/**
 * @file
 * This file is about yaml token type.
 */

package yaml4cj.yaml

enum TokenTypeT {
    | TokenTypeT_NO_TOKEN
    | TokenTypeT_STREAM_START_TOKEN
    | TokenTypeT_STREAM_END_TOKEN
    | TokenTypeT_VERSION_DIRECTIVE_TOKEN
    | TokenTypeT_TAG_DIRECTIVE_TOKEN
    | TokenTypeT_DOCUMENT_START_TOKEN
    | TokenTypeT_DOCUMENT_END_TOKEN
    | TokenTypeT_BLOCK_SEQUENCE_START_TOKEN
    | TokenTypeT_BLOCK_MAPPING_START_TOKEN
    | TokenTypeT_BLOCK_END_TOKEN
    | TokenTypeT_FLOW_SEQUENCE_START_TOKEN
    | TokenTypeT_FLOW_SEQUENCE_END_TOKEN
    | TokenTypeT_FLOW_MAPPING_START_TOKEN
    | TokenTypeT_FLOW_MAPPING_END_TOKEN
    | TokenTypeT_BLOCK_ENTRY_TOKEN
    | TokenTypeT_FLOW_ENTRY_TOKEN
    | TokenTypeT_KEY_TOKEN
    | TokenTypeT_VALUE_TOKEN
    | TokenTypeT_ALIAS_TOKEN
    | TokenTypeT_ANCHOR_TOKEN
    | TokenTypeT_TAG_TOKEN
    | TokenTypeT_SCALAR_TOKEN

    /**
     * The Function is getValues
     *
     * @return Type of Array<TokenTypeT>
     * @since 0.30.4
     */
    /*public static func getValues(): Array<TokenTypeT> {
        [
            TokenTypeT_NO_TOKEN,
            TokenTypeT_STREAM_START_TOKEN,
            TokenTypeT_STREAM_END_TOKEN,
            TokenTypeT_VERSION_DIRECTIVE_TOKEN,
            TokenTypeT_TAG_DIRECTIVE_TOKEN,
            TokenTypeT_DOCUMENT_START_TOKEN,
            TokenTypeT_DOCUMENT_END_TOKEN,
            TokenTypeT_BLOCK_SEQUENCE_START_TOKEN,
            TokenTypeT_BLOCK_MAPPING_START_TOKEN,
            TokenTypeT_BLOCK_END_TOKEN,
            TokenTypeT_FLOW_SEQUENCE_START_TOKEN,
            TokenTypeT_FLOW_SEQUENCE_END_TOKEN,
            TokenTypeT_FLOW_MAPPING_START_TOKEN,
            TokenTypeT_FLOW_MAPPING_END_TOKEN,
            TokenTypeT_BLOCK_ENTRY_TOKEN,
            TokenTypeT_FLOW_ENTRY_TOKEN,
            TokenTypeT_KEY_TOKEN,
            TokenTypeT_VALUE_TOKEN,
            TokenTypeT_ALIAS_TOKEN,
            TokenTypeT_ANCHOR_TOKEN,
            TokenTypeT_TAG_TOKEN,
            TokenTypeT_SCALAR_TOKEN
        ]
    }*/

    /**
     * The Function is getCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    func getCode(): Int64 {
        match (this) {
            case TokenTypeT_NO_TOKEN => 0
            case TokenTypeT_STREAM_START_TOKEN => 1
            case TokenTypeT_STREAM_END_TOKEN => 2
            case TokenTypeT_VERSION_DIRECTIVE_TOKEN => 3
            case TokenTypeT_TAG_DIRECTIVE_TOKEN => 4
            case TokenTypeT_DOCUMENT_START_TOKEN => 5
            case TokenTypeT_DOCUMENT_END_TOKEN => 6
            case TokenTypeT_BLOCK_SEQUENCE_START_TOKEN => 7
            case TokenTypeT_BLOCK_MAPPING_START_TOKEN => 8
            case TokenTypeT_BLOCK_END_TOKEN => 9
            case TokenTypeT_FLOW_SEQUENCE_START_TOKEN => 10
            case TokenTypeT_FLOW_SEQUENCE_END_TOKEN => 11
            case TokenTypeT_FLOW_MAPPING_START_TOKEN => 12
            case TokenTypeT_FLOW_MAPPING_END_TOKEN => 13
            case TokenTypeT_BLOCK_ENTRY_TOKEN => 14
            case TokenTypeT_FLOW_ENTRY_TOKEN => 15
            case TokenTypeT_KEY_TOKEN => 16
            case TokenTypeT_VALUE_TOKEN => 17
            case TokenTypeT_ALIAS_TOKEN => 18
            case TokenTypeT_ANCHOR_TOKEN => 19
            case TokenTypeT_TAG_TOKEN => 20
            case TokenTypeT_SCALAR_TOKEN => 21
        }
    }

    /**
     * The Function is hashCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    /*public func hashCode(): Int64 {
        genHashCode([getCode()], name: "TokenTypeT")
    }*/

    /**
     * The Function is ==
     *
     * @param b of TokenTypeT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func ==(b: TokenTypeT): Bool {
        eq(getCode(), b.getCode())
    }

    /**
     * The Function is !=
     *
     * @param b of TokenTypeT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func !=(b: TokenTypeT): Bool {
        ne(getCode(), b.getCode())
    }

    /**
     * The Function is toString
     *
     * @return Type of String
     * @since 0.30.4
     */
    /*public func toString(): String {
        match (this) {
            case TokenTypeT_NO_TOKEN => "TokenTypeT_NO_TOKEN"
            case TokenTypeT_STREAM_START_TOKEN => "TokenTypeT_STREAM_START_TOKEN"
            case TokenTypeT_STREAM_END_TOKEN => "TokenTypeT_STREAM_END_TOKEN"
            case TokenTypeT_VERSION_DIRECTIVE_TOKEN => "TokenTypeT_VERSION_DIRECTIVE_TOKEN"
            case TokenTypeT_TAG_DIRECTIVE_TOKEN => "TokenTypeT_TAG_DIRECTIVE_TOKEN"
            case TokenTypeT_DOCUMENT_START_TOKEN => "TokenTypeT_DOCUMENT_START_TOKEN"
            case TokenTypeT_DOCUMENT_END_TOKEN => "TokenTypeT_DOCUMENT_END_TOKEN"
            case TokenTypeT_BLOCK_SEQUENCE_START_TOKEN => "TokenTypeT_BLOCK_SEQUENCE_START_TOKEN"
            case TokenTypeT_BLOCK_MAPPING_START_TOKEN => "TokenTypeT_BLOCK_MAPPING_START_TOKEN"
            case TokenTypeT_BLOCK_END_TOKEN => "TokenTypeT_BLOCK_END_TOKEN"
            case TokenTypeT_FLOW_SEQUENCE_START_TOKEN => "TokenTypeT_FLOW_SEQUENCE_START_TOKEN"
            case TokenTypeT_FLOW_SEQUENCE_END_TOKEN => "TokenTypeT_FLOW_SEQUENCE_END_TOKEN"
            case TokenTypeT_FLOW_MAPPING_START_TOKEN => "TokenTypeT_FLOW_MAPPING_START_TOKEN"
            case TokenTypeT_FLOW_MAPPING_END_TOKEN => "TokenTypeT_FLOW_MAPPING_END_TOKEN"
            case TokenTypeT_BLOCK_ENTRY_TOKEN => "TokenTypeT_BLOCK_ENTRY_TOKEN"
            case TokenTypeT_FLOW_ENTRY_TOKEN => "TokenTypeT_FLOW_ENTRY_TOKEN"
            case TokenTypeT_KEY_TOKEN => "TokenTypeT_KEY_TOKEN"
            case TokenTypeT_VALUE_TOKEN => "TokenTypeT_VALUE_TOKEN"
            case TokenTypeT_ALIAS_TOKEN => "TokenTypeT_ALIAS_TOKEN"
            case TokenTypeT_ANCHOR_TOKEN => "TokenTypeT_ANCHOR_TOKEN"
            case TokenTypeT_TAG_TOKEN => "TokenTypeT_TAG_TOKEN"
            case TokenTypeT_SCALAR_TOKEN => "TokenTypeT_SCALAR_TOKEN"
        }
    }*/
}
