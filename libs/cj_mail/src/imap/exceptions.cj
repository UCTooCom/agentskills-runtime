package cj_mail.imap

import cj_mail.commons.*
import cj_mail.exception.*

public class ImapException <: MailException & ToString {
   public var response: String

    public init(response: String) {
        this.response = response
    }

    public func toString(): String {
        "ImapException(response=${response})"
    }
}
