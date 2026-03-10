/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2024. All rights reserved.
 */

package commonmark4cj.commonmark

/* Character range of ascii type：0-127*/
public type AsciiByte = Byte

public class Escaping {
    public static let ESCAPABLE: String = "[!\"#$%&\'()*+,./:;<=>?@\\[\\\\\\]^_`{|}~-]"

    public static let ENTITY: String = "&(?:#x[a-f0-9]{1,6}|#[0-9]{1,7}|[a-z][a-z0-9]{1,31});"

    private static let BACKSLASH_OR_AMP = Regex(#"[\\&]"#)

    private static let ENTITY_OR_ESCAPED_CHAR = Regex(
        "\\\\" + ESCAPABLE + '|'.toString() + ENTITY,
        IgnoreCase
    )

    // From RFC 3986 (see "reserved", "unreserved") except don't escape '[' or ']' to be compatible with JS encodeURI
    private static let ESCAPE_IN_URI = Regex("(%[a-fA-F0-9]{0,2}|[^:/?#@!$&'()*+,;=a-zA-Z0-9\\-._~])")

    private static let WHITESPACE = Regex("[ \t\r\n]+")

    static let amp: Array<Byte> = "&amp;".toArray()
    static let lt: Array<Byte> = "&lt;".toArray()
    static let gt: Array<Byte> = "&gt;".toArray()
    static let quot: Array<Byte> = "&quot;".toArray()

    public static func escapeHtml(input: String): String {
        // Avoid building a new string in the majority of cases (nothing to escape)
        let arr: Array<Byte> = unsafe { input.rawData() }
        var sb: ?ArrayList<Byte> = None
        var i: Int64 = 0
        while (i < arr.size) {
            let replacement: Array<Byte> = match (arr[i]) {
                case '&' => amp
                case '<' => lt
                case '>' => gt
                case '\"' => quot
                case byte =>
                    if (let Some(s) <- sb) {
                        s.add(byte)
                    }
                    i++
                    continue
            }
            if (sb.isNone()) {
                sb = ArrayList<Byte>(arr.size + 16)
                sb?.add(all: arr[..i])
            }
            sb?.add(all: replacement)
            i++
        }
        if (let Some(s) <- sb) {
            return unsafe { String.fromUtf8Unchecked(s.getRawArray()[..s.size]) }
        } else {
            return input
        }
    }

    /**
     * Replace entities and backslash escapes with literal characters.
     */
    public static func unescapeString(s: String): String {
        // match (BACKSLASH_OR_AMP.find(s)) {
        //     case None => return s
        //     case _ => return replaceAll(ENTITY_OR_ESCAPED_CHAR, s, UnescapeReplacer())
        // }
        for (b in s) {
            if (b == b'\\' || b == b'&') {
                return replaceAll(ENTITY_OR_ESCAPED_CHAR, s, UnescapeReplacer())
            }
        }
        return s
    }

    public static func percentEncodeUrl(s: String): String {
        let str = s |> map<Byte, ToString> {
            b => if (b < 128) {
                String(Rune(b))
            } else {
                "%${b.format("X")}"
            }
        } |> collectString(delimiter: "")
        return replaceAll(ESCAPE_IN_URI, str, UriReplacer())
    }

    public static func normalizeReference(input: String): String {
        // Strip '[' and ']'
        let stripped: String = input[1..input.size - 1]
        return normalizeLabelContent(stripped)
    }

    protected static func normalizeLabelContent(input: String): String {
        let trimmed: String = input.trimAscii()
        // let lowercase: String = trimmed.toAsciiLower()
        // return WHITESPACE.replaceAll(lowercase, " ")
        let arr = trimmed.toArray()
        for (i in 0..arr.size) {
            if (arr[i] >= b'A' && arr[i] <= b'Z') {
                arr[i] == arr[i] + 0x20
            } else if (arr[i] == b'\r' || arr[i] == b'\n' || arr[i] == b'\t') {
                arr[i] == b' '
            }
        }
        return unsafe { String.fromUtf8Unchecked(arr) }
    }

    private static func replaceAll(p: Regex, s: String, replacer: Replacer): String {
        let matcher: Array<MatchData> = p.findAll(s)

        if (matcher.size < 1) {
            return s
        }

        var sb: StringBuilder = StringBuilder(s.size + 16)
        var lastEnd: Int64 = 0

        var pos: Position
        var i: Int64 = 0
        while (i < matcher.size) {
            pos = matcher[i].matchPosition()
            sb.append(s[lastEnd..pos.start])
            replacer.replace(matcher[i].matchString(), sb)
            lastEnd = pos.end
            i++
        }

        if (lastEnd != s.size) {
            sb.append(s[lastEnd..])
        }
        return sb.toString()
    }
}

class UnescapeReplacer <: Replacer {
    public func replace(input: String, sb: StringBuilder): Unit {
        if (input[0] == b'\\') {
            sb.append(input[1..])
        } else {
            sb.append(Html5Entities.entityToString(input))
        }
    }
}

class UriReplacer <: Replacer {
    private static let HEX_DIGITS: Array<Rune> = [r'0', r'1', r'2', r'3', r'4', r'5', r'6', r'7', r'8', r'9', r'A', r'B',
        r'C', r'D', r'E', r'F']

