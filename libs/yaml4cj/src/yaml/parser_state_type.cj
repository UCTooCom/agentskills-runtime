/**
 * @file
 * This file is about yaml parser state.
 */

package yaml4cj.yaml

enum ParserStateT {
    | ParserStateT_PARSE_STREAM_START_STATE
    | ParserStateT_PARSE_IMPLICIT_DOCUMENT_START_STATE
    | ParserStateT_PARSE_DOCUMENT_START_STATE
    | ParserStateT_PARSE_DOCUMENT_CONTENT_STATE
    | ParserStateT_PARSE_DOCUMENT_END_STATE
    | ParserStateT_PARSE_BLOCK_NODE_STATE
    | ParserStateT_PARSE_BLOCK_NODE_OR_INDENTLESS_SEQUENCE_STATE
    | ParserStateT_PARSE_FLOW_NODE_STATE
    | ParserStateT_PARSE_BLOCK_SEQUENCE_FIRST_ENTRY_STATE
    | ParserStateT_PARSE_BLOCK_SEQUENCE_ENTRY_STATE
    | ParserStateT_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE
    | ParserStateT_PARSE_BLOCK_MAPPING_FIRST_KEY_STATE
    | ParserStateT_PARSE_BLOCK_MAPPING_KEY_STATE
    | ParserStateT_PARSE_BLOCK_MAPPING_VALUE_STATE
    | ParserStateT_PARSE_FLOW_SEQUENCE_FIRST_ENTRY_STATE
    | ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_STATE
    | ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_KEY_STATE
    | ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE
    | ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE
    | ParserStateT_PARSE_FLOW_MAPPING_FIRST_KEY_STATE
    | ParserStateT_PARSE_FLOW_MAPPING_KEY_STATE
    | ParserStateT_PARSE_FLOW_MAPPING_VALUE_STATE
    | ParserStateT_PARSE_FLOW_MAPPING_EMPTY_VALUE_STATE
    | ParserStateT_PARSE_END_STATE

    /**
     * The Function is getValues
     *
     * @return Type of Array<ParserStateT>
     * @since 0.30.4
     */
    /*public static func getValues(): Array<ParserStateT> {
        [
            ParserStateT_PARSE_STREAM_START_STATE,
            ParserStateT_PARSE_IMPLICIT_DOCUMENT_START_STATE,
            ParserStateT_PARSE_DOCUMENT_START_STATE,
            ParserStateT_PARSE_DOCUMENT_CONTENT_STATE,
            ParserStateT_PARSE_DOCUMENT_END_STATE,
            ParserStateT_PARSE_BLOCK_NODE_STATE,
            ParserStateT_PARSE_BLOCK_NODE_OR_INDENTLESS_SEQUENCE_STATE,
            ParserStateT_PARSE_FLOW_NODE_STATE,
            ParserStateT_PARSE_BLOCK_SEQUENCE_FIRST_ENTRY_STATE,
            ParserStateT_PARSE_BLOCK_SEQUENCE_ENTRY_STATE,
            ParserStateT_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE,
            ParserStateT_PARSE_BLOCK_MAPPING_FIRST_KEY_STATE,
            ParserStateT_PARSE_BLOCK_MAPPING_KEY_STATE,
            ParserStateT_PARSE_BLOCK_MAPPING_VALUE_STATE,
            ParserStateT_PARSE_FLOW_SEQUENCE_FIRST_ENTRY_STATE,
            ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_STATE,
            ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_KEY_STATE,
            ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE,
            ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE,
            ParserStateT_PARSE_FLOW_MAPPING_FIRST_KEY_STATE,
            ParserStateT_PARSE_FLOW_MAPPING_KEY_STATE,
            ParserStateT_PARSE_FLOW_MAPPING_VALUE_STATE,
            ParserStateT_PARSE_FLOW_MAPPING_EMPTY_VALUE_STATE,
            ParserStateT_PARSE_END_STATE
        ]
    }*/

    /**
     * The Function is getCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    public func getCode(): Int64 {
        match (this) {
            case ParserStateT_PARSE_STREAM_START_STATE => 0
            case ParserStateT_PARSE_IMPLICIT_DOCUMENT_START_STATE => 1
            case ParserStateT_PARSE_DOCUMENT_START_STATE => 2
            case ParserStateT_PARSE_DOCUMENT_CONTENT_STATE => 3
            case ParserStateT_PARSE_DOCUMENT_END_STATE => 4
            case ParserStateT_PARSE_BLOCK_NODE_STATE => 5
            case ParserStateT_PARSE_BLOCK_NODE_OR_INDENTLESS_SEQUENCE_STATE => 6
            case ParserStateT_PARSE_FLOW_NODE_STATE => 7
            case ParserStateT_PARSE_BLOCK_SEQUENCE_FIRST_ENTRY_STATE => 8
            case ParserStateT_PARSE_BLOCK_SEQUENCE_ENTRY_STATE => 9
            case ParserStateT_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE => 10
            case ParserStateT_PARSE_BLOCK_MAPPING_FIRST_KEY_STATE => 11
            case ParserStateT_PARSE_BLOCK_MAPPING_KEY_STATE => 12
            case ParserStateT_PARSE_BLOCK_MAPPING_VALUE_STATE => 13
            case ParserStateT_PARSE_FLOW_SEQUENCE_FIRST_ENTRY_STATE => 14
            case ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_STATE => 15
            case ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_KEY_STATE => 16
            case ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE => 17
            case ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE => 18
            case ParserStateT_PARSE_FLOW_MAPPING_FIRST_KEY_STATE => 19
            case ParserStateT_PARSE_FLOW_MAPPING_KEY_STATE => 20
            case ParserStateT_PARSE_FLOW_MAPPING_VALUE_STATE => 21
            case ParserStateT_PARSE_FLOW_MAPPING_EMPTY_VALUE_STATE => 22
            case ParserStateT_PARSE_END_STATE => 23
        }
    }

    /**
     * The Function is hashCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    /*public func hashCode(): Int64 {
        genHashCode([getCode()], name: "ParserStateT")
    }*/

