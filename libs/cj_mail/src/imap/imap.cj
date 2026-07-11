package cj_mail.imap

import cj_mail.commons.*
import cj_mail.log.*
import stdx.net.tls.*
import std.net.*
import std.regex.*
import std.io.*
import std.collection.*
import cj_mail.exception.*
import std.convert.*

private let fetchRegex = Regex("^\\* \\d+ FETCH [\\S\\s]+ \\{(\\d+)\\}$")
private let defaultTlsPort: UInt16 = 993

public class Imap <: Resource{

    private var cmdIdx = 0
    public var connection: MailConnection
    // private var inDeflate = false

    public init(connection: MailConnection) {
        this.connection = connection
        readCommand(None) // Server Hello
    }

    public init(socket: StreamingSocket) {
        this(mailConnection(socket))
    }

    public init(host: String, port: UInt16) {
        this(defaultTlsConnect(host, port))
    }

    public init(host: String) {
        this(host, defaultTlsPort)
    }
    
    public func close() {
            connection.disconnect()
    }

    public func isClosed(): Bool {
        connection.isClosed()
    }

    public func nextCmdIdx() {
        cmdIdx += 1
        cmdIdx %= 1000
        if (cmdIdx == 0) {
            cmdIdx = 1
        }
        var str = cmdIdx.toString()
        while (str.size < 3) {
            str = "0" + str
        }
        return "A${str}"
    }

    public func readCommand(cmdIdx: Option<String>): String {
        let reader = this.connection.reader
        match (cmdIdx) {
            case Some(cmdIdx)=>
                let builder = StringBuilder()
                while(true) {
                    let line = reader.readln().getOrThrow({=>MailConnectExcption("Connect has been eof")})
                    cjMailLogger.trace("S: ${line}", ("package", "cj_mail.smtp"))
                    builder.append(line)
                    builder.append("\r\n")
                    if (line.startsWith("* ")) {
                        if (line.endsWith("}")) {
                             match(regexGroups(fetchRegex, line)) {
                                    case Some(s) =>
                                        let len = Int64.parse(s[1])
                                        cjMailLogger.trace(".. for read Rune * ${len} from server ..", ("package", "cj_mail.smtp"))
                                        builder.append(String.fromUtf8(reader.readSize(len)))
                                        let left = reader.readln().getOrThrow({=>MailConnectExcption("Connect has been eof")})
                                        cjMailLogger.trace(".. line left : ${left} ..", ("package", "cj_mail.smtp"))
                                        builder.append(left)
                                        builder.append("\r\n")
                                    case None => ()
                             }
                        }
                    } else if (line.startsWith("${cmdIdx} ")) {
                        if (line.startsWith("${cmdIdx} OK ")) {
                            return builder.toString()
                        } else {
                            throw ImapException(line)
                        }
                    } else {
                        throw MailContentParseException("Invalid response : ${line}");
                    }
                }
                throw Exception("Unreachable")
            case None=>
                    let line = reader.readln().getOrThrow({=>MailConnectExcption("Connect has been eof")})
                    cjMailLogger.trace("S: ${line}", ("package", "cj_mail.smtp"))
                    return line
        }
    }

   public func writeCommand(command: String) {
        let writer = this.connection.writer
        cjMailLogger.trace("C: ${command}", ("package", "cj_mail.smtp"))
        writer.write(command)
        writer.write("\r\n")
        writer.flush()
    }

    public func login(username: String, password: String) {
        let idx = nextCmdIdx();
        writeCommand("${idx} LOGIN ${username} ${password}")
        readCommand(idx)
    }

    public func select(mailbox: String): MailboxState {
        let idx = nextCmdIdx();
        writeCommand("${idx} SELECT \"${mailbox}\"")
        parseMailBoxState(readCommand(idx))
    }

    public func examine(mailbox: String): MailboxState {
        let idx = nextCmdIdx();
        writeCommand("${idx} EXAMINE \"${mailbox}\"")
        parseMailBoxState(readCommand(idx))
    }

