/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights resvered.
 */
package commonmark4cj.commonmark

public class LinkScannerV2 {
    /**
     * Attempt to scan the contents of a link label (inside the brackets), stopping after the content or returning false.
     * The stopped position can bei either the closing {@code ]}, or the end of the line if the label continues on
     * the next line.
     */
    public static func scanLinkLabelContent(scanner: Scanner): Bool {
        while (scanner.hasNext()) {
            match (scanner.peek()) {
                case '\\' =>
                    scanner.next()
                    if (isEscapable(scanner.peek())) {
                        scanner.next()
                    }
                case ']' => 
                return true
                case '[' =>
                    // spec: Unescaped square bracket characters are not allowed inside the opening and closing
                    // square brackets of link labels.
                    return false
                case _ => 
                scanner.next()
            }
        }
        return true
    }

    /**
     * Attempt to scan a link destination, stopping after the destination or returning false.
     */
    public static func scanLinkDestination(scanner: Scanner): Bool {
        if (!scanner.hasNext()) {
            return false
        }

        if (scanner.next('<')) {
            while (scanner.hasNext()) {
                match (scanner.peek()) {
                    case '\\' =>
                        scanner.next()
                        if (isEscapable(scanner.peek())) {
                            scanner.next()
                        }
                    case '\n' | '<' => return false
                    case '>' =>
                        scanner.next()
                        return true
                    case _ => scanner.next()
                }
            }
            return false
        } else {
            return scanLinkDestinationWithBalancedParens(scanner)
        }
    }

    public static func scanLinkTitle(scanner: Scanner): Bool {
        if (!scanner.hasNext()) {
            return false
        }

        let endDelimiter: Rune = match (scanner.peek()) {
            case '"' => r'"'
            case '\'' => r'\''
            case '(' => r')'
            case _ => return false
        }
        scanner.next()

        if (!scanLinkTitleContent(scanner, endDelimiter)) {
            return false
        }
        if (!scanner.hasNext()) {
            return false
        }
        scanner.next()
        return true
    }

    public static func scanLinkTitleContent(scanner: Scanner, endDelimiter: Rune): Bool {
        while (scanner.hasNext()) {
            let c: Rune = scanner.peek()
            if (c == r'\\') {
                scanner.next()
                if (isEscapable(scanner.peek())) {
                    scanner.next()
                }
            } else if (c == endDelimiter) {
                return true
            } else if (endDelimiter == r')' && c == r'(') {
                // unescaped '(' in title within parens is invalid
                return false
            } else {
                scanner.next()
            }
        }
        return true
    }

    // spec: a nonempty sequence of characters that does not start with <, does not include ASCII space or control
    // characters, and includes parentheses only if (a) they are backslash-escaped or (b) they are part of a balanced
    // pair of unescaped parentheses
    private static func scanLinkDestinationWithBalancedParens(scanner: Scanner): Bool {
        var parens = 0
        var empty = true
        while (scanner.hasNext()) {
            let c = scanner.peek()
            match (c) {
                case ' ' => return !empty
                case '\\' =>
                    scanner.next()
                    if (isEscapable(scanner.peek())) {
                        scanner.next()
                    }
                case '(' =>
                    parens++
                    // Limit to 32 nested parens for pathological cases
                    if (parens > 32) {
                        return false
                    }
                    scanner.next()
                case ')' =>
                    if (parens == 0) {
                        return true
                    } else {
                        parens--
                    }
                    scanner.next()
                case _ =>
                    // or control character
                    if (isISOControl(c)) {
                        return !empty
                    }
                    scanner.next()
            }
            empty = false
        }
        return true
    }

    private static func isEscapable(c: Rune): Bool {
        match (c) {
            case '!' | '"' | '#' | '$' | '%' | '&' | '\'' | '(' | ')' | '*' | '+' | ',' | '-' | '.' | '/' | ':' | ';' | '<' | '=' | '>' | '?' | '@' | '[' | '\\' | ']' | '^' | '_' | '`' | '{' | '|' | '}' | '~' => return true
            case _ => return false
        }
    }

    private static func isISOControl(codePoint: Rune): Bool {
        let u32 = UInt32(codePoint)
        return u32 <= 0x9F && (u32 >= 0x7F || (u32 >> 5 == 0x00))
    }
}
