/**
 * @file
 * This file is about yaml node type.
 */

package yaml4cj.yaml

enum NodeTypeT {
    | NodeTypeT_NO_NODE
    | NodeTypeT_SCALAR_NODE
    | NodeTypeT_SEQUENCE_NODE
    | NodeTypeT_MAPPING_NODE

    /**
     * The Function is getValues
     *
     * @return Type of Array<NodeTypeT>
     * @since 0.30.4
     */
    /*public static func getValues(): Array<NodeTypeT> {
        [
            NodeTypeT_NO_NODE,
            NodeTypeT_SCALAR_NODE,
            NodeTypeT_SEQUENCE_NODE,
            NodeTypeT_MAPPING_NODE
        ]
    }

    /**
     * The Function is getCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    func getCode(): Int64 {
        match (this) {
            case NodeTypeT_NO_NODE => 0
            case NodeTypeT_SCALAR_NODE => 1
            case NodeTypeT_SEQUENCE_NODE => 2
            case NodeTypeT_MAPPING_NODE => 3
        }
    }

    /**
     * The Function is hashCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    public func hashCode(): Int64 {
        genHashCode([getCode()], name: "NodeTypeT")
    }

    /**
     * The Function is ==
     *
     * @param b of NodeTypeT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func ==(b: NodeTypeT): Bool {
        eq(getCode(), b.getCode())
    }

    /**
     * The Function is !=
     *
     * @param b of NodeTypeT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func !=(b: NodeTypeT): Bool {
        ne(getCode(), b.getCode())
    }*/
}
