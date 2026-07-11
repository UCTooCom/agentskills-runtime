package cj_mail.tests

import std.io.*

import stdx.log.*
import std.unittest.*
import std.unittest.testmacro.*

import cj_mail.*

@When[test]
@Test
public class Base64Tests {

    let logger = getGlobalLogger(("name", "cj_mail.tests.Base64Tests"))

    let testText = "你好，世界！我是一名仓颉工程师！在编写BASE64工具包。AESTE6N;Z5^Y5`5Y2D^D"
    let testBase64 = "5L2g5aW977yM5LiW55WM77yB5oiR5piv5LiA5ZCN5LuT6aKJ5bel56iL5biI77yB5Zyo57yW5YaZQkFTRTY05bel5YW35YyF44CCQUVTVEU2TjtaNV5ZNWA1WTJEXkQ="


    @TestCase
    func encodeToString(): Unit {
        logger.debug("Testing StdBase64 encodeToString")
        let encoded = StdBase64.encodeToString(testText.toArray())
        @Expect(encoded, testBase64) 
    }

    @TestCase
    func decodeFromString(): Unit {
        logger.debug("Testing StdBase64 decodeFromString")
        let decoded = StdBase64.decodeFromString(testBase64)
        let decodedText = String.fromUtf8(decoded);
        @Expect(decodedText, testText)
    }

    @TestCase
    func encodeStream(): Unit {
        logger.debug("Testing StdBase64 encodeStream")
        let encoder = StdBase64.encoder()
        let stream = ByteArrayStream()
        stream.write(testText.toArray())
        stream.flush()
        let out = ByteArrayStream()
        let buffer = Array<Byte>(10, {_=>0})
        var read: Int64
        while (true) {
            read = stream.read(buffer)
            if (read == 0) {
                break
            }
            let encoded = encoder.encode(buffer[0..read])
            out.write(encoded)
        }
        out.write(encoder.finish())
        let encoded = String.fromUtf8(out.readToEnd())
        @Expect(encoded, testBase64) 
    }

    @TestCase
    func decodeStream(): Unit {
        logger.debug("Testing StdBase64 decodeStream")
        let decoder = StdBase64.decoder()
        let stream = ByteArrayStream()
        stream.write(testBase64.toArray())
        stream.flush()
        let out = ByteArrayStream()
        let buffer = Array<Byte>(10, {_=>0})
        var read: Int64
        while (true) {
            read = stream.read(buffer)
            if (read == 0) {
                break
            }
            let decoded = decoder.decode(buffer[0..read])
            out.write(decoded)
        }
        out.write(decoder.finish())
        let decoded = String.fromUtf8(out.readToEnd())
        @Expect(decoded, testText) 
    }
}
