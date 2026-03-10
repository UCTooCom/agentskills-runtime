/**
 * @file
 * This file is about reader.
 */

package yaml4cj.yaml

let BOM_UTF8: Array<UInt8> = [0xef, 0xbb, 0xbf]
let BOM_UTF16LE: Array<UInt8> = [0xff, 0xfe]
let BOM_UTF16BE: Array<UInt8> = [0xfe, 0xff]

func parserSetReaderError(parser: ParserT, problem: String, offset: Int64, value: Int64): Bool {
    parser.error = ErrorTypeT_READER_ERROR
    parser.problem = problem
    parser.problemOffset = offset
    parser.problemValue = value
    false
}

func parserDetermineEncoding(parser: ParserT): Bool {
    while (!parser.eof && parser.rawBuffer.size - parser.rawBufferPos < 3) {
        if (!parserUpdateRawBuffer(parser)) {
            return false
        }
    }

    let buf = parser.rawBuffer
    let pos = parser.rawBufferPos
    let avail = buf.size - pos
    if (avail >= 2 && buf[pos] == BOM_UTF16LE[0] && buf[pos + 1] == BOM_UTF16LE[1]) {
        parser.encoding = EncodingT_UTF16LE_ENCODING
        parser.rawBufferPos += 2
        parser.offset += 2
    } else if (avail >= 2 && buf[pos] == BOM_UTF16BE[0] && buf[pos + 1] == BOM_UTF16BE[1]) {
        parser.encoding = EncodingT_UTF16BE_ENCODING
        parser.rawBufferPos += 2
        parser.offset += 2
    } else if (avail >= 3 && buf[pos] == BOM_UTF8[0] && buf[pos + 1] == BOM_UTF8[1] && buf[pos + 2] == BOM_UTF8[2]) {
        parser.encoding = EncodingT_UTF8_ENCODING
        parser.rawBufferPos += 3
        parser.offset += 3
    } else {
        parser.encoding = EncodingT_UTF8_ENCODING
    }
    true
}

func parserUpdateRawBuffer(parser: ParserT): Bool {
    if (parser.rawBufferPos == 0 && parser.rawBuffer.size == parser.rawBuffer.capacity) {
        return true
    }

    if (parser.eof) {
        return true
    }

    try {
        if (parser.rawBufferPos > 0 && parser.rawBufferPos < parser.rawBuffer.size) {
            copy(parser.rawBuffer, parser.rawBuffer, srcStart: parser.rawBufferPos)
        }

        if (parser.rawBuffer.size - parser.rawBufferPos <= 0) {
            parser.rawBuffer.clear()
        } else {
            let t = parser.rawBuffer[0..(parser.rawBuffer.size - parser.rawBufferPos)]
            parser.rawBuffer = ArrayList<UInt8>(inputRawBufferSize)
            for (v in t) {
                parser.rawBuffer.add(v)
            }
        }
        parser.rawBufferPos = 0

        let writeStart = parser.rawBuffer.size
        let tempRawBuffer = Array<UInt8>(parser.rawBuffer.capacity - writeStart, repeat: 0)
        let sizeRead = parser.readHandler.getOrThrow()(parser, tempRawBuffer)
        if (sizeRead > 0) {
            parser.rawBuffer.fill(length: sizeRead)
            copy(parser.rawBuffer, tempRawBuffer, dstStart: writeStart, srcEnd: sizeRead)
        } else {
            parser.eof = true
        }
        let tempRawBuf = ArrayList<UInt8>(inputRawBufferSize)
        tempRawBuf.add(all: parser.rawBuffer[0..(writeStart + sizeRead)])
        parser.rawBuffer = tempRawBuf
    } catch (e: Exception) {
        return parserSetReaderError(parser, "input error: ${e}", parser.offset, -1)
    }
    true
}

