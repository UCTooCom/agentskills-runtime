package cj_mail.encoding.base64

import std.collection.*
import std.io.*

import cj_mail.exception.*


private let translationNewLine = "\n".toArray()[0];
private let translationRreturn = "\r".toArray()[0];
private let translationSpace = " ".toArray()[0];
private let translationTab = "\t".toArray()[0];
private let blankRunes = [translationNewLine, translationRreturn, translationSpace, translationTab];

public let Base64DefaultDictionary = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="

public let StdBase64 = Base64()
public let WrappedBase64 = Base64(wrap: true)

public class Base64 {

    private var encodeMap: HashMap<Byte, Byte> = HashMap<Byte, Byte>() // index => rune
    private var decodeMap: HashMap<Byte, Byte> = HashMap<Byte, Byte>() // rune => index
    private var wrap = false
    
    public mut prop dictionary : String {
        get () { 
            String.fromUtf8(Array<UInt8>(
                encodeMap.size
            ) {
                i => encodeMap[UInt8(i)]
            })
        }
        set (newDictString) {
            let buff = newDictString.toArray()
            if (buff.size != 65) {
                throw MailContentParseException("Invalid dictionary size, must be 65 (64 characters + padding character)")
            }
            var encodeMap = HashMap<Byte, Byte>()
            var decodeMap = HashMap<Byte, Byte>()
            for (i in 0..=64) {
                var bt = buff[i]
                encodeMap[UInt8(i)] = bt
                decodeMap[bt] = UInt8(i)
            }
            this.encodeMap = encodeMap
            this.decodeMap = decodeMap
        }
    }

    public init(wrap!: Bool = false) {
        this.dictionary = Base64DefaultDictionary
        this.wrap = wrap
    }

    public init(dictionary: String, wrap!: Bool = false) {
        this.dictionary = dictionary
        this.wrap = wrap
    }

    public func encoder() : Base64Encoder {
        Base64Encoder(encodeMap, wrap: wrap)
    }

    public func decoder() : Base64Decoder {
        Base64Decoder(decodeMap, encodeMap)
    }

    public func outputStream(output: OutputStream): Base64OutputStream {
        Base64OutputStream(output, encodeMap, wrap: wrap)
    }

    public func inputStream(input: InputStream): Base64InputStream {
        Base64InputStream(input, decodeMap, encodeMap)
    }

    public func encodeToString(inputData: Array<Byte>) : String {
        String.fromUtf8(encoder().encode(inputData, finish: true))
    }

    public func decodeFromString(inputString: String) : Array<Byte> {
        decoder().decode(inputString.toArray(), eofAsFinish: true)
    }

}

public class Base64Encoder {

    private let bufferStream: ByteBuffer
    private let encodeSream: Base64OutputStream

    public prop finished: Bool {
        get () { encodeSream.finished }
    }

    protected init(encodeMap: HashMap<Byte, Byte>, wrap!: Bool = false) {
        bufferStream = ByteBuffer()
        encodeSream = Base64OutputStream(bufferStream, encodeMap, wrap: wrap)
    }

    public func encode(input: Array<Byte>, finish!: Bool = false) : Array<Byte> {
        encodeSream.writeData(input, finish: finish)
        let result = bufferStream.bytes()
        bufferStream.clear()
        result
    }

    public func finish() : Array<Byte> {
        encode([], finish: true)
    }

    public func finish(input: Array<Byte>) : Array<Byte> {
        encode(input, finish: true)
    }

}

public class Base64Decoder {

    private let bufferStream: ByteBuffer
    private let decodeStream: Base64InputStream
    private var isFinished = false
    public prop finished: Bool {
        get () {
            isFinished
        }
    }

    protected init(decodeMap: HashMap<Byte, Byte>, encodeMap: HashMap<Byte, Byte>) {
        bufferStream = ByteBuffer()
        decodeStream = Base64InputStream(bufferStream, decodeMap, encodeMap)
    }

    public func decode(input: Array<Byte>, eofAsFinish!: Bool = false) : Array<Byte> {
        if (finished) {
            throw MailContentParseException("decoder has been finished")
        }
        bufferStream.write(input)
        let result = decodeStream.readToEnd(eofAsFinish: eofAsFinish)
        if (eofAsFinish) {
            isFinished = true
        }
        result
    }

    public func finish(): Array<Byte> {
        decode([], eofAsFinish: true)
    }

}

public class Base64OutputStream <: OutputStream {

    private let output: OutputStream
    private let encodeMap: HashMap<Byte, Byte>
    private let wrap: Bool
    private var writeCount = 0

    private var writing = Array<Byte>()
    private var encoded = Array<Byte>(4, {_=>0})

    private var isFinished = false
    public prop finished: Bool { 
        get () { isFinished }
    }

    public init(output: OutputStream, encodeMap: HashMap<Byte, Byte>, wrap!: Bool = false) {
        this.output = output
        this.encodeMap = encodeMap
        this.wrap = wrap
    }

    public func flush() {
        output.flush()
    }

    public func write(data: Array<Byte>) {
        writeData(data)
    }

    public func finish() {
        writeData([], finish: true)
    }