    public func search(criteria: String): ArrayList<Int64> {
        let idx = nextCmdIdx();
        var command = "${idx} SEARCH \"${escapingDoubleQuote(criteria)}\""
        writeCommand(command)
        let result = ArrayList<Int64>();
        for(line in  readCommand(idx).split("\r\n")) {
            if (line.startsWith("* SEARCH ")) {
                for (str in line.split(" ")[2..]) {
                    if (str != "*") {
                        result.add(Int64.parse(str))
                    }
                }
            }
        }
        result
    }

    public func fetch(sequenceSet: Option<String>, dataItems: String, withUid: Bool): (String, String) {
        let idx = nextCmdIdx()
        let sequenceSetValue = match (sequenceSet) {
            case Some(value) => value
            case _ => "1:*" 
        }
        let uidStr = if (withUid) {
            "UID "
        } else {
            ""
        }
        let command = "${idx} ${uidStr}FETCH ${sequenceSetValue} ${dataItems}"
        writeCommand(command)
        (idx, readCommand(idx))
    }

    public func fetchFullParse(sequenceSet: Option<String>, withUid: Bool): ArrayList<ImapReceiveMail> {
        let mails = ArrayList<(Int64, ReceiveMail)>()
        let (idx, response) = fetch(sequenceSet, "(UID FLAGS INTERNALDATE RFC822.SIZE ENVELOPE BODY BODY[TEXT])", withUid)
        parseImapMailResponses(idx, response, skipHeaders: true)
    }

    public func fetchFullParse(sequenceSet: Option<String>): ArrayList<ImapReceiveMail> {
        fetchFullParse(sequenceSet, false)
    }

    public func fetchFullParse(): ArrayList<ImapReceiveMail> {
        fetchFullParse(None)
    }

    public func fetchFullTextBody(sequenceSet: Option<String>, withUid: Bool): ArrayList<ImapReceiveMail> {
        let mails = ArrayList<(Int64, ReceiveMail)>()
        let (idx, response) = fetch(sequenceSet, "(UID FLAGS INTERNALDATE RFC822.SIZE ENVELOPE BODY BODY[TEXT])", withUid)
        parseImapMailResponses(idx, response, skipHeaders: true, textBody: true)
    }

    public func fetchFullTextBody(sequenceSet: Option<String>): ArrayList<ImapReceiveMail> {
        fetchFullTextBody(sequenceSet, false)
    }

    public func fetchFullTextBody(): ArrayList<ImapReceiveMail> {
        fetchFullTextBody(None)
    }

    public func fetchInfo(sequenceSet: Option<String>, withUid: Bool): ArrayList<ImapReceiveMail> {
        let (idx, response) = fetch(
            sequenceSet, 
            "(UID RFC822.SIZE FLAGS BODY.PEEK[HEADER.FIELDS (From To Cc Bcc Subject Date Message-ID Content-Type)])",
            withUid
        )
        parseImapMailResponses(idx, response)
    }

    public func fetchInfo(sequenceSet: Option<String>): ArrayList<ImapReceiveMail> {
        fetchInfo(sequenceSet, false)
    }

    public func fetchInfo(): ArrayList<ImapReceiveMail> {
        fetchInfo(None)
    }

    public func fetchFlags(sequenceSet: Option<String>, withUid: Bool): ArrayList<ImapReceiveMail> {
        let (idx, response) = fetch(sequenceSet, "(UID FLAGS)", withUid)
        parseImapMailResponses(idx, response)
    }

