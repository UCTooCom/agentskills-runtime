package cj_mail.encoding.quotedprintable

import std.io.*
import std.collection.*

import cj_mail.exception.*


let exclamationMark = "!".toArray()[0]
let tilde = "~".toArray()[0]
let equals = "=".toArray()[0]
let translationNewLine = "\n".toArray()[0]
let translationRreturn = "\r".toArray()[0]

let space = " ".toArray()[0]
let tab = "\t".toArray()[0]

let zero = "0".toArray()[0]
let nine = "9".toArray()[0]
let upperA = "A".toArray()[0]
let upperF = "F".toArray()[0]
let lowerA = "a".toArray()[0]
let lowerF = "f".toArray()[0]

const lineMaxLen = 76
let upperhex = "0123456789ABCDEF".toArray()

public let StdQuotedPrintable = QuotedPrintable()

public class QuotedPrintable {

    public func encoder(): QuotedPrintableEncoder {
        QuotedPrintableEncoder()
    }

    public func decoder(): QuotedPrintableDecoder {
        QuotedPrintableDecoder()
    }

    public func encodeOutputStream(output: OutputStream): OutputStream {
        QuotedPrintableOutputStream(output)
    }

    public func decodeInputStream(input: InputStream): InputStream {
        QuotedPrintableInputStream(input)
    }

    public func encodeToString(data: Array<Byte>): String {
        let buffStream = ByteBuffer()
        let qpoStream = QuotedPrintableOutputStream(buffStream)
        qpoStream.write(data)
        qpoStream.flushLine()
        String.fromUtf8(buffStream.bytes())
    }

    public func decodeFromString(data: String): Array<Byte> {
        decoder().decode(data.toArray(), finish: true)
    }
}

public class QuotedPrintableEncoder {
    
    let buffStream = ByteBuffer()
    let qpoStream = QuotedPrintableOutputStream(buffStream)
    private var isFinished = false

    public prop finished: Bool {
        get () { isFinished }
    }

    protected init() {
    }

    public func encode(data: Array<Byte>, finish!: Bool = false): Array<Byte> {
        if (isFinished) {
            throw MailContentParseException("Encoder has isFinished")
        }
        qpoStream.write(data)
        if (finish) {
            qpoStream.flushLine()
            isFinished = true
        }
        qpoStream.flush()
        let result = buffStream.bytes()
        buffStream.clear()
        result
    }

    public func finish(): Array<Byte> {
        encode([], finish: true)
    }

}

public class QuotedPrintableDecoder {

    private let buffStream = ByteBuffer()
    private let qpiStream = QuotedPrintableInputStream(buffStream)
    private let resultStream = ByteBuffer()
    private let buffer = Array<Byte>(1<<10, {_=>0})
    private var isFinished = false

    protected init() {
        
    }

    public func decode(data: Array<Byte>, finish!: Bool = false): Array<Byte> {
        if (isFinished) {
            throw MailContentParseException("Decoder has isFinished")
        }
        buffStream.write(data)
        while(true) {
            let n = qpiStream.readData(buffer, ignoreEof: !finish)
            if (n == 0) {
                break
            }
            resultStream.write(buffer[0..n])
        }
        if (finish) {
            isFinished = true
        }
        let result = resultStream.bytes()
        resultStream.clear()
        buffStream.clear()
        result
    }

    public func finish(): Array<Byte> {
        decode([], finish: true)
    }

}

private func isWhitespace(b: Byte): Bool {
    b == space || b == tab
}

public class QuotedPrintableOutputStream <: OutputStream {

    private let output: OutputStream
    private var cr = false
	private let line = Array<Byte>(78, {_=>0})
    private var i = 0

    protected init(output: OutputStream) {
        this.output = output
    }

    public func write(p: Array<Byte>): Unit {
        writeData(p)
    }

    public func flush() {
        output.flush()
    }

    public func writeData(p: Array<Byte>): Int64 {
        var n = 0
        for (i in 0..p.size) {
            let b = p[i]
            if (b >= exclamationMark && b <= tilde && b != equals) {
                continue
            }
            if (isWhitespace(b)) {
                continue
            }
            if (i > n) {
                writeRaw(p[n..i])
                n = i
            }
            encode(b)
            n++
        }
        if (n == p.size) {
            return n
        }
        writeRaw(p[n..p.size])
        return p.size
    }

