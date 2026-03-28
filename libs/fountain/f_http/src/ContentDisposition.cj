/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_http

public class ContentDisposition <: Equatable<ContentDisposition> & Equatable<Any> & Hashable & ToString {
    private static const US_ASCII = "US-ASCII"
    private static const ISO_8859_1 = "ISO-8859-1"
    private static const UTF8 = "UTF-8"
    private static let BASE64_ENCODED_PATTERN = #"=\?([0-9a-zA-Z-_]+)\?B\?([+/0-9a-zA-Z]+=*)\?="#.regex()
    private static const INVALID_HEADER_FIELD_PARAMETER_FORMAT = "Invalid header field parameter format (as defined in RFC 5987)"

    /**
     * Private constructor. See static factory methods in this class.
     */
    public ContentDisposition(
        private var `type`!: ContentDispositionType = ContentDispositionType.none,
        private var name!: String = "",
        private var filename!: String = "",
        private var charset!: ?Charset = Option<Charset>.None,
        private var size!: Int64 = -1,
        private var creationDate!: Option<DateTime> = None<DateTime>,
        private var modificationDate!: Option<DateTime> = None<DateTime>,
        private var readDate!: Option<DateTime> = None<DateTime>
    ) {}

    /**
     * Return whether the getType()  is "attachment".
     */
    public prop isAttachment: Bool {
        get() {
            this.`type`.isAttachment
        }
    }

    /**
     * Return whether the getType() is "form-data".
     */
    public prop isFormData: Bool {
        get() {
            this.`type`.isFormData
        }
    }

    /**
     * Return whether the getType() is "inline".
     */
    public prop isInline: Bool {
        get() {
            this.`type`.isInline
        }
    }

    /**
     * Return the disposition type.
     * @see isAttachment
     * @see isFormData
     * @see isInline
     */
    public func getType() {
        return this.`type`
    }
    public func setType(`type`: ContentDispositionType): ContentDisposition {
        this.`type` = `type`
        this
    }

    /**
     * Return the value of the name parameter, or empty string if not defined.
     */
    public func getName() {
        return this.name
    }
    public func setName(name: String): ContentDisposition {
        this.name = name
        this
    }

    /**
     * Return the value of the filename parameter, possibly decoded
     * from BASE64 encoding based on RFC 2047, or of the filename
     * parameter, possibly decoded as defined in the RFC 5987.
     */
    public func getFilename() {
        return this.filename
    }
    public func setFilename(filename: String): ContentDisposition {
        this.filename = filename
        this
    }

    /**
     * Return the charset defined in {@literal filename*} parameter, or {@code null} if not defined.
     */
    public func getCharset(): ?Charset {
        return this.charset
    }
    public func setCharset(charset: Charset): ContentDisposition {
        this.charset = charset
        this
    }

    /**
     * Return the value of the size parameter, or -1 if not defined.
     * <a href="https://tools.ietf.org/html/rfc6266#appendix-B">RFC 6266, Appendix B</a>,
     * to be removed in a future release.
     */
    public func getSize() {
        return this.size
    }
    public func setSize(size: Int64): ContentDisposition {
        this.size = size
        this
    }
    public func getCreationDate() {
        this.creationDate
    }
    public func setCreationDate(creationDate: DateTime) {
        this.creationDate = creationDate
    }
    public func setCreationDate(creationDate: String) {
        this.creationDate = parseRfc1123(creationDate)
    }
    public func setModificationDate(modificationDate: String) {
        this.modificationDate = parseRfc1123(modificationDate)
    }
    public func setReadDate(readDate: String) {
        this.readDate = parseRfc1123(readDate)
    }

    public func getModificationDate() {
        this.modificationDate
    }
    public func setModificationDate(modificationDate: DateTime) {
        this.modificationDate = modificationDate
    }
    public func getReadDate() {
        this.readDate
    }
    public func setReadDate(readDate: DateTime) {
        this.readDate = readDate
    }

    public operator func ==(other: Any) {
        match (other) {
            case otherCd: ContentDisposition => this == otherCd
            case _ => false
        }
    }
    private func charsetEq(other: ContentDisposition) {
        match ((this.charset, other.charset)) {
            case (Option<Charset>.None, Option<Charset>.None) => true
            case (Some(cs1), Some(cs2)) => cs1 == cs2
            case _ => false
        }
    }
    public operator func ==(other: ContentDisposition) {
        refEq(this, other) || 
        (this.`type` == other.`type` && this.name == other.name && this.filename == other.filename && charsetEq(other) &&
            this.size == other.size && this.creationDate == other.creationDate && this.modificationDate == other
            .modificationDate && this.readDate == other.readDate)
    }
    private var hash = 0
    public func hashCode(): Int64 {
        if (hash == 0) {
            hash = HashBuilder()
                .append(this.`type`)
                .append(this.name)
                .append(this.filename)
                .append(this.charset?.toString() ?? "")
                .append(this.size)
                .append(this.creationDate?.toString() ?? "")
                .append(this.modificationDate?.toString() ?? "")
                .append(this.readDate?.toString() ?? "")
                .build()
        }
        hash
    }