    public func store(
        sequenceSet: Option<String>,
        storeType: StoreType,
        flags: ArrayList<String>,
        withUid: Bool
    ): ArrayList<ImapReceiveMail> {
        let idx = nextCmdIdx()
        let sequenceSetValue = match (sequenceSet) {
            case Some(value) => value
            case _ => "1:*" 
        }
        let uidStr = if (withUid) {
            "UID "
        } else {
            ""
        }
        let flagsCmd = StringBuilder()
        for (flag in flags) {
            if (flagsCmd.size > 0) {
                flagsCmd.append(" ")
            }
            flagsCmd.append("${flag}")
        }
        let command = "${idx} ${uidStr}STORE ${sequenceSetValue} ${storeType} (${flagsCmd})"
        writeCommand(command)
        parseImapMailResponses(idx, readCommand(idx))
    }

    public func move(sequenceSet: Option<String>, mailboxName: String, withUid: Bool) {
        let idx = nextCmdIdx()
        let sequenceSetValue = match (sequenceSet) {
            case Some(value) => value
            case _ => "1:*" 
        }
        let uidStr = if (withUid) {
            "UID "
        } else {
            ""
        }
        let command = "${idx} ${uidStr}MOVE ${sequenceSetValue} \"${escapingDoubleQuote(mailboxName)}\""
        writeCommand(command)
        readCommand(idx)
    }

    public func list(referenceName: String, mailboxName: String): String {
        let idx = nextCmdIdx();
        writeCommand("${idx} LIST \"${escapingDoubleQuote(referenceName)}\" \"${escapingDoubleQuote(mailboxName)}\"")
        readCommand(idx)
    }

    public func id(properties: List<(String, String)>) {
        let idx = nextCmdIdx();
        let propertiesStr = StringBuilder()
        for (property in properties) {
            if (propertiesStr.size > 0) {
                propertiesStr.append(" ")
            }
            propertiesStr.append("${property[0]} \"${escapingDoubleQuote(property[1])}\"")
        }
        writeCommand("${idx} ID (${propertiesStr})")
        readCommand(idx)
    }

    public func quit() {
        let idx = nextCmdIdx();
        writeCommand("${idx} LOGOUT")
        readCommand(idx)
    }

    // public func deflate() {
    //     if (inDeflate) {
    //         throw MailConnectExcption("Already in deflate mode")
    //     }
    //     let idx = nextCmdIdx();
    //     writeCommand("${idx} COMPRESS DEFLATE")
    //     readCommand(idx)
    //     let conn = this.connection.getOrThrow({=>MailConnectExcption("Not connected")})
    //     conn.reader.deflate()
    //     conn.writer.deflate()
    //     inDeflate = true
    // }

}

private func escapingDoubleQuote(str: String): String {
    str.replace("\"", "\\\"")
}

private func parseImapMailResponses(
    idx: String, response: String,
    skipHeaders!: Bool = false, textBody!: Bool = false
): ArrayList<ImapReceiveMail> {
        let reader = StreamReader(ByteBuffer(response.toArray()))
        let mails = ArrayList<ImapReceiveMail>()
        while(true) {
            let line = reader.readln().getOrThrow({=>MailContentParseException()})
            if (line.startsWith("* ")) {
                mails.add(parseImapMail(line, reader, skipHeaders: skipHeaders, textBody: textBody))
            } else if (line.startsWith("${idx} ")) {
                break
            } else {
                throw MailContentParseException(
                    "not match email", line
                )
            }
        }
        mails
}

