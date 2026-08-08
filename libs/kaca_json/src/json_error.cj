package kaca_json

import std.collection.*

public enum JsonErrorCode {
    | UnexpectedToken
    | UnexpectedEndOfInput
    | InvalidNumber
    | InvalidString
    | InvalidEscapeSequence
    | InvalidUnicodeEscape
    | InvalidSurrogatePair
    | UnterminatedString
    | UnterminatedObject
    | UnterminatedArray
    | ExpectedToken
    | DuplicateKey
    | TrailingComma
    | LeadingZero
    | InvalidControlCharacter
}

public class JsonError <: Exception {
    public let code: JsonErrorCode
    public let errMsg: String
    public let line: Int64
    public let column: Int64
    public let context: String
    
    public JsonError(code: JsonErrorCode, errMsg: String, line: Int64, column: Int64, context: String) {
        this.code = code
        this.errMsg = errMsg
        this.line = line
        this.column = column
        this.context = context
    }
    
    public func toString(): String {
        let codeStr = errorCodeToString(code)
        let location = "at line ${line}, column ${column}"
        "${codeStr}: ${errMsg} ${location}\n${context}"
    }
}

private func errorCodeToString(code: JsonErrorCode): String {
    match (code) {
        case JsonErrorCode.UnexpectedToken => "Unexpected token"
        case JsonErrorCode.UnexpectedEndOfInput => "Unexpected end of input"
        case JsonErrorCode.InvalidNumber => "Invalid number"
        case JsonErrorCode.InvalidString => "Invalid string"
        case JsonErrorCode.InvalidEscapeSequence => "Invalid escape sequence"
        case JsonErrorCode.InvalidUnicodeEscape => "Invalid unicode escape"
        case JsonErrorCode.InvalidSurrogatePair => "Invalid surrogate pair"
        case JsonErrorCode.UnterminatedString => "Unterminated string"
        case JsonErrorCode.UnterminatedObject => "Unterminated object"
        case JsonErrorCode.UnterminatedArray => "Unterminated array"
        case JsonErrorCode.ExpectedToken => "Expected token"
        case JsonErrorCode.DuplicateKey => "Duplicate key"
        case JsonErrorCode.TrailingComma => "Trailing comma"
        case JsonErrorCode.LeadingZero => "Leading zero"
        case JsonErrorCode.InvalidControlCharacter => "Invalid control character"
    }
}

public func lexerError(errMsg: String, line: Int64, column: Int64): JsonError {
    JsonError(
        JsonErrorCode.UnexpectedToken,
        errMsg,
        line,
        column,
        ""
    )
}

public func parseError(errMsg: String, line: Int64, column: Int64): JsonError {
    JsonError(
        JsonErrorCode.UnexpectedToken,
        errMsg,
        line,
        column,
        ""
    )
}

public func numberError(errMsg: String, pos: Int64): JsonError {
    JsonError(
        JsonErrorCode.InvalidNumber,
        errMsg,
        1,
        pos + 1,
        ""
    )
}

