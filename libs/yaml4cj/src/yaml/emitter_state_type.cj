/**
 * @file
 * This file is about yaml emitter state.
 */

package yaml4cj.yaml

enum EmitterStateT <: Hashable & ToString {
    | EmitterStateT_EMIT_STREAM_START_STATE
    | EmitterStateT_EMIT_FIRST_DOCUMENT_START_STATE
    | EmitterStateT_EMIT_DOCUMENT_START_STATE
    | EmitterStateT_EMIT_DOCUMENT_CONTENT_STATE
    | EmitterStateT_EMIT_DOCUMENT_END_STATE
    | EmitterStateT_EMIT_FLOW_SEQUENCE_FIRST_ITEM_STATE
    | EmitterStateT_EMIT_FLOW_SEQUENCE_ITEM_STATE
    | EmitterStateT_EMIT_FLOW_MAPPING_FIRST_KEY_STATE
    | EmitterStateT_EMIT_FLOW_MAPPING_KEY_STATE
    | EmitterStateT_EMIT_FLOW_MAPPING_SIMPLE_VALUE_STATE
    | EmitterStateT_EMIT_FLOW_MAPPING_VALUE_STATE
    | EmitterStateT_EMIT_BLOCK_SEQUENCE_FIRST_ITEM_STATE
    | EmitterStateT_EMIT_BLOCK_SEQUENCE_ITEM_STATE
    | EmitterStateT_EMIT_BLOCK_MAPPING_FIRST_KEY_STATE
    | EmitterStateT_EMIT_BLOCK_MAPPING_KEY_STATE
    | EmitterStateT_EMIT_BLOCK_MAPPING_SIMPLE_VALUE_STATE
    | EmitterStateT_EMIT_BLOCK_MAPPING_VALUE_STATE
    | EmitterStateT_EMIT_END_STATE

    /**
     * The Function is hashCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    public func hashCode(): Int64 {
        match (this) {
            case EmitterStateT_EMIT_STREAM_START_STATE => 0
            case EmitterStateT_EMIT_FIRST_DOCUMENT_START_STATE => 1
            case EmitterStateT_EMIT_DOCUMENT_START_STATE => 2
            case EmitterStateT_EMIT_DOCUMENT_CONTENT_STATE => 3
            case EmitterStateT_EMIT_DOCUMENT_END_STATE => 4
            case EmitterStateT_EMIT_FLOW_SEQUENCE_FIRST_ITEM_STATE => 5
            case EmitterStateT_EMIT_FLOW_SEQUENCE_ITEM_STATE => 6
            case EmitterStateT_EMIT_FLOW_MAPPING_FIRST_KEY_STATE => 7
            case EmitterStateT_EMIT_FLOW_MAPPING_KEY_STATE => 8
            case EmitterStateT_EMIT_FLOW_MAPPING_SIMPLE_VALUE_STATE => 9
            case EmitterStateT_EMIT_FLOW_MAPPING_VALUE_STATE => 10
            case EmitterStateT_EMIT_BLOCK_SEQUENCE_FIRST_ITEM_STATE => 11
            case EmitterStateT_EMIT_BLOCK_SEQUENCE_ITEM_STATE => 12
            case EmitterStateT_EMIT_BLOCK_MAPPING_FIRST_KEY_STATE => 13
            case EmitterStateT_EMIT_BLOCK_MAPPING_KEY_STATE => 14
            case EmitterStateT_EMIT_BLOCK_MAPPING_SIMPLE_VALUE_STATE => 15
            case EmitterStateT_EMIT_BLOCK_MAPPING_VALUE_STATE => 16
            case EmitterStateT_EMIT_END_STATE => 17
        }
    }

    /**
     * The Function is ==
     *
     * @param b of EmitterStateT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    /*public operator func ==(b: EmitterStateT): Bool {
        eq(this, b)
    }

    /**
     * The Function is !=
     *
     * @param b of EmitterStateT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func !=(b: EmitterStateT): Bool {
        ne(this, b)
    }*/

    /**
     * The Function is toString
     *
     * @return Type of String
     * @since 0.30.4
     */
    public func toString(): String {
        match (this) {
            case EmitterStateT_EMIT_STREAM_START_STATE => "EmitterStateT_EMIT_STREAM_START_STATE"
            case EmitterStateT_EMIT_FIRST_DOCUMENT_START_STATE => "EmitterStateT_EMIT_FIRST_DOCUMENT_START_STATE"
            case EmitterStateT_EMIT_DOCUMENT_START_STATE => "EmitterStateT_EMIT_DOCUMENT_START_STATE"
            case EmitterStateT_EMIT_DOCUMENT_CONTENT_STATE => "EmitterStateT_EMIT_DOCUMENT_CONTENT_STATE"
            case EmitterStateT_EMIT_DOCUMENT_END_STATE => "EmitterStateT_EMIT_DOCUMENT_END_STATE"
            case EmitterStateT_EMIT_FLOW_SEQUENCE_FIRST_ITEM_STATE => "EmitterStateT_EMIT_FLOW_SEQUENCE_FIRST_ITEM_STATE"
            case EmitterStateT_EMIT_FLOW_SEQUENCE_ITEM_STATE => "EmitterStateT_EMIT_FLOW_SEQUENCE_ITEM_STATE"
            case EmitterStateT_EMIT_FLOW_MAPPING_FIRST_KEY_STATE => "EmitterStateT_EMIT_FLOW_MAPPING_FIRST_KEY_STATE"
            case EmitterStateT_EMIT_FLOW_MAPPING_KEY_STATE => "EmitterStateT_EMIT_FLOW_MAPPING_KEY_STATE"
            case EmitterStateT_EMIT_FLOW_MAPPING_SIMPLE_VALUE_STATE => "EmitterStateT_EMIT_FLOW_MAPPING_SIMPLE_VALUE_STATE"
            case EmitterStateT_EMIT_FLOW_MAPPING_VALUE_STATE => "EmitterStateT_EMIT_FLOW_MAPPING_VALUE_STATE"
            case EmitterStateT_EMIT_BLOCK_SEQUENCE_FIRST_ITEM_STATE => "EmitterStateT_EMIT_BLOCK_SEQUENCE_FIRST_ITEM_STATE"
            case EmitterStateT_EMIT_BLOCK_SEQUENCE_ITEM_STATE => "EmitterStateT_EMIT_BLOCK_SEQUENCE_ITEM_STATE"
            case EmitterStateT_EMIT_BLOCK_MAPPING_FIRST_KEY_STATE => "EmitterStateT_EMIT_BLOCK_MAPPING_FIRST_KEY_STATE"
            case EmitterStateT_EMIT_BLOCK_MAPPING_KEY_STATE => "EmitterStateT_EMIT_BLOCK_MAPPING_KEY_STATE"
            case EmitterStateT_EMIT_BLOCK_MAPPING_SIMPLE_VALUE_STATE => "EmitterStateT_EMIT_BLOCK_MAPPING_SIMPLE_VALUE_STATE"
            case EmitterStateT_EMIT_BLOCK_MAPPING_VALUE_STATE => "EmitterStateT_EMIT_BLOCK_MAPPING_VALUE_STATE"
            case EmitterStateT_EMIT_END_STATE => "EmitterStateT_EMIT_END_STATE"
        }
    }
}