private func parseImapMail(
    line: String, reader: StreamReader,
    skipHeaders!: Bool = false, textBody!: Bool = false
): ImapReceiveMail {
    var lineReader = StreamReader(ByteBuffer(line.trimAscii().toArray()))
    let mail = ImapReceiveMail()
    if (lineReader.readRune().getOrThrow({=>MailContentParseException()}) != r"*") {
        throw MailContentParseException()
    }
    if (lineReader.readRune().getOrThrow({=>MailContentParseException()}) != r" ") {
        throw MailContentParseException()
    }
    let (idx, endListByIdx) = imapReaderNumber(lineReader)
    if (endListByIdx) {
        throw MailContentParseException()
    }
    mail.idx = idx
    var imapSetContentType = ""
    var imapSetContentTransferEncoding = ""
    matchRunes("FETCH (", lineReader)
    while (true) {
        let name = imapReadItemName(lineReader)
        if (name == ")") {
            break
        } else if (name == "UID") {
            let (uid, endList) = imapReaderNumber(lineReader)
            mail.uid = uid
            if (endList) {
                break
            }
        } else if (name == "RFC822.SIZE") {
            let (size, endListBySize) = imapReaderNumber(lineReader)
            mail.size = size
            if (endListBySize) {
                break
            }
        } else if (name == "FLAGS") {
            mail.flags = imapReaderFlags(lineReader)
        } else if (name == "INTERNALDATE") {
            // todo
            let _ = lineReader.readRune() // skip \"
            let _ = lineReader.readUntil({rune => rune == r'\"'}).getOrThrow().trimEnd("\"")
            // internalDate = time
        } else if (name == "ENVELOPE") {
            // todo
            var subject = ""
            var from = MailAddress()
            var to = ArrayList<MailAddress>()
            let enevelope = match (parseThisItem(lineReader)) {
                case ImapValue.LIST(list) =>
                    list
                case _ =>
                    throw MailContentParseException("Invalid fetch ENVELOPE")
            }
            if (enevelope.size < 7) {
                throw MailContentParseException("Invalid fetch ENVELOPE")
            }
            subject = match (enevelope[1]) {
                case ImapValue.STRING(str) =>
                    decodeSubject(str)
                case _ =>
                    "" // NIL
            }
            match (enevelope[2]) {
                case ImapValue.LIST(list) =>
                    if (list.size > 0) {
                        match (list[0]) {
                            case ImapValue.LIST(list) =>
                                from = parseImapAddress(list)
                            case _ =>
                                ()
                        }
                    }
                case _ =>  ()
            }
            match (enevelope[5]) {
                case ImapValue.LIST(list) =>
                    for (item in list) {
                        match (item) {
                            case ImapValue.LIST(list) =>
                                to.add(parseImapAddress(list))
                            case _ =>
                                ()
                        }
                    }
                case _ => ()
            }
            if (subject != "") {
                mail.subject = subject
            }
            if (from.address != "" || from.name != "") {
                mail.from = from
            }
            if (!to.isEmpty()) {
                mail.to = to
            }
        } else if (name == "BODY" || name == "BODYSTRUCTURE") {
            // body must be list
            let body = match (parseThisItem(lineReader)) {
                case ImapValue.LIST(list) =>
                    list
                case _ =>
                    throw MailContentParseException("Invalid fetch BODY")
            }
            //
            if (body.size < 1) {
                throw MailContentParseException("Invalid fetch BODY (size < 1)")
            }
            match (body.get(0).getOrThrow()) {
                case ImapValue.STRING(value0) =>
                    if (body.size < 6) {
                        throw MailContentParseException("Invalid fetch BODY (size < 6)")
                    }
                    imapSetContentType = match (body.get(1).getOrThrow()) {
                        case ImapValue.STRING(value1) => "${value0}/${value1}"
                        case _ => value0
                    }
                    imapSetContentTransferEncoding = match (body.get(5).getOrThrow()) {
                        case ImapValue.STRING(value5) => value5
                        case _ => ""
                    }
                case ImapValue.LIST(_) => 
                     match (body.get(body.size - 1).getOrThrow()) {
                        case ImapValue.STRING(last) => 
                            imapSetContentType = "multipart/${last.toAsciiLower()}"
                        case _ => ()
                     }
                case _ => ()
            }
        } else if (name.startsWith("BODY[")) {
            let byteCount = imapReaderByteCount(lineReader);
            if (lineReader.readRune().isSome()) {
                throw MailContentParseException()
            }
            let mailData = reader.readSize(byteCount)
            lineReader = StreamReader(ByteBuffer(reader.readln().getOrThrow({=>MailConnectExcption()}).toArray()))
            let str = String.fromUtf8(mailData)
            if (textBody) {
                mail.data = str
            } else {
                let (from, to, cc, bcc, subject, data) = parseMailContent(
                    str,
                    imapSetContentType: imapSetContentType,
                    imapSetContentTransferEncoding: imapSetContentTransferEncoding,
                    skipHeaders: skipHeaders
                )
                if (from != "") {
                    mail.from = parseMailAddress(from)
                }
                if (to != "") {
                    mail.to = parseMailAddresses(to)
                }
                if (cc != "") {
                    mail.cc = parseMailAddresses(cc)
                }
                if (bcc != "") {
                    mail.bcc = parseMailAddresses(bcc)
                }
                mail.subject = subject
                mail.data = data
            }
        } else {
            throw MailContentParseException(
                "not match imap item name",
                name
            )
        }
    }
    mail
}

