package cj_mail.tests

import std.io.*

import stdx.log.*
import std.unittest.*
import std.unittest.testmacro.*

import cj_mail.*

@When[test]
@Test
public class QuotedPrintableTests {
    let logger = getGlobalLogger(("name", "cj_mail.tests.QuotedPrintableTests"))
    
    let testText = "你好，世界！我是一名仓颉工程师！在编写Quoted Printable工具包。AESTE6N;Z5^Y5`5Y2D^D"
    let testEncodedText = "=E4=BD=A0=E5=A5=BD=EF=BC=8C=E4=B8=96=E7=95=8C=EF=BC=81=E6=88=91=E6=98=AF=E4=\r\n=B8=80=E5=90=8D=E4=BB=93=E9=A2=89=E5=B7=A5=E7=A8=8B=E5=B8=88=EF=BC=81=E5=9C=\r\n=A8=E7=BC=96=E5=86=99Quoted Printable=E5=B7=A5=E5=85=B7=E5=8C=85=E3=80=82AE=\r\nSTE6N;Z5^Y5`5Y2D^D"

    @TestCase
    func encodeToString(): Unit {
        logger.debug("Testing StdQuotedPrintable encodeToString")
        let encoded = StdQuotedPrintable.encodeToString(testText.toArray())
        @Expect(encoded, testEncodedText) 
    }

    @TestCase
    func decodeFromString(): Unit {
        logger.debug("Testing StdQuotedPrintable decodeFromString")
        let decoded = StdQuotedPrintable.decodeFromString(testEncodedText)
        @Expect(String.fromUtf8(decoded), testText) 
    }

    @TestCase
    func encodeStream(): Unit {
        logger.debug("Testing StdQuotedPrintable encodeStream")
        let encoder = StdQuotedPrintable.encoder()
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
        @Expect(encoded, testEncodedText) 
    }

    @TestCase
    func decodeStream(): Unit {
        logger.debug("Testing StdQuotedPrintable decodeStream")
        let decoder = StdQuotedPrintable.decoder()
        let stream = ByteArrayStream()
        stream.write(testEncodedText.toArray())
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