    public func replace(input: String, sb: StringBuilder): Unit {
        if (input[0] == b'%') {
            if (input.size == 3) {
                // Already percent-encoded, preserve
                sb.append(input)
            } else {
                // %25 is the percent-encoding for %
                sb.append("%25")
                sb.append(input[1..])
            }
        } else {
            for (b in input) {
                sb.append('%')
                sb.append(HEX_DIGITS[Int64((b >> 4) & 0xF)])
                sb.append(HEX_DIGITS[Int64(b & 0xF)])
            }
        }
    }
}

public interface Replacer {
    func replace(input: String, sb: StringBuilder): Unit
}

public class Html5Entities {
    private static let NAMED_CHARACTER_REFERENCES: HashMap<String, String> = readEntities()
    private static let NUMERIC_PATTERN = Regex("^&#[Xx]?")

    public static func entityToString(input: String): String {
        let md: ?MatchData = NUMERIC_PATTERN.find(input)
        if (md.isSome()) {
            try {
                let codePointString: String = input[md.getOrThrow().matchPosition().end..input.size - 1]
                let codePoint: Int64
                if (md.getOrThrow().matchPosition().end == 2) {
                    codePoint = Int64.parse(codePointString)
                } else {
                    codePoint = Int64.parse("0x" + codePointString)
                }
                if (codePoint == 0) {
                    return "\u{FFFD}"
                }

                return String(Rune(codePoint))
            } catch (e: IllegalArgumentException) {
                return "\u{FFFD}"
            }
        } else {
            let name: String = input[1..input.size - 1]
            let s: ?String = NAMED_CHARACTER_REFERENCES.get(name)
            return s ?? input
        }
    }

    public static func readEntities(): HashMap<String, String> {
        return entities_dict
    }
}

public class LinkScanner {

    /**
     * Attempt to scan the contents of a link label (inside the brackets), returning the position after the content or
     * -1. The returned position can either be the closing {@code ]}, or the end of the line if the label continues on
     * the next line.
     */
    public static func scanLinkLabelContent(input: String, start: Int64): Int64 {
        var i: Int64 = start
        while (i < input.size) {
            let c = input[i]
            match (c) {
                case '\\' =>
                    if (Parsing.isEscapable(input, i + 1)) {
                        i++
                    }
                case ']' => return i
                case '[' =>
                    // spec: Unescaped square bracket characters are not allowed inside the opening and closing
                    // square brackets of link labels.
                    return -1
                case _ => ()
            }
            i++
        }
        return input.size
    }

