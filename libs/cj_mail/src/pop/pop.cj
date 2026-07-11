
package cj_mail.pop

import stdx.net.tls.*
import std.net.*
import std.collection.*
import std.io.*
import std.regex.*
import cj_mail.log.*
import cj_mail.commons.*
import stdx.encoding.base64.*
import cj_mail.exception.*
import std.convert.*

private let popStatePattern = Regex("^\\+OK (\\d+) (\\d+)$")
private let defaultTlsPort: UInt16 = 995

public class PopException <: Exception {
    public var serverResponse: String

    public init(serverResponse: String) {
        this.serverResponse = serverResponse
    }
}

public class Pop <: Resource {

    public var connection: MailConnection

    public init(connection: MailConnection) {
        this.connection = connection
        readCommand()
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

    public func readCommand(): String {
        let reader = this.connection.reader
        let line = reader.readln().getOrThrow({=>MailConnectExcption("Connect has been eof")})
        cjMailLogger.trace("S: ${line}", ("package", "cj_mail.smtp"))
        if (line.toAsciiLower().startsWith("-ERR")) {
            throw PopException(line)
        }
        line
    }

    public func writeCommand(command: String) {
        let writer = this.connection.writer
        cjMailLogger.trace("C: ${command}", ("package", "cj_mail.smtp"))
        writer.write(command)
        writer.write("\r\n")
        writer.flush()
    }

    public func noop() {
        writeCommand("NOOP")
        readCommand()
    }

    public func rest() {
        writeCommand("RSET")
        readCommand()
    }

    public func apop(username: String, password: String) {
        writeCommand("APOP ${username} ${password}")
        readCommand()
    }

    public func user(username: String) {
        writeCommand("USER ${username}")
        readCommand()
    }

    public func pass(password: String) {
        writeCommand("PASS ${password}")
        readCommand()
    }

    public func auth(username: String, password: String) {
        user(username)
        pass(password)
    }

    public func stat(): Int64 {
        writeCommand("STAT")
        let line = readCommand()
        match (regexGroups(popStatePattern, line)) {
            case Some(r) =>
                Int64.parse(r[1])
            case None =>
                throw Exception("Invalid response")
        }
    }

    public func list() :(Int64, ArrayList<(Int64, Int64)>) {
        writeCommand("LIST")
        let line = readCommand()
        if (!line.startsWith("+OK")) {
            throw Exception("Invalid response : ${line}")
        }
        var count = -1
        if (line != "+OK") {
            let parts = line.split(" ")
            count = Int64.parse(parts[1])
        }
        let mails = ArrayList<(Int64, Int64)>()
        while (true) {
            let line = readCommand()
            if (line == ".") {
                break
            }
            let parts = line.split(" ")
            if (parts.size < 2) {
                throw Exception("Invalid response")
            }
            let msg = Int64.parse(parts[0])
            let size = Int64.parse(parts[1])
            mails.add((msg, size))
        }
        (count, mails)
    }

    public func list(msg: Int64) : (Int64, Int64) {
        writeCommand("LIST ${msg}")
        let response = readCommand()
        if (let Some(r) <- regexGroups(popStatePattern, response)) {
            let idx = Int64.parse(r[1])
            let size = Int64.parse(r[2])
            (idx, size)
        } else {
            throw Exception("Invalid response")
        }
    }

    public func retr(msg : Int64) : (Int64, String) {
        writeCommand("RETR ${msg}")
        let lien = readCommand()
        let split = lien.split(" ")
        if (split.size < 2) {
            throw Exception("Invalid response")
        }
        let size = Int64.parse(split[1])
        var content = StringBuilder()
        while (true) {
            let line = readCommand()
            if (line == ".") {
                break
            }
            content.append(line)
            content.append("\r\n")
        }
        (size, content.toString())
    }

    public func retrParse(msg: Int64) : ReceiveMail {
        let (_, content) = retr(msg)
        let (from, to, cc, bcc, subject, data) = parseMailContent(content)
        
        let mail = ReceiveMail()
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
        mail
    }

    public func dele(msg: Int64) {
        writeCommand("DELE ${msg}")
        readCommand()
    }

   public func quit() {
      writeCommand("QUIT")
      readCommand()
   }
    
}