func parserUpdateBufferInner(parser: ParserT, bufferLenBox: Box<Int64>): ?Bool {
    while (parser.rawBufferPos != parser.rawBuffer.size) {
        var value: UInt32
        var width: Int64
        let rawUnread = parser.rawBuffer.size - parser.rawBufferPos

        match (parser.encoding) {
            case EncodingT_UTF8_ENCODING =>
                var octet = parser.rawBuffer[parser.rawBufferPos]
                width = if ((octet & 0x80) == 0x00) {
                    1
                } else if ((octet & 0xE0) == 0xC0) {
                    2
                } else if ((octet & 0xF0) == 0xE0) {
                    3
                } else if ((octet & 0xF8) == 0xF0) {
                    4
                } else {
                    return parserSetReaderError(
                        parser,
                        "invalid leading UTF-8 octet",
                        parser.offset,
                        Int64(octet)
                    )
                }

                if (width > rawUnread) {
                    /*if (parser.eof) {
                        return parserSetReaderError(
                            parser,
                            "incomplete UTF-8 octet sequence",
                            parser.offset,
                            -1
                        )
                    }*/
                    return None
                }

                value = if ((octet & 0x80) == 0x00) {
                    UInt32(octet & 0x7F)
                } else if ((octet & 0xE0) == 0xC0) {
                    UInt32(octet & 0x1F)
                } else if ((octet & 0xF0) == 0xE0) {
                    UInt32(octet & 0x0F)
                } else if ((octet & 0xF8) == 0xF0) {
                    UInt32(octet & 0x07)
                } else {
                    0
                }

                for (k in 1..width) {
                    octet = parser.rawBuffer[parser.rawBufferPos + k]

                    if ((octet & 0xC0) != 0x80) {
                        /*return parserSetReaderError(
                            parser,
                            "invalid trailing UTF-8 octet",
                            parser.offset + k,
                            Int64(octet)
                        )*/
                    }

                    value = (UInt32(value) << 6) + UInt32(octet & 0x3F)
                }

                if (!(width == 1 || (width == 2 && value >= 0x80) || (width == 3 && value >= 0x800) || (width == 4 &&
                    value >= 0x10000))) {
                    return parserSetReaderError(
                        parser,
                        "invalid length of a UTF-8 sequence",
                        parser.offset,
                        -1
                    )
                }

                if (value >= 0xD800 && value <= 0xDFFF || value > 0x10FFFF) {
                    /*return parserSetReaderError(
                        parser,
                        "invalid Unicode character",
                        parser.offset,
                        Int64(UInt32(value))
                    )*/
                }
            case EncodingT_UTF16LE_ENCODING | EncodingT_UTF16BE_ENCODING =>
                let (low, high) = if (parser.encoding == EncodingT_UTF16LE_ENCODING) {
                    (0, 1)
                } else {
                    (1, 0)
                }
                if (rawUnread < 2) {
                    if (parser.eof) {
                        return parserSetReaderError(
                            parser,
                            "incomplete UTF-16 character",
                            parser.offset,
                            -1
                        )
                    }
                    return None
                }

                value = UInt32(parser.rawBuffer[parser.rawBufferPos + low]) + (UInt32(parser.rawBuffer[parser.
                        rawBufferPos + high]) << 8)

                if ((value & 0xFC00) == 0xDC00) {
                    return parserSetReaderError(
                        parser,
                        "unexpected low surrogate area",
                        parser.offset,
                        Int64(value)
                    )
                }

                if ((value & 0xFC00) == 0xD800) {
                    width = 4

                    if (rawUnread < 4) {
                        if (parser.eof) {
                            /*return parserSetReaderError(
                                parser,
                                "incomplete UTF-16 surrogate pair",
                                parser.offset,
                                -1
                            )*/
                        }
                        return None
                    }

                    let value2 = UInt32(parser.rawBuffer[parser.rawBufferPos + low + 2]) + (UInt32(parser.rawBuffer[parser.
                            rawBufferPos + high + 2]) << 8)
                    if ((value2 & 0xFC00) != 0xDC00) {
                        return parserSetReaderError(
                            parser,
                            "expected low surrogate area",
                            parser.offset + 2,
                            Int64(value2)
                        )
                    }

                    value = 0x10000 + ((value & 0x3FF) << 10) + (value2 & 0x3FF)
                } else {
                    width = 2
                }

            case _ => throw Exception("impossible")
        }

        if (!(value == 0x09 || value == 0x0A || value == 0x0D || (value >= 0x20 && value <= 0x7E) || value == 0x85 || (value>=
            0xA0 && value <= 0xD7FF) || (value >= 0xE000 && value <= 0xFFFD) || (value >= 0x10000 && value <= 0x10FFFF))) {
            return parserSetReaderError(
                parser,
                "control characters are not allowed",
                parser.offset,
                Int64(value)
            )
        }
        parser.rawBufferPos += width
        parser.offset += width

        let bufferLen = bufferLenBox.value
        bufferLenBox.value += if (value <= 0x7F) {
            parser.buffer[bufferLen + 0] = UInt8(value)
            1
        } else if (value <= 0x7FF) {
            parser.buffer[bufferLen + 0] = UInt8(0xC0 + (value >> 6))
            parser.buffer[bufferLen + 1] = UInt8(0x80 + (value & 0x3F))
            2
        } else if (value <= 0xFFFF) {
            parser.buffer[bufferLen + 0] = UInt8(0xE0 + (value >> 12))
            parser.buffer[bufferLen + 1] = UInt8(0x80 + ((value >> 6) & 0x3F))
            parser.buffer[bufferLen + 2] = UInt8(0x80 + (value & 0x3F))
            3
        } else {
            parser.buffer[bufferLen + 0] = UInt8(0xF0 + (value >> 18))
            parser.buffer[bufferLen + 1] = UInt8(0x80 + ((value >> 12) & 0x3F))
            parser.buffer[bufferLen + 2] = UInt8(0x80 + ((value >> 6) & 0x3F))
            parser.buffer[bufferLen + 3] = UInt8(0x80 + (value & 0x3F))
            4
        }
        parser.bufferTemp = parser.buffer
        parser.unread++
    }
    None
}