    public func writeData(data: Array<Byte>, finish!: Bool = false) {
        if (isFinished) {
            throw MailContentParseException("Encoder has isFinished")
        }
        func processWrap() {
            if (wrap) {
                writeCount += 4
                if (writeCount >= 76) {
                    output.write([translationRreturn, translationNewLine])
                    writeCount = 0
                }
            }
        }
        writing = if (writing.size == 0) {
            data
        } else {
            let bos = ByteBuffer()
            bos.write(writing)
            bos.write(data)
            bos.bytes()
        }
        while (writing.size >= 3) {
            encode()
            output.write(encoded)
            processWrap()
        }
        if (finish) {
            if (writing.size > 0) {
                if (writing.size == 1) {
                    writing = [writing[0], 0, 0]
                    encode()
                    output.write([encoded[0], encoded[1], encodeMap[64], encodeMap[64]])
                } else if (writing.size == 2) {
                    writing = [writing[0], writing[1], 0]
                    encode()
                    output.write([encoded[0], encoded[1], encoded[2], encodeMap[64]])
                }
            }
            flush()
            isFinished = true
        } else if (writing.size > 0) {
            // !!! IMPORTANT !!! DO NOT DELETE THIS BLOCK !!! 
            // if not copy, the writing's will be changed
            // (because the writing is a reference by byteArrayStream)
            writing = writing.clone()
        }
    }

    private func encode() {
        encode(writing, encoded)
        writing = writing[3..]
    }

    private func encode(i: Array<Byte>, o: Array<Byte>) {
        o[0] = encodeMap[i[0]>>2]
        o[1] = encodeMap[(i[0]<<4 | i[1]>>4) & 0b111111]
        o[2] = encodeMap[(i[1]<<2 | i[2]>>6) & 0b111111]
        o[3] = encodeMap[i[2] & 0b111111]
    }

}

public class Base64InputStream <: InputStream {

    private var inputStream: InputStream

    private var decodeMap: HashMap<Byte, Byte> 
    private var encodeMap: HashMap<Byte, Byte>

    private var cached = Array<Byte>(4, {_=>0})
    private var cachedSize = 0
    private var decodedTemp = Array<Byte>(4, {_=>0})
    private var decoded = Array<Byte>(3, {_=>0})
    private var decodedOff = 0
    private var pad = 0

    private var p = Array<Byte>()
    private var n = 0

    protected init(input: InputStream, decodeMap: HashMap<Byte, Byte>, encodeMap: HashMap<Byte, Byte>) {
        this.inputStream = input
        this.decodeMap = decodeMap
        this.encodeMap = encodeMap
    }

    public func read(input: Array<Byte>) : Int64 {
        readData(input)
    }

    public func readData(input: Array<Byte>, eofAsFinish!: Bool = true) : Int64 {
        p = input
        n = 0
        // last decode data not read over
        putDecode()
        var eof = false
        while (p.size > n) {
            var read = inputStream.read(cached[cachedSize..])
            if (read == 0) {
                eof = true
                break
            }
            // remove space and new line
            var spaceMatchIdx = cachedSize;
            while (spaceMatchIdx < cachedSize + read) {
                if (blankRunes.contains(cached[spaceMatchIdx]) || (pad > 0 && cached[spaceMatchIdx] == encodeMap[64])) {
                    for (i in spaceMatchIdx..cachedSize+read-1) {
                        cached[i] = cached[i+1]
                    }
                    read -= 1
                } else {
                    spaceMatchIdx+=1
                }
            }
            cachedSize += read
            if (pad > 0 && cachedSize > 0) {
                // only allow blank
                throw MailContentParseException("Invalid base64 data, not allow data after pad")
            }
            if (cachedSize == 4) {
                decode()
                putDecode()
            }
        }
        // read full or eof
        if (p.size == n) {
            return n
        }
        if (eof && eofAsFinish) {
            if (cachedSize != 0) {
                if (cachedSize == 1) {
                    if (cached[0] == encodeMap[64]) {
                        cachedSize = 0
                        return n
                    } else {
                        throw MailContentParseException("eof but only one byte : ${cached[0]} ")
                    }
                }
                for (idx in cachedSize..4) {
                    cached[idx] = encodeMap[64]
                }
                decode()
                putDecode()
            }
        }
        n
    }

    func putDecode() {
        if (pad > 0) {
            while (p.size - n > 0 && decodedOff - pad > 0) {
                p[n] = decoded[3 - decodedOff]
                n++
                decodedOff--
            }
            return
        }
        var putCount = min([p.size - n, decodedOff]).getOrThrow()
        for (i in 0..putCount) {
            p[n + i] = decoded[3 - decodedOff +i]
        }
        n += putCount
        decodedOff -= putCount
    }

    public func readToEnd(eofAsFinish!: Bool = true) : Array<Byte> {
        var result = ByteBuffer()
        var buff = Array<Byte>(1024, {_=>0})
        var read = 0
        while (true) {
            read = readData(buff, eofAsFinish: eofAsFinish)
            if (read == 0) {
                break
            }
            result.write(buff[0..read])
        }
        result.bytes()
    }

    private func decode() {
        pad = decode(cached, decodedTemp, decoded)
        cachedSize = 0
        decodedOff = 3
    }

    private func decode(i: Array<Byte>, t: Array<Byte>, o: Array<Byte>) : Int64 {
        var pad = 0
        t[0] = decodeMap[i[0]]
        t[1] = decodeMap[i[1]]
        t[2] = decodeMap[i[2]]
        t[3] = decodeMap[i[3]]
        if (t[0] == 64 || t[1] == 64) {
            throw MailContentParseException("Invalid base64 data")
        }
        if (t[2] == 64) {
            if (t[3] == 64) {
                t[2] = 0
                t[3] = 0
                pad = 2
            } else {
                throw MailContentParseException("Invalid base64 data")
            }
        } else if (t[3] == 64) {
            t[3] = 0
            pad = 1
        }
        o[0] = decodedTemp[0] << 2 | decodedTemp[1]>>4
        o[1] = decodedTemp[1] << 4 | decodedTemp[2]>>2
        o[2] = decodedTemp[2] << 6 | decodedTemp[3]
        pad
    }

}
