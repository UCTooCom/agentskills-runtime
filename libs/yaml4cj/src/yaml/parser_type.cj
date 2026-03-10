/**
 * @file
 * This file is about yaml parser.
 */

package yaml4cj.yaml

type ReadHandlerT = (ParserT, Array<UInt8>) -> Int64

/**
 * The class is ParserT
 * @author changeden
 * @since 0.30.4
 */
class ParserT {
    var error: ErrorTypeT = ErrorTypeT_NO_ERROR

    var problem: String = ""
    var problemOffset: Int64 = 0
    var problemValue: Int64 = 0
    var problemMark: MarkT = MarkT()

    var context: String = ""
    var contextMark: MarkT = MarkT()

    var readHandler: ?ReadHandlerT = None
    var input: Array<UInt8> = Array<UInt8>()
    var inputPos: Int64 = 0

    var eof: Bool = false

    var buffer: ArrayList<UInt8> = ArrayList<UInt8>()
    var bufferTemp: ArrayList<UInt8> = ArrayList<UInt8>()
    var bufferPos: Int64 = 0

    var unread: Int64 = 0

    var rawBuffer: ArrayList<UInt8> = ArrayList<UInt8>()
    var rawBufferPos: Int64 = 0

    var encoding: EncodingT = EncodingT_ANY_ENCODING
    var offset: Int64 = 0
    var mark: MarkT = MarkT()

    var streamStartProduced: Bool = false
    var streamEndProduced: Bool = false

    var flowLevel: Int64 = 0

    var tokens: ArrayList<TokenT> = ArrayList<TokenT>(1)
    var tokensHead: Int64 = 0
    var tokensParsed: Int64 = 0
    var tokenAvailable: Bool = false

    var indent: Int64 = 0
    var indents: ArrayList<Int64> = ArrayList<Int64>()

    var simpleKeyAllowed: Bool = false
    var simpleKeys: ArrayList<SimpleKeyT> = ArrayList<SimpleKeyT>()
    var simpleKeysByTok: HashMap<Int64, Int64> = HashMap<Int64, Int64>()

    var state: ParserStateT = ParserStateT_PARSE_STREAM_START_STATE
    var states: ArrayList<ParserStateT> = ArrayList<ParserStateT>()
    var marks: ArrayList<MarkT> = ArrayList<MarkT>()
    var tagDirectives: ArrayList<TagDirectiveT> = ArrayList<TagDirectiveT>()

    var aliases: ArrayList<AliasDataT> = ArrayList<AliasDataT>()
    var document: DocumentT = DocumentT()
}