    /**
     * Return the header value for this content disposition as defined in RFC 6266.
     * @see parse(String)
     */
    public func toString(): String {
        let builder = StringGenerator()
        if (this.`type` != ContentDispositionType.none) {
            builder.append(this.`type`)
        }
        if (this.name != "") {
            builder.append(#"; name=""#)
            builder.append(this.name)
            builder.append(r'"')
        }
        if (this.filename != "") {
            if (this.charset.isNone() || this.charset.getOrThrow().nameEquals(US_ASCII)) {
                builder.append("; filename=\"");
                builder.append(escapeQuotationsInFilename(this.filename))
                builder.append('\"');
            } else {
                builder.append("; filename*=");
                builder.append(encodeFilename(this.filename, this.charset.getOrThrow()));
            }
        }
        if (this.size > 0) {
            builder.append("; size=")
            builder.append(this.size)
        }
        if (let Some(d) <- creationDate) {
            builder.append("; creation-date=\"")
            builder.append(rfc1123(d))
            builder.append('\"')
        }
        if (let Some(d) <- modificationDate) {
            builder.append("; modification-date=\"")
            builder.append(rfc1123(d))
            builder.append('\"')
        }
        if (let Some(d) <- readDate) {
            builder.append("; read-date=\"")
            builder.append(rfc1123(d))
            builder.append('\"')
        }
        return builder.append('\r\n\r\n').toString()
    }

    /**
     * Return a builder for a ContentDisposition of type "attachment".
     */
    public static prop attachment: ContentDisposition {
        get() {
            ContentDisposition(`type`: ContentDispositionType.attachment)
        }
    }

    /**
     * Return a builder for a {@code ContentDisposition} of type "form-data".
     */
    public static prop formData: ContentDisposition {
        get() {
            ContentDisposition(`type`: ContentDispositionType.formData)
        }
    }

    /**
     * Return a builder for a {@code ContentDisposition} of type "inline".
     */
    public static prop inline: ContentDisposition {
        get() {
            ContentDisposition(`type`: ContentDispositionType.inline)
        }
    }

    /**
     * Return an empty content disposition.
     */
    public static prop empty: ContentDisposition {
        get() {
            ContentDisposition()
        }
    }

    /**
     * Parse a Content-Disposition header value as defined in RFC 2183.
     * @param contentDisposition the Content-Disposition header value
     * @return the parsed content disposition
     * @see toString()
     */
    public static func parse(contentDisposition: String): ContentDisposition {
        let parts = tokenize(contentDisposition)
        let `type` = ContentDispositionType.parse(parts[0])
        var name = ""
        var filename = ""
        var size = -1
        var creationDate = None<DateTime>
        var modificationDate = None<DateTime>
        var readDate = None<DateTime>
        for (i in 1..parts.size) {
            let part = parts[i]
            let eqIndex = part.indexOf("=") ?? -1
            if (eqIndex != -1) {
                let attribute = part[0..eqIndex]
                let value = if (part.indexOf("\"", eqIndex + 1).isSome() && part.endsWith("\"")) {
                    part[eqIndex + 2..part.size - 1]
                } else {
                    part[eqIndex + 1..]
                }
                if (attribute == "name") {
                    name = value
                } else if (attribute == "filename*") {
                    let idx1 = value.indexOf("'") ?? -1
                    let idx2 = value.indexOf("'", idx1 + 1) ?? -1
                    let charset = Charsets.forName(value[0..idx1].trimAscii()).getOrThrow()
                    if (idx1 != -1 && idx2 != -1) {
                        filename = decodeFilename(value[idx2 + 1..], charset)
                    } else {
                        // US ASCII
                        filename = decodeFilename(value, Charsets.WINDOWS_1252)
                    }
                } else if (attribute == "filename" && (filename == "")) {
                    if (value.startsWith("=?")) {
                        let matched = BASE64_ENCODED_PATTERN.find(value, group: true)
                        match (matched) {
                            case Some(m) =>
                                let _ = m.matchString(1) //charset
                                let matched = m.matchString(2)
                                filename = String.fromUtf8(fromBase64String(matched) ?? [])
                            case _ => filename = value
                        }
                    } else {
                        filename = value
                    }
                } else if (attribute == "size") {
                    size = Int64.parse(value)
                } else if (attribute == "creation-date") {
                    try {
                        creationDate = parseRfc1123(value)
                    } catch (_) {
                        // ignore
                    }
                } else if (attribute == "modification-date") {
                    try {
                        modificationDate = parseRfc1123(value)
                    } catch (_) {
                        // ignore
                    }
                } else if (attribute == "read-date") {
                    try {
                        readDate = parseRfc1123(value)
                    } catch (_) {
                        // ignore
                    }
                }
            } else {
                throw IllegalArgumentException("Invalid content disposition format")
            }
        }
        return ContentDisposition(
            `type`: `type`,
            name: name,
            filename: filename,
            size: size,
            creationDate: creationDate,
            modificationDate: modificationDate,
            readDate: readDate
        )
    }

    private static func tokenize(headerValue: String): ArrayList<String> {
        var index = headerValue.indexOf(b';') ?? -1
        let `type` = (if (index >= 0) {
            headerValue[0..index]
        } else {
            headerValue
        }).trimAscii()
        if (`type`.isEmpty()) {
            throw IllegalArgumentException("Content-Disposition header must not be empty")
        }
        let parts = ArrayList<String>()
        parts.add(`type`.toString())
        if (index >= 0) {
            do {
                var nextIndex = index + 1
                var quoted = false
                var escaped = false
                while (nextIndex < headerValue.size) {
                    let ch = headerValue[nextIndex]
                    if (ch == b';') {
                        if (!quoted) {
                            break
                        }
                    } else if (!escaped && ch == b'"') {
                        quoted = !quoted
                    }
                    escaped = (!escaped && ch == b'\\')
                    nextIndex++
                }
                let part = headerValue[index + 1..nextIndex].trimAscii()
                if (!part.isEmpty()) {
                    parts.add(part)
                }
                index = nextIndex
            } while (index < headerValue.size)
        }
        parts
    }

    /**
     * Decode the given header field param as described in RFC 5987.
     * <p>Only the US-ASCII, UTF-8 and ISO-8859-1 charsets are supported.
     * @param filename the filename
     * @param charset the charset for the filename
     * @return the encoded header field param
     * @see <a href="https://tools.ietf.org/html/rfc5987">RFC 5987</a>
     */
    private static func decodeFilename(filename: String, charset: Charset): String {
        let value = charset.newEncoder().encode(filename)
        let baos = ByteBuffer()
        var index = 0
        while (index < value.size) {
            let b = value[index]
            if (isRFC5987AttrChar(b)) {
                baos.write(b)
                index++
            } else if (b == b'%' && index < value.size - 2) {
                let array = [Rune(value[index + 1]), Rune(value[index + 2])]
                try {
                    let byte = fromHexString(String(array)).getOrThrow()[0]
                    baos.write(byte)
                } catch (ex: Exception) {
                    throw IllegalArgException(INVALID_HEADER_FIELD_PARAMETER_FORMAT, ex)
                }
                index += 3
            } else {
                throw IllegalArgException(INVALID_HEADER_FIELD_PARAMETER_FORMAT)
            }
        }
        return charset.newDecoder().decode(baos.bytes())
    }

    private static func isRFC5987AttrChar(c: Byte): Bool {
        return (c >= b'0' && c <= b'9') || (c >= b'a' && c <= b'z') || (c >= b'A' && c <= b'Z') || c == b'!' || c == b'#' ||
            c == b'$' || c == b'&' || c == b'+' || c == b'-' || c == b'.' || c == b'^' || c == b'_' || c == b'`' || c ==
            b'|' || c == b'~'
    }

    private static func escapeQuotationsInFilename(filename: String): String {
        if ((filename.indexOf(b'"') ?? -1) == -1 && (filename.indexOf(b'\\') ?? -1) == -1) {
            return filename
        }
        var escaped = false
        let builder = StringGenerator()
        for (c in filename) {
            if (!escaped && c == b'"') {
                builder.append("\\\"")
            } else {
                builder.append(c)
            }
            escaped = (!escaped && c == b'\\')
        }

        // Remove backslash at the end.
        if (escaped) {
            builder.toString()[0..builder.size - 1]
        } else {
            builder.toString()
        }
    }

    /**
     * Encode the given header field param as describe in RFC 5987.
     * @param input the header field param
     * @param charset the charset of the header field param string,
     * only the US-ASCII, UTF-8 and ISO-8859-1 charsets are supported
     * @return the encoded header field param
     * @see <a href="https://tools.ietf.org/html/rfc5987">RFC 5987</a>
     */
    private static func encodeFilename(input: String, charset: Charset): String {
        if (!charset.nameEquals(US_ASCII)) {
            throw IllegalArgumentException("US_ASCII does not require encoding.")
        }
        let isUtf8 = charset == Charsets.UTF8
        if (!(isUtf8 || charset.nameEquals(ISO_8859_1))) {
            throw IllegalArgumentException("Only UTF-8 and ISO-8859-1 supported.")
        }
        let source = charset.newEncoder().encode(input)
        let builder = StringGenerator()
        builder.append(if (isUtf8) {
            UTF8
        } else {
            ISO_8859_1
        })
        builder.append("''")
        for (b in source) {
            if (isRFC5987AttrChar(b)) {
                builder.append(Rune(b))
            } else {
                builder.append(r'%')
                builder.append(toHexString([b]).toAsciiUpper())
            }
        }
        return builder.toString()
    }
}
