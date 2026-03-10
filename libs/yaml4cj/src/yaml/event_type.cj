/**
 * @file
 * This file is about yaml event type.
 */

package yaml4cj.yaml

enum EventTypeT <: Hashable & ToString {
    | EventTypeT_NO_EVENT
    | EventTypeT_STREAM_START_EVENT
    | EventTypeT_STREAM_END_EVENT
    | EventTypeT_DOCUMENT_START_EVENT
    | EventTypeT_DOCUMENT_END_EVENT
    | EventTypeT_ALIAS_EVENT
    | EventTypeT_SCALAR_EVENT
    | EventTypeT_SEQUENCE_START_EVENT
    | EventTypeT_SEQUENCE_END_EVENT
    | EventTypeT_MAPPING_START_EVENT
    | EventTypeT_MAPPING_END_EVENT

    /**
     * The Function is hashCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    public func hashCode(): Int64 {
        match (this) {
            case EventTypeT_NO_EVENT => 0
            case EventTypeT_STREAM_START_EVENT => 1
            case EventTypeT_STREAM_END_EVENT => 2
            case EventTypeT_DOCUMENT_START_EVENT => 3
            case EventTypeT_DOCUMENT_END_EVENT => 4
            case EventTypeT_ALIAS_EVENT => 5
            case EventTypeT_SCALAR_EVENT => 6
            case EventTypeT_SEQUENCE_START_EVENT => 7
            case EventTypeT_SEQUENCE_END_EVENT => 8
            case EventTypeT_MAPPING_START_EVENT => 9
            case EventTypeT_MAPPING_END_EVENT => 10
        }
    }

    /**
     * The Function is ==
     *
     * @param b of EventTypeT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func ==(b: EventTypeT): Bool {
        eq(this, b)
    }

    /**
     * The Function is !=
     *
     * @param b of EventTypeT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func !=(b: EventTypeT): Bool {
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
            case EventTypeT_NO_EVENT => "EventTypeT_NO_EVENT"
            case EventTypeT_STREAM_START_EVENT => "EventTypeT_STREAM_START_EVENT"
            case EventTypeT_STREAM_END_EVENT => "EventTypeT_STREAM_END_EVENT"
            case EventTypeT_DOCUMENT_START_EVENT => "EventTypeT_DOCUMENT_START_EVENT"
            case EventTypeT_DOCUMENT_END_EVENT => "EventTypeT_DOCUMENT_END_EVENT"
            case EventTypeT_ALIAS_EVENT => "EventTypeT_ALIAS_EVENT"
            case EventTypeT_SCALAR_EVENT => "EventTypeT_SCALAR_EVENT"
            case EventTypeT_SEQUENCE_START_EVENT => "EventTypeT_SEQUENCE_START_EVENT"
            case EventTypeT_SEQUENCE_END_EVENT => "EventTypeT_SEQUENCE_END_EVENT"
            case EventTypeT_MAPPING_START_EVENT => "EventTypeT_MAPPING_START_EVENT"
            case EventTypeT_MAPPING_END_EVENT => "EventTypeT_MAPPING_END_EVENT"
        }
    }
}
