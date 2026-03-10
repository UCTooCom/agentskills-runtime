/**
 * @file
 * This file is about yaml event.
 */

package yaml4cj.yaml

/**
 * The class is EventT
 * @author changeden
 * @since 0.30.4
 */
class EventT {
    var typ: EventTypeT = EventTypeT_NO_EVENT
    var startMark: MarkT = MarkT()
    var endMark: MarkT = MarkT()
    var encoding: EncodingT = EncodingT_ANY_ENCODING
    var versionDirective: ?VersionDirectiveT = None
    var tagDirectives: ArrayList<TagDirectiveT> = ArrayList<TagDirectiveT>()
    var anchor: Array<UInt8> = Array<UInt8>()
    var tag: Array<UInt8> = Array<UInt8>()
    var value: Array<UInt8> = Array<UInt8>()
    var implicit: Bool = false
    var quotedImplicit: Bool = false
    var style: StyleT = NullStyleT_NULL_STYLE

    /**
     * The Function is scalar_style
     *
     * @return Type of ScalarStyleT
     * @since 0.30.4
     */
    func scalarStyle(): ScalarStyleT {
        ScalarStyleT.get(this.style)
    }

    /**
     * The Function is sequence_style
     *
     * @return Type of SequenceStyleT
     * @since 0.30.4
     */
    func sequenceStyle(): SequenceStyleT {
        SequenceStyleT.get(this.style)
    }

    /**
     * The Function is mapping_style
     *
     * @return Type of MappingStyleT
     * @since 0.30.4
     */
    func mappingStyle(): MappingStyleT {
        MappingStyleT.get(this.style)
    }
}