    /**
     * Attempt to scan a link destination, returning the position after the destination or -1.
     */
    public static func scanLinkDestination(input: String, start: Int64): Int64 {
        if (start >= input.size) {
            return -1
        }
        if (input[start] == b'<') {
            var i: Int64 = start + 1
            while (i < input.size) {
                let c = input[i]
                match (c) {
                    case '\\' =>
                        if (Parsing.isEscapable(input, i + 1)) {
                            i++
                        }
                    case '\n' | '<' => return -1
                    case '>' => return i + 1
                    case _ => ()
                }
                i++
            }
            return -1
        } else {
            return scanLinkDestinationWithBalancedParens(input, start)
        }
    }

    public static func scanLinkTitle(input: String, start: Int64): Int64 {
        if (start >= input.size) {
            return -1
        }

        var endDelimiterByte: Byte
        match (input[start]) {
            case '"' => endDelimiterByte = '"'
            case '\'' => endDelimiterByte = '\''
            case '(' => endDelimiterByte = ')'
            case _ => return -1
        }
        let afterContent: Int64 = scanLinkTitleContent(input, start + 1, endDelimiterByte)
        if (afterContent == -1) {
            return -1
        }

        if (afterContent >= input.size || input[afterContent] != endDelimiterByte) {
            // missing or wrong end delimiter
            return -1
        }

        return afterContent + 1
    }

    /*
     * simple bitmap
     */
    public static func scanLinkTitleContent(input: String, start: Int64, endDelimiter: Byte): Int64 {
        var i: Int64 = start
        while (i < input.size) {
            let c = input[i]
            if (c == b'\\' && Parsing.isEscapable(input, i + 1)) {
                i++
            } else if (c == endDelimiter) {
                return i
            } else if (endDelimiter == b')' && c == b'(') {
                // unescaped '(' in title within parens is invalid
                return -1
            }
            i++
        }
        return input.size
    }

    // spec: a nonempty sequence of characters that does not start with <, does not include ASCII space or control
    // characters, and includes parentheses only if (a) they are backslash-escaped or (b) they are part of a balanced
    // pair of unescaped parentheses
    private static func scanLinkDestinationWithBalancedParens(input: String, start: Int64): Int64 {
        var parens: Int64 = 0
        var i: Int64 = start
        while (i < input.size) {
            let c = input[i]
            match (c) {
                case '\0' | ' ' =>
                    if (i != start) {
                        return i
                    } else {
                        return -1
                    }
                case '\\' =>
                    if (Parsing.isEscapable(input, i + 1)) {
                        i++
                    }
                case '(' =>
                    parens++
                    // Limit to 32 nested parens for pathological cases
                    if (parens > 32) {
                        return -1
                    }
                case ')' =>
                    if (parens == 0) {
                        return i
                    } else {
                        parens--
                    }
                case _ =>
                    let (char, charSize) = Rune.fromUtf8(unsafe { input.rawData() }, i)
                    // or control character
                    if (charSize == 1 && isISOControl(char)) {
                        if (i != start) {
                            return i
                        } else {
                            return -1
                        }
                    } else {
                        i += charSize
                        continue
                    }
            }
            i++
        }
        return input.size
    }
    private static func isISOControl(codePoint: Rune): Bool {
        let u32 = UInt32(codePoint)
        return u32 <= 0x9F && (u32 >= 0x7F || (u32 >> 5 == 0x00))
    }
}

public class Parsing {
    private static let bytes: Array<Byte> = [b'!', b'"', b'#', b'$', b'%', b'&', b'\'', b'(', b')', b'*', b'+', b',',
        b'-', b'.', b'/', b':', b';', b'<', b'=', b'>', b'?', b'@', b'[', b'\\', b']', b'^', b'_', b'`', b'{', b'|',
        b'}', b'~']
    private static let TAGNAME: String = "[A-Za-z][A-Za-z0-9-]*"
    private static let ATTRIBUTENAME: String = "[a-zA-Z_:][a-zA-Z0-9:._-]*"
    private static let UNQUOTEDVALUE: String = "[^\"'=<>`\\x00-\\x20]+"
    private static let SINGLEQUOTEDVALUE: String = "'[^']*'"
    private static let DOUBLEQUOTEDVALUE: String = "\"[^\"]*\""
    private static let ATTRIBUTEVALUE: String = "(?:" + UNQUOTEDVALUE + "|" + SINGLEQUOTEDVALUE + "|" + DOUBLEQUOTEDVALUE +
        ")"
    private static let ATTRIBUTEVALUESPEC: String = "(?:" + "\\s*=" + "\\s*" + ATTRIBUTEVALUE + ")"
    private static let ATTRIBUTE: String = "(?:" + "\\s+" + ATTRIBUTENAME + ATTRIBUTEVALUESPEC + "?)"