func parserUpdateBuffer(parser: ParserT, length: Int64): Bool {
    if (let None <- parser.readHandler) {
        throw Exception("read handler must be set")
    }

    if (parser.unread >= length) {
        return true
    }

    if (parser.encoding == EncodingT_ANY_ENCODING && !parserDetermineEncoding(parser)) {
        return false
    }

    var bufferLen = Box<Int64>(parser.buffer.size)
    if (parser.bufferPos > 0 && parser.bufferPos < bufferLen.value) {
        copy(parser.bufferTemp, parser.bufferTemp, srcStart: parser.bufferPos, srcEnd: bufferLen.value)
        bufferLen.value -= parser.bufferPos
        parser.bufferPos = 0
    } else if (parser.bufferPos == bufferLen.value) {
        bufferLen.value = 0
        parser.bufferPos = 0
    }
    if (parser.bufferTemp.size >= inputBufferSize) {
        parser.buffer = parser.bufferTemp
    } else {
        let tBuffer = ArrayList<UInt8>(inputBufferSize)
        tBuffer.add(all: parser.buffer)
        tBuffer.fill()
        parser.buffer = tBuffer
    }

    var first = true

    while (parser.unread < length) {
        if ((!first || parser.rawBufferPos == parser.rawBuffer.size) && !parserUpdateRawBuffer(parser)) {
            parser.buffer = parser.buffer[0..bufferLen.value]
            return false
        }

        first = false

        if (let Some(b) <- parserUpdateBufferInner(parser, bufferLen)) {
            return b
        }

        if (parser.eof) {
            parser.buffer[bufferLen.value] = 0
            bufferLen.value++
            parser.unread++
            break
        }
    }

    while (bufferLen.value < length) {
        parser.buffer[bufferLen.value] = 0
        bufferLen.value++
    }
    parser.buffer = parser.buffer[0..bufferLen.value]
    true
}