    /**
     * The Function is ==
     *
     * @param b of ParserStateT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func ==(b: ParserStateT): Bool {
        eq(getCode(), b.getCode())
    }

    /**
     * The Function is !=
     *
     * @param b of ParserStateT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    /*public operator func !=(b: ParserStateT): Bool {
        ne(getCode(), b.getCode())
    }

    /**
     * The Function is toString
     *
     * @return Type of String
     * @since 0.30.4
     */
    public func toString(): String {
        match (this) {
            case ParserStateT_PARSE_STREAM_START_STATE => "ParserStateT_PARSE_STREAM_START_STATE"
            case ParserStateT_PARSE_IMPLICIT_DOCUMENT_START_STATE => "ParserStateT_PARSE_IMPLICIT_DOCUMENT_START_STATE"
            case ParserStateT_PARSE_DOCUMENT_START_STATE => "ParserStateT_PARSE_DOCUMENT_START_STATE"
            case ParserStateT_PARSE_DOCUMENT_CONTENT_STATE => "ParserStateT_PARSE_DOCUMENT_CONTENT_STATE"
            case ParserStateT_PARSE_DOCUMENT_END_STATE => "ParserStateT_PARSE_DOCUMENT_END_STATE"
            case ParserStateT_PARSE_BLOCK_NODE_STATE => "ParserStateT_PARSE_BLOCK_NODE_STATE"
            case ParserStateT_PARSE_BLOCK_NODE_OR_INDENTLESS_SEQUENCE_STATE => "ParserStateT_PARSE_BLOCK_NODE_OR_INDENTLESS_SEQUENCE_STATE"
            case ParserStateT_PARSE_FLOW_NODE_STATE => "ParserStateT_PARSE_FLOW_NODE_STATE"
            case ParserStateT_PARSE_BLOCK_SEQUENCE_FIRST_ENTRY_STATE => "ParserStateT_PARSE_BLOCK_SEQUENCE_FIRST_ENTRY_STATE"
            case ParserStateT_PARSE_BLOCK_SEQUENCE_ENTRY_STATE => "ParserStateT_PARSE_BLOCK_SEQUENCE_ENTRY_STATE"
            case ParserStateT_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE => "ParserStateT_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE"
            case ParserStateT_PARSE_BLOCK_MAPPING_FIRST_KEY_STATE => "ParserStateT_PARSE_BLOCK_MAPPING_FIRST_KEY_STATE"
            case ParserStateT_PARSE_BLOCK_MAPPING_KEY_STATE => "ParserStateT_PARSE_BLOCK_MAPPING_KEY_STATE"
            case ParserStateT_PARSE_BLOCK_MAPPING_VALUE_STATE => "ParserStateT_PARSE_BLOCK_MAPPING_VALUE_STATE"
            case ParserStateT_PARSE_FLOW_SEQUENCE_FIRST_ENTRY_STATE => "ParserStateT_PARSE_FLOW_SEQUENCE_FIRST_ENTRY_STATE"
            case ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_STATE => "ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_STATE"
            case ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_KEY_STATE => "ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_KEY_STATE"
            case ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE => "ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE"
            case ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE => "ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE"
            case ParserStateT_PARSE_FLOW_MAPPING_FIRST_KEY_STATE => "ParserStateT_PARSE_FLOW_MAPPING_FIRST_KEY_STATE"
            case ParserStateT_PARSE_FLOW_MAPPING_KEY_STATE => "ParserStateT_PARSE_FLOW_MAPPING_KEY_STATE"
            case ParserStateT_PARSE_FLOW_MAPPING_VALUE_STATE => "ParserStateT_PARSE_FLOW_MAPPING_VALUE_STATE"
            case ParserStateT_PARSE_FLOW_MAPPING_EMPTY_VALUE_STATE => "ParserStateT_PARSE_FLOW_MAPPING_EMPTY_VALUE_STATE"
            case ParserStateT_PARSE_END_STATE => "ParserStateT_PARSE_END_STATE"
        }
    }*/
}