    public static let OPENTAG: String = "<" + TAGNAME + ATTRIBUTE + "*" + "\\s*/?>"
    public static let CLOSETAG: String = "</" + TAGNAME + "\\s*[>]"

    public static let CODE_BLOCK_INDENT: Int64 = 4

    public static func columnsToNextTabStop(column: Int64): Int64 {
        // Tab stop is 4
        return 4 - (column % 4)
    }

    /**
     * Byte is ascii
     */
    public static func find(c: Byte, s: String, startIndex: Int64): Int64 {
        let length: Int64 = s.size
        for (i in startIndex..length) {
            if (s[i] == c) {
                return i
            }
        }
        return -1
    }

    public static func findLineBreak(s: String, startIndex: Int64): Int64 {
        let length: Int64 = s.size
        var i = startIndex
        while (i < length) {
            match (s[i]) {
                case '\n' | '\r' => return i
                case _ => ()
            }
            i++
        }
        return -1
    }

    public static func isBlank(s: String): Bool {
        return findNonSpace(s, 0) == -1
    }

    public static func hasNonSpace(s: String): Bool {
        let length: Int64 = s.size
        let skipped: Int64 = skip(b' ', s, 0, length)
        return skipped != length
    }

    public static func isLetter(s: String, index: Int64): Bool {
        return s[index].isAsciiLetter()
    }

    public static func isSpaceOrTab(s: String, index: Int64): Bool {
        if (index < s.size) {
            match (s[index]) {
                case ' ' | '\t' => return true
                case _ => ()
            }
        }
        return false
    }

    public static func isEscapable(s: String, index: Int64): Bool {
        if (index < s.size) {
            if (bytes.contains(s[index])) {
                return true
            }
        }
        return false
    }

    public static func skip(skip: Byte, s: String, startIndex: Int64, endIndex: Int64): Int64 {
        for (i in startIndex..endIndex) {
            if (s[i] != skip) {
                return i
            }
        }
        return endIndex
    }

    public static func skipBackwards(skip: Byte, s: String, startIndex: Int64, lastIndex: Int64): Int64 {
        for (i in startIndex..lastIndex : -1) {
            if (s[i] != skip) {
                return i
            }
        }
        return lastIndex - 1
    }

    public static func skipSpaceTab(s: String, startIndex: Int64, endIndex: Int64): Int64 {
        for (i in startIndex..endIndex) {
            match (s[i]) {
                case ' ' | '\t' => continue
                case _ => return i
            }
        }
        return endIndex
    }

    public static func skipSpaceTabBackwards(s: String, startIndex: Int64, lastIndex: Int64): Int64 {
        for (i in startIndex..lastIndex : -1) {
            match (s[i]) {
                case ' ' | '\t' => continue
                case _ => return i
            }
        }
        return lastIndex - 1
    }

    private static func findNonSpace(s: String, startIndex: Int64): Int64 {
        let length: Int64 = s.size
        for (i in startIndex..length) {
            match (s[i]) {
                case ' ' | '\t' | '\n' | '\u{0B}' | '\f' | '\r' => continue
                case _ => return i
            }
        }
        return -1
    }
}