    private func writeRaw(p: Array<Byte>) {
        for (idx in 0..p.size) {
            let b = p[idx]
            if (b == translationNewLine || b == translationRreturn) {
                // If the previous byte was \r, the CRLF has already been inserted.
                if (cr && b == translationNewLine) {
                    cr = false
                    continue
                }

                if (b == translationRreturn) {
                    cr = true
                }

                checkLastByte()
                insertCRLF()

                continue
            }

            if (i == lineMaxLen-1) {
                insertSoftLineBreak()
            }

            line[i] = b
            this.i ++
            cr = false
        }
    }

    private func encode(b: Byte) {
        if (lineMaxLen - 1 - i < 3) {
		    insertSoftLineBreak()
	    }
        line[i] = equals
        line[i+1] = upperhex[Int64(b>>4)]
        line[i+2] = upperhex[Int64(b&0x0f)]
        i += 3
    }

    private func  checkLastByte()  {
        if (i == 0) {
            return
        }
        let b = line[i-1]
        if (isWhitespace(b)) {
            i--
            encode(b)
        }
    }

    private func insertSoftLineBreak() {
        line[i] = equals
        i++
        insertCRLF()
    }

    private func insertCRLF() {
        line[i] = translationRreturn
        line[i+1] = translationNewLine
        i += 2
        flushLine()
    }

    public func flushLine() {
        output.write(line[0..i])
        i = 0
        output.flush()
    }

}

public class QuotedPrintableInputStream <: InputStream {

    private let input: InputStream
    private let reader: StringReader<InputStream>
    private var perignoreEof = false
    private var lineArray = Array<Byte>()
    
    protected init(input: InputStream) {
        this.input = input
        this.reader = StringReader<InputStream>(input)
    }

    public func read(buffer: Array<Byte>): Int {
        readData(buffer, ignoreEof: true)
    }

    public func readData(buffer: Array<Byte>, ignoreEof!:Bool = false): Int {
        // Deviations from RFC 2045:
        // 1. in addition to "=\r\n", "=\n" is also treated as soft line break.
        // 2. it will pass through a '\r' or '\n' not preceded by '=', consistent
        //    with other broken QP encoders & decoders.
        // 3. it accepts soft line-break (=) at end of message (issue 15486); i.e.
        //    the final byte read from the underlying reader is allowed to be '=',
        //    and it will be silently ignored.
        // 4. it takes = as literal = if not followed by two hex digits
        //    but not at end of line (issue 13219).
        var n = 0
        var p = buffer
        while (p.size > 0) {
            if (lineArray.size == 0) {
                match (reader.readUntil({rune => rune == r'\n'})) {
                    case Some(line) =>
                        lineArray = line.toArray()
                    case None =>
                        break
                }
            }
            if (perignoreEof) {
                match (reader.readUntil({rune => rune == r'\n'})) {
                    case Some(line) =>
                        let list = ArrayList<Byte>(lineArray)
                        list.add(all: line.toArray())
                        lineArray = list.toArray()
                        perignoreEof = false
                    case None =>
                        ()
                }
            }
            if (lineArray[0] == equals) {
                if (lineArray.size == 1) {
                    if (ignoreEof) {
                        perignoreEof = true
                        break
                    }
                }
                if (lineArray[1] == translationNewLine) {
                    lineArray = lineArray[2..]
                    continue
                }
                if (lineArray[1] == translationRreturn && lineArray[2] == translationNewLine) {
                    lineArray = lineArray[3..]
                    continue
                }
                if (lineArray.size < 3) {
                    if (ignoreEof) {
                        perignoreEof = true
                        break
                    }
                    throw MailContentParseException("Invalid quoted-printable encoding")
                }
                p[0] = (fromHex(lineArray[1]) << 4) | fromHex(lineArray[2])
                n++
                p = buffer[n..]
                lineArray = lineArray[3..]
            } else {
                p[0] = lineArray[0]
                n++
                p = buffer[n..]
                lineArray = lineArray[1..]
            }
        }
        n
    }

    func fromHex(b: Byte): Byte {
        if (b >= zero && b <= nine) {
            return b - zero
        }
        if (b >= upperA && b <= upperF) {
            return b - upperA + 10
        }
        if (b >= lowerA && b <= lowerF) {
            return b - lowerA + 10
        }
        throw MailContentParseException("Invalid quoted-printable encoding")
    }

}
