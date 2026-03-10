/**
 * @file
 * This file is about yaml node.
 */

package yaml4cj.yaml

public type NodeItemT = Int64

/**
 * The class is NodeT
 * @author changeden
 * @since 0.30.4
 */
class NodeT {
    var typ: NodeTypeT = NodeTypeT_NO_NODE
    var tag: Array<UInt8> = Array<UInt8>()
    var scalar: NodeScalarT = NodeScalarT()
    var sequence: NodeSequenceT = NodeSequenceT()
    var mapping: NodeMappingT = NodeMappingT()
    var startMark: MarkT = MarkT()
    var endMark: MarkT = MarkT()
}

/**
 * The class is NodeScalarT
 * @author changeden
 * @since 0.30.4
 */
class NodeScalarT {
    var value: Array<UInt8> = Array<UInt8>()
    var length: Int64 = 0
    var style: ScalarStyleT = ScalarStyleT_ANY_SCALAR_STYLE
}

/**
 * The class is NodeSequenceT
 * @author changeden
 * @since 0.30.4
 */
class NodeSequenceT {
    var items_data: Array<NodeItemT> = Array<NodeItemT>()
    var style: SequenceStyleT = SequenceStyleT_ANY_SEQUENCE_STYLE
}

/**
 * The class is NodeMappingT
 * @author changeden
 * @since 0.30.4
 */
class NodeMappingT {
    var pairsData: Array<NodePairT> = Array<NodePairT>()
    var pairsStart: NodePairT = NodePairT()
    var pairsEnd: NodePairT = NodePairT()
    var pairsTop: NodePairT = NodePairT()
    var style: MappingStyleT = MappingStyleT_ANY_MAPPING_STYLE
}
