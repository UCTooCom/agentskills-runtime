package cj_mail.imap

import std.collection.*
import std.convert.*
import cj_mail.commons.*
import cj_mail.exception.*

enum ImapValue {
    | NIL
    | STRING(String)
    | NUMBER(Int64)
    | LIST (ArrayList<ImapValue>)
}

extend ImapValue <: ToString {
    public func toString(): String {
        match (this) {
            case NIL =>
                "NIL"
            case STRING(str) =>
                "\"${str}\""
            case NUMBER(num) =>
                num.toString()
            case LIST(list) =>
                var builder = StringBuilder()
                builder.append("(")
                for (value in list) {
                    builder.append(value.toString())
                    builder.append(" ")
                }
                builder.append(")")
                builder.toString()
        }
    }
}

func parseThisItem(reader: StreamReader): ImapValue {
    let builder = StringBuilder()
    var rune = reader.readRune().getOrThrow({=>MailConnectExcption("Connect has been eof")})
    builder.append(rune)
    match (rune) {
        case r"(" => 
            return parseList(reader)
        case r"\"" =>
            return parseString(reader)
        case "N" =>
            return parseNil(builder, reader)
        case _ =>
            if (rune >= r'0' && rune <= r'9') {
                let (value, end) = parseNumber(builder, reader)
                if (end) {
                    throw MailContentParseException("Invalid item todo : end")
                }
                return value
            }
            throw MailContentParseException("Invalid item : ${rune}")
    }
}

func parseList(reader: StreamReader): ImapValue {
    let values = ArrayList<ImapValue>()
    while (true) {
        let rune = reader.readRune().getOrThrow({=>MailConnectExcption("Connect has been eof")})
        match (rune) {
            case " " =>
                continue
            case ")" =>
                break
            case r"(" =>
                values.add(parseList(reader))
            case r"\"" =>
                values.add(parseString(reader))
            case "N" =>
                values.add(parseNil(StringBuilder("N"), reader))
            case _ =>
                if (rune >= r'0' && rune <= r'9') {
                    let (value, end) = parseNumber(StringBuilder(rune), reader)
                    values.add(value)
                    if (end) {
                        break
                    }
                } else {
                    throw MailContentParseException("Invalid parse : ${rune}")
                }
        }
    }
    ImapValue.LIST(values)
}

func parseNil(builder: StringBuilder, reader: StreamReader): ImapValue {
    for (_ in 0..2) {
        let rune = reader.readRune().getOrThrow({=>MailConnectExcption("Connect has been eof")})
        builder.append(rune)
    }
    if (builder.toString() == "NIL") {
        return ImapValue.NIL
    } else {
        throw MailContentParseException("Invalid NIL")
    }
}

func parseString(reader: StreamReader): ImapValue {
    let cBuilder = StringBuilder()
    var inEscape = false
    while (true) {
        let rune = reader.readRune().getOrThrow({=>MailConnectExcption("Connect has been eof")})
        if (inEscape) {
            inEscape = false
            cBuilder.append(rune)
        } else if (rune == r'\\') {
            inEscape = true
        } else if (rune == r'"') {
            break
        } else {
            cBuilder.append(rune)
        }
    }
    return ImapValue.STRING(cBuilder.toString())
}

func parseNumber(builder: StringBuilder, reader: StreamReader): (ImapValue, Bool) {
    var end = false
    while (true) {
        let rune = reader.readRune().getOrThrow({=>MailConnectExcption("Connect has been eof")})
        if (rune >= r'0' && rune <= r'9') {
            continue
        } else if (rune == r' ') {
            break
        } else if (rune == r')') {
            end = true
            break
        } else {
            throw MailContentParseException("Invalid NUMBER : ${rune}")
        }
    }
    return (ImapValue.NUMBER(Int64.parse(builder.toString())), end)
}

func parseImapAddress(list: ArrayList<ImapValue>): MailAddress {
    if (list.size < 4) {
        throw MailContentParseException("Invalid fetch ENVELOPE")
    }
    var name = getImapValueString(list[0])
    var mailId = getImapValueString(list[2])
    var mailDomain = getImapValueString(list[3])
    MailAddress(decodeSubject(name), "${mailId}@${mailDomain}")
}

func getImapValueString(value: ImapValue): String {
    match (value) {
        case ImapValue.STRING(str) =>
            str
        case _ =>
            ""
    }
}