private func imapReaderNumber(reader: StreamReader): (Int64, Bool) {
    var endList = false
    let builder = StringBuilder()
    while(true) {
        let rune = reader.readRune().getOrThrow({=>MailConnectExcption("Connect has been eof")})
        if (rune >= r'0' && rune <= r'9') {
            builder.append(rune)
            continue
        } else if (rune == r' ') {
            if (builder.size == 0) {
               continue
            }
            break
        } else if (rune == r')') {
            endList = true
            break
        } else {
            throw MailContentParseException("Invalid NUMBER : ${rune}")
        }
    }
    return (Int64.parse(builder.toString()), endList)
}

private func matchRunes(runes: String, reader: StreamReader) {
    for(rune in runes.runes()) {
        if (rune != reader.readRune().getOrThrow({=>MailConnectExcption()})) {
            throw MailConnectExcption("not match rune")
        }
    }
}

private func imapReadItemName(reader: StreamReader): String {
    let builder = StringBuilder()
    var inSquareBrackets = false
    while (true) {
        let rune = reader.readRune().getOrThrow({=>MailConnectExcption()})
        if (rune == r" " && !inSquareBrackets) {
            if (builder.size == 0) {
                continue
            }
            break
        } 
        if (!inSquareBrackets) {
            if (rune == r")") {
                if (builder.size == 0) {
                    return ")"
                }
                throw MailContentParseException(" ${builder} ${rune}")
            }
            if (rune == r"(") {
                throw MailContentParseException(" ${builder} ${rune}")
            }
        }
        builder.append(rune)
        if (rune == r"[") {
            inSquareBrackets = true
        } else if (rune == r"]") {
            inSquareBrackets = false
        }  
    }
    builder.toString()
}

public func imapReaderFlags(reader: StreamReader): ArrayList<String> {
    var builder = StringBuilder()
    let list = ArrayList<String>()
    func takeFlag() {
        if (builder.size > 0) {
            list.add(builder.toString())
            builder = StringBuilder()
        }
    }
    var inBrackets = false
    while (true) {
        let rune = reader.readRune().getOrThrow({=>MailConnectExcption()})
        if (rune == r"(") {
            if (!inBrackets) {
                inBrackets = true
            } else {
                throw MailConnectExcption()
            }
        } else if (rune == r")") {
            if (inBrackets) {
                takeFlag()
                break
            } else {
                throw MailConnectExcption()
            }
        } else if (rune == r" ") {
            takeFlag()
        } else {
            builder.append(rune)
        }
    }
    list
}

private func imapReaderByteCount(reader: StreamReader): Int64{
    let builder = StringBuilder()
    var inCurlyBraces = false
    while(true) {
        let rune = reader.readRune().getOrThrow({=>MailContentParseException()})
        if (rune == r" " && !inCurlyBraces) {
            continue
        } 
        if (rune == r"{" && !inCurlyBraces) {
            inCurlyBraces = true
            continue
        }
        if (!inCurlyBraces) {
            throw MailConnectExcption()
        }
        if (rune == r"}") {
            break
        }
        builder.append(rune)
    }
    Int64.parse(builder.toString())
}
