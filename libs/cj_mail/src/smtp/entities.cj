
package cj_mail.smtp

import cj_mail.commons.*
import cj_mail.exception.*

public class SmtpResponse <: ToString{
   public var code: Int64
   public var message: String

   public init() {
      this.code = 0
      this.message = ""
   }

   public init(code: Int64, message: String) {
      this.code = code
      this.message = message
   }

   public func toString(): String {
      "SmtpResponse(code=${code}, message=${message})"
   }

}

public class SmtpException <: MailException & ToString{
   public var response: SmtpResponse

   public init(response: SmtpResponse) {
      this.response = response
   }

   public func toString(): String {
      "SmtpException(response=${response})"
   }
}
