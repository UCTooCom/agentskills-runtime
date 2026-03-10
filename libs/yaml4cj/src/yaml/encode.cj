/**
 * @file
 * This file is about yaml encode.
 */

package yaml4cj.yaml

/**
 * The Function is encode
 *
 * @param input of JsonValue
 *
 * @return Type of Array<UInt8>
 * @since 0.30.4
 */
public func encode(input: JsonValue): Array<UInt8> {
    initResolve()
    let e = Encoder()
    try {
        e.encode("", input)
        e.finish()
        e.out.toArray()
    } catch (err: Exception) {
        throw err
    } finally {
        e.destroy()
    }
}

var disableLineWrapping = false

class Encoder {
    var emitter: EmitterT = EmitterT()
    var event: EventT = EventT()
    let out: ArrayList<UInt8> = ArrayList<UInt8>()
    var flow: Bool = false
    var doneInit: Bool = false

    init() {
        emitterInitialize()
        emitterSetOutputString()
    }

    func emitterInitialize() {
        this.emitter = EmitterT()
        this.emitter.buffer = ArrayList<UInt8>(outputBufferSize, {_ => 0})
        this.emitter.rawBuffer = ArrayList<UInt8>(outputRawBufferSize)
        this.emitter.states = ArrayList<EmitterStateT>(initialStackSize)
        this.emitter.events = ArrayList<EventT>(initialQueueSize)
        if (disableLineWrapping) {
            this.emitter.bestWidth = -1
        }
    }

    func emitterSetOutputString() {
        if (let Some(_) <- emitter.writeHandler) {
            throw Exception("must set the output target only once")
        }
        emitter.writeHandler = stringWriteHandler
        emitter.outputBuffer = this.out
    }

    func initiator() {
        if (this.doneInit) {
            return
        }
        this.event = streamStartEventinitialize(EncodingT_UTF8_ENCODING)
        emit()
        this.doneInit = true
    }

    func finish() {
        this.emitter.openEnded = false
        this.event = streamEndEventinitialize()
        emit()
    }

    func destroy() {
        this.emitter = emitterDelete()
    }

    func emit() {
        must(emitterEmit(this.emitter, this.event, this))
    }

    func must(ok: Bool) {
        if (!ok) {
            let msg = if (this.emitter.problem == "") {
                "unknown problem generating YAML content"
            } else {
                this.emitter.problem
            }
            failf(msg)
        }
    }

    func encode(tag: String, input: JsonValue) {
        initiator()
        this.event = documentStartEventinitialize(true)
        emit()
        encodeValue(tag, input)
        this.event = documentEndEventinitialize(true)
        emit()
    }

    func encodeValue(tag: String, input: JsonValue): Unit {
        if (input is JsonNull) {
            nilv()
        } else if (input is JsonObject) {
            mapv(tag, (input as JsonObject).getOrThrow())
        } else if (input is JsonArray) {
            slicev(tag, (input as JsonArray).getOrThrow())
        } else if (input is JsonString) {
            stringv(tag, (input as JsonString).getOrThrow())
        } else if (input is JsonInt) {
            intv(tag, (input as JsonInt).getOrThrow())
        } else if (input is JsonFloat) {
            floatv(tag, (input as JsonFloat).getOrThrow())
        } else if (input is JsonBool) {
            boolv(tag, (input as JsonBool).getOrThrow())
        } else {
            throw Exception("cannot marshal type: ${input}")
        }
    }

    func nilv() {
        emitScalar("null", "", "", ScalarStyleT_PLAIN_SCALAR_STYLE)
    }

    func emitScalar(value: String, anchor: String, tag: String, style: ScalarStyleT) {
        let implicit = tag == ""
        let (eve, ok) = scalarEventInitialize(
            anchor.toArray(),
            tag.toArray(),
            value.toArray(),
            implicit,
            implicit,
            style
        )
        this.event = eve
        must(ok)
        emit()
    }

    func mapv(tag: String, input: JsonObject) {
        mappingv(tag, {
                 =>
                let kv = input.getFields()
                for ((k, v) in kv) {
                    encodeValue("", JsonString(k))
                    encodeValue("", v)
                }
            })
    }

    func mappingv(tag: String, f: () -> Unit) {
        let implicit = tag == ""
        var style = MappingStyleT_BLOCK_MAPPING_STYLE
        if (this.flow) {
            this.flow = false
            style = MappingStyleT_FLOW_MAPPING_STYLE
        }
        this.event = mappingStartEventInitialize([], tag.toArray(), implicit, style)
        emit()
        f()
        this.event = mappingEndEventInitialize()
        emit()
    }

