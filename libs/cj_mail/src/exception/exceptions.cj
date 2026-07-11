package cj_mail.exception

import std.collection.*

public abstract class MailException <: Exception {
    public var lines = ArrayList<String>()

    public init() {
        super()
    }

    public init(message: String) {
        super(message)
    }

    public init(
        message: String,
        line1: String
    ) {
        super(message)
        lines.add(line1)
    }

    public init(
        message: String,
        line1: String,
        line2: String
    ) {
        super(message)
        lines.add(line1)
        lines.add(line2)
    }

    public init(
        message: String,
        lines: ArrayList<String>
    ) {
        super(message)
        this.lines = lines
    }

}

public class MailContentParseException <: MailException & ToString{

    public init() {
        super()
    }

    public init(message: String) {
        super(message)
    }

    public init(message: String, line: String) {
        super(message, line)
    }

    public override func toString(): String {
        var msg = "MailContentParseException: ${message}"
        if (!lines.isEmpty()) {
            for (line in lines) {
                msg += " : "
                msg += line
            }
        }
        msg 
    }

}

public class MailConnectExcption <: MailException & ToString {

    public init() {
        super()
    }

    public init(message: String) {
        super(message)
    }

    public override func toString(): String {
        "MailConnectExcption(${message})"
    }

}