    func slicev(tag: String, input: JsonArray) {
        let implicit = tag == ""
        var style = SequenceStyleT_BLOCK_SEQUENCE_STYLE
        if (this.flow) {
            this.flow = false
            style = SequenceStyleT_FLOW_SEQUENCE_STYLE
        }
        let (eve0, ok0) = sequenceStartEventInitialize([], tag.toArray(), implicit, style)
        this.event = eve0
        must(ok0)
        emit()
        for (i in 0..input.size()) {
            encodeValue("", input[i])
        }
        let (eve1, ok1) = sequenceEndEventInitialize()
        this.event = eve1
        must(ok1)
        emit()
    }

    func stringv(ntag: String, input: JsonString) {
        var s = input.getValue()
        var canUsePlain = true
        var tag = ntag
        if (!utf8ValidString(s)) {
           /* if (tag == YAML_BINARY_TAG) {
                failf("explicitly tagged !!binary data must be base64-encoded")
            }
            if (tag != "") {
                failf("cannot marshal invalid UTF-8 data as ${shortTag(tag)}")
            }
            tag = YAML_BINARY_TAG
            s = encodeBase64(s)*/
        } else if (tag == "") {
            let (rtag, _) = resolve("", s)
            canUsePlain = rtag == YAML_STR_TAG && !isBase60Float(s)
        }
        let style = if (s.contains("\n")) {
            ScalarStyleT_LITERAL_SCALAR_STYLE
        } else if (canUsePlain) {
            ScalarStyleT_PLAIN_SCALAR_STYLE
        } else {
            ScalarStyleT_DOUBLE_QUOTED_SCALAR_STYLE
        }
        emitScalar(s, "", tag, style)
    }

    func intv(tag: String, input: JsonInt) {
        emitScalar("${input.getValue()}", "", tag, ScalarStyleT_PLAIN_SCALAR_STYLE)
    }

    func floatv(tag: String, input: JsonFloat) {
        let v = input.getValue()
        let s = if (Float64.Inf == v) {
            ".inf"
        } else if (-Float64.Inf == v) {
            "-.inf"
        } else if (Float64.NaN == v) {
            ".nan"
        } else {
            "${v}"
        }
        emitScalar(s, "", tag, ScalarStyleT_PLAIN_SCALAR_STYLE)
    }

    func boolv(tag: String, input: JsonBool) {
        let s = if (input.getValue()) {
            "true"
        } else {
            "false"
        }
        emitScalar(s, "", tag, ScalarStyleT_PLAIN_SCALAR_STYLE)
    }
}

func stringWriteHandler(emitter: EmitterT, buffer: ArrayList<UInt8>) {
    emitter.outputBuffer.add(all: buffer)
}

func emitterDelete(): EmitterT {
    EmitterT()
}

func streamStartEventinitialize(encoding: EncodingT): EventT {
    let e = EventT()
    e.typ = EventTypeT_STREAM_START_EVENT
    e.encoding = encoding
    e
}

func streamEndEventinitialize(): EventT {
    let e = EventT()
    e.typ = EventTypeT_STREAM_END_EVENT
    e
}

func documentStartEventinitialize(implicit: Bool): EventT {
    let e = EventT()
    e.typ = EventTypeT_DOCUMENT_START_EVENT
    e.versionDirective = None
    e.tagDirectives.clear()
    e.implicit = implicit
    e
}

func documentEndEventinitialize(implicit: Bool): EventT {
    let e = EventT()
    e.typ = EventTypeT_DOCUMENT_END_EVENT
    e.implicit = implicit
    e
}

func emitterEmit(emitter: EmitterT, event: EventT, encoder: Encoder): Bool {
    emitter.events.add(event)
    while (!emitterNeedMoreEvents(emitter)) {
        let e = emitter.events[emitter.eventsHead]
        if (!emitterAnalyzeEvent(emitter, e)) {
            return false
        }
        let (eve, ok) = emitterStateMachine(emitter, e)
        encoder.event = eve
        if (!ok) {
            return false
        }
        encoder.event = eventDelete()
        emitter.eventsHead++
    }
    true
}

func eventDelete(): EventT {
    EventT()
}

let base60float = Regex("^[-+]?[0-9][0-9_]*(?::[0-5]?[0-9])+(?:\\.[0-9_]*)?$")

func isBase60Float(s: String): Bool {
    if (s == "") {
        return false
    }
    let c = s[0]
    if (!(c == b'+' || c == b'-' || c >= b'0' && c <= b'9') || match (s.indexOf(b':')) {
        case None => true
        case _ => false
    }) {
        return false
    }
    return base60float.matches(s)

}
