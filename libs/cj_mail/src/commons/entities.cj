package cj_mail.commons

import std.collection.*
import std.io.*
import std.regex.*
import charset4cj.charset.*
import cj_mail.log.*
import cj_mail.encoding.base64.*
import cj_mail.exception.*
import std.convert.*

let mailAddressPattern = Regex("^(.*)?<(.*)>$")

/// MailAdress

public class MailAddress <: ToString {
   public var name: String
   public var address: String

   public init(name: String, address: String) {
      this.name = name
      this.address = address
   }

   public init() {
      this("", "")
   }

   public func toString() {
      "${name}<${address}>"
   }
}

public func parseMailAddress(address: String): MailAddress {
   match (regexGroups(mailAddressPattern,address)) {
      case Some(matches) =>
         let name = matches[1].trimAscii()
         let addr = matches[2].trimAscii()
         MailAddress(decodeSubject(name), addr)
      case None =>
         MailAddress("", address)
   }
}

public func parseMailAddresses(addresses: String): ArrayList<MailAddress> {
   let parts = addresses.lazySplit(",")
   let result = ArrayList<MailAddress>()
   for (part in parts) {
      var text = part.trimAscii()
      if (text == "") {
         continue
      }
      result.add(parseMailAddress(text))
   }
   result
}

/// Mail

public open class Mail {
   public var from: MailAddress
   public var to: ArrayList<MailAddress>
   public var cc: ArrayList<MailAddress>
   public var bcc: ArrayList<MailAddress>
   public var subject: String
   public var data: MailContent = ""

   public init() {
      from = MailAddress()
      to = ArrayList()
      cc = ArrayList()
      bcc = ArrayList()
      subject = ""
   }
}

extend Mail <: ToString {

   public func toString(): String {
      toString(ignoreBody: false)
   }

   public func toString(ignoreBody!: Bool = false): String {
      if (this is ImapReceiveMail) {
         let mail = (this as ImapReceiveMail).getOrThrow()
         let builder = StringBuilder("ImapReceiveMail(idx=${mail.idx}, uid=${mail.uid}, from=${mail.from}, to=${mail.to}")
         if (mail.cc.size > 0) {
            builder.append(", cc=${mail.cc}")
         }
         if (mail.bcc.size > 0) {
            builder.append(", bcc=${mail.bcc}")
         }
         if (mail.flags.size > 0) {
            builder.append(", flags=${mail.flags}")
         }
         builder.append(", subject=${mail.subject}")
         if (!ignoreBody) {
            builder.append(", data=${mail.data}")
         }
         builder.append(")")
         return builder.toString()
      } else {
         let builder =StringBuilder("Mail(from=${from}, to=${to}, cc=${cc}, bcc=${bcc}, subject=${subject}, ")
         if (!ignoreBody) {
            builder.append(", data=${data}")
         }
         builder.append(")")
         return builder.toString()
      }
   }
}

public type SendMail = Mail
public type ReceiveMail = Mail

public class ImapReceiveMail <: ReceiveMail {
   public var idx: Int64
   public var uid: Int64
   public var size: Int64
   public var flags: ArrayList<String>
   public var messageId: String
   public init() {
      super()
      idx = -1
      uid = -1
      size = -1
      flags = ArrayList()
      messageId = ""
   }
}

/// MailContent: MutilParts / MimeFile or MimeText

public interface MailContent <: ToString {
}

extend String <: MailContent{
}

public class MimeText <: MailContent {
     public var text: String = ""
     public var contentType: String = ""
     public var contentId: String = ""
     public var headers: ArrayList<(String, String)> = ArrayList()

     public init() {
     }

     public init(text: String, contentType: String, contentId!: String = "", headers!: ArrayList<(String, String)> = ArrayList()) {
        this.text = text
        this.contentType = contentType
        this.contentId = contentId
        this.headers = headers
     }

     public func toString(): String {
         let builder = StringBuilder("MimeText(contentType=${contentType}, text=${text}")
         if (contentId != "") {
            builder.append(", contentId=${contentId}")
         }
         if (headers.size > 0) {
            builder.append(", headers=(")
            for (header in headers) {
               builder.append("${header[0]}=${header[1]}, ")
            }
            builder.append(")")
         }
         builder.append(")")
         builder.toString()
     }
}

public class MimeFile <: MailContent {
   public var data: Array<Byte>
   public var contentType: String
   public var contentId: String
   public var fileName: String
   public var headers: ArrayList<(String, String)>

   public init() {
      this.data = "".toArray()
      this.contentType = ""
      this.contentId = ""
      this.fileName = ""
      this.headers = ArrayList()
   }

   public init(data: Array<Byte>, contentType: String, contentId!: String = "", headers!: ArrayList<(String, String)> = ArrayList()) {
      this.data = data
      this.contentType = contentType
      this.contentId = contentId
      this.headers = headers
      this.fileName = ""
   }

   public func toString(): String {
      let builder = StringBuilder("MimeFile(contentType=${contentType}, data={${data.size}}")
      if (contentId != "") {
         builder.append(", contentId=${contentId}")
      }
      if (headers.size > 0) {
         builder.append(", headers=(")
         for (header in headers) {
            builder.append("${header[0]}=${header[1]}, ")
         }
         builder.append(")")
      }
      builder.append(")")
      builder.toString()
   }
}

public class MimeMutilParts <: Collection<MailContent> & MailContent {
   public var contentType: String = ""
   public var contentId: String = ""
   public var headers: ArrayList<(String, String)> = ArrayList()
   public var parts: ArrayList<MailContent> = ArrayList()

   public init() {
   }

   public func iterator() : Iterator<MailContent> {
      parts.iterator()
   }

   public prop size: Int64 {
        get() { parts.size }
   }

   public func isEmpty(): Bool {
      parts.isEmpty()
   }

   public func append(part: MailContent) {
      parts.add(part)
   }

   public func toString(): String {
      "MimeMutilParts(contentType=${contentType}, size=${parts.size}, parts=${parts})"
   }
}

// parse conent (pop / imap)

public enum MailContentType {
   | Main
   | Par
}

public func parseMailContent(
   content: String, isPartEntry!: Bool = false,
   imapSetContentType!: String = "", imapSetContentTransferEncoding!: String = "",
   skipHeaders!: Bool = false
) : (String, String, String, String, String, MailContent) {
   var onlyHeaders = false
   var from = ""
   var to = ""
   var cc = ""
   var bcc = ""
   var subject = ""
   var contentId = ""
   var contentType = ""
   var contentTransferEncoding =""
   var headers = ArrayList<(String, String)>()
   // read header
   var lines = StringReader(ByteBuffer(content.toArray()))
   // foreach Header
   var headerLine = ""
   func parseHeader() {
      if (headerLine == "") {
         return
      }
      let parts = headerLine.trimAscii().split(":", 2, removeEmpty: true)
      if (parts.size < 2) {
            throw MailContentParseException("Missing colon in mail content header value", headerLine)
      }
      let key = parts[0].trimAscii()
      let value = parts[1].trimAscii()
      match (key) {
            case "From" => from = value
            case "To" => to = value
            case "Cc" => cc = value
            case "Bcc" => bcc = value
            case "Subject" => subject = value
            case "Content-ID" => contentId = value
            case "Content-Type" => contentType = value
            case "Content-Transfer-Encoding" => contentTransferEncoding = value
            case _ => 
                  headers.add((key, value))
      }
      headerLine = ""
   }
   var first = true;
   while(!skipHeaders && true){
      let lineOption = lines.readln()
      let line = match (lineOption) {
            case Some(l) => l
            case None => 
               onlyHeaders = true
               break
      }
      if (first && !line.contains(":")) {
            if (isPartEntry) {
               return (from, to, cc, bcc, subject, content)
            }
            throw MailContentParseException("Missing colon in mail content header", line)
      }
      if (first) {
         first = false
      }
      if (line == "") {
            parseHeader()
            break
      } else if (line.contains(":")) {
            parseHeader()
            headerLine += line
            headerLine += "\r\n"
      } else if (let Some(_take) <- regexGroups(Regex("^\\s+[^\\n]+"), line)) {
            headerLine += " "
            headerLine += line.trimAscii()
      } else {
         throw MailContentParseException("Invalid header line", line)
      }
   }
   if (contentType.isEmpty()) {
      contentType = imapSetContentType
   }
   if (contentTransferEncoding.isEmpty()) {
      contentTransferEncoding = imapSetContentTransferEncoding
   }
   parseHeader()
   // fix
   // "=?{charset}?{encoding}?{encoded_text}?="
   subject = decodeSubject(subject)
   
   if (contentId.startsWith("<") && contentId.endsWith(">")) {
      contentId = contentId[1..contentId.size-1]
   }
   // todo ?q? quopri
   // parse mime
   if (contentType == ""){
      var textBody = StringBuilder()
      while(let Some(line) <- lines.readln()) {
         textBody.append(line)
         textBody.append("\r\n")
      }
      let mc: MailContent = if ("base64" == contentTransferEncoding.toAsciiLower()) {
            MimeFile(parseBase64MailContent(textBody.toString()), "application/octet-stream", contentId: contentId, headers: headers).toString()
      } else if ("quoted-printable" == contentTransferEncoding.toAsciiLower()) {
            MimeFile(parseQuotedPrintableMailContent(textBody.toString()), "application/octet-stream", contentId: contentId, headers: headers).toString()
      } else {
         textBody.toString()
      }
      return (from, to, cc, bcc, subject, mc)
   }

   let parts = contentType.split(";")
   let contentTypeMime = parts[0].trimAscii()
   var boundary=""
   var charset=""
   for (p in parts[1..]) {
      match (p.indexOf("=")) {
            case Some(idx) =>
               let key = p[0..idx].trimAscii()
               var value = p[idx+1..].trimAscii()
               if (value.startsWith("\"") && value.endsWith("\"")) {
                  value = value[1..value.size-1]
               }
               match (key) {
                  case "boundary" => boundary = value
                  case "charset" => charset = value
                  case _ => 
                        cjMailLogger.debug("Ignore content type : ${key}", ("package", "cj_mail.commons"))
               }
            case None =>
               continue
      }
   }

   // parse body
   if (contentTypeMime.toAsciiLower().startsWith("text/")) {
      if (onlyHeaders) {
         return (from, to, cc, bcc, subject, MimeText("", contentTypeMime, contentId: contentId, headers: headers))
      }
      var textBody = ""
      while(let Some(line) <- lines.readln()) {
            textBody += line + "\r\n"
      }
      textBody = decodeTextBody(textBody, charset, contentTransferEncoding)
      let text = MimeText(textBody, contentTypeMime, contentId: contentId, headers: headers)
      return (from, to, cc, bcc, subject, textBody)
   } else if (contentTypeMime.startsWith("multipart/")) {
      let mimeMutilParts = MimeMutilParts()
      mimeMutilParts.contentType = contentTypeMime
      mimeMutilParts.contentId = contentId
      mimeMutilParts.headers = headers
      if (onlyHeaders) {
         return (from, to, cc, bcc, subject, mimeMutilParts)
      }
      if (boundary == "") {
            if (skipHeaders) {
               var builder = StringBuilder()
               while (true) {
                  let line = lines.readln()
                  match(line) {
                     case Some(line) =>
                        if (line.startsWith("--")) {
                           mimeMutilParts.append(builder.toString())
                           builder = StringBuilder()
                           builder.append(line)
                           builder.append("\r\n")
                           while (let Some(lineOff) <- lines.readln()) {
                                 builder.append(lineOff)
                                 builder.append("\r\n")
                           }
                           lines = StringReader(ByteBuffer(builder.toString().toArray()))
                           boundary = line.trimStart("--").trimEnd("--")
                           break
                        } else {
                           builder.append(line)
                           builder.append("\r\n")
                        }
                     case None =>
                        mimeMutilParts.append(builder.toString())
                        return (from, to, cc, bcc, subject, mimeMutilParts)
                  }
               }
            } else {
               throw MailContentParseException("multipart missing boundary", contentType)
            }
      }
      var line = lines.readln().getOrThrow({=>MailContentParseException("The email content ended prematurely 1")})
      // blank content
      if (line == "--${boundary}--") {
            return (from, to,  cc, bcc, subject, mimeMutilParts)
      }
      // children
      var builder = StringBuilder()
      while(true) {
         line = lines.readln().getOrThrow({=> MailContentParseException("The email content ended prematurely 2")})
         if (line.startsWith("--${boundary}")) {
            let (_, _, _, _, _, data) = parseMailContent(builder.toString(), isPartEntry: true)
            mimeMutilParts.append(data)
            if (line == "--${boundary}--") {
               break
            }
            builder = StringBuilder()
            continue
         }
         builder.append(line)
         builder.append("\r\n")
      }
      return (from, to,  cc, bcc, subject, mimeMutilParts)
   } else {
      if (onlyHeaders) {
         return (from, to, cc, bcc, subject, MimeFile("".toArray(), contentTypeMime, contentId: contentId, headers: headers))
      }
      var textBody = ""
      while(let Some(line) <- lines.readln()) {
            textBody += line + "\r\n"
      }
      let file = if ("base64" == contentTransferEncoding.toAsciiLower()) {
            MimeFile(parseBase64MailContent(textBody), contentTypeMime, contentId: contentId, headers: headers)
      } else if ("quoted-printable" == contentTransferEncoding.toAsciiLower()) {
            MimeFile(parseQuotedPrintableMailContent(textBody), contentTypeMime, contentId: contentId, headers: headers)
      } else {
            MimeFile(textBody.toArray(), contentTypeMime, contentId: contentId, headers: headers)
      }
      file.headers = headers
      file.contentId = contentId
      return (from, to, cc, bcc, subject, file)
   }
}

public func parseBase64MailContent(content: String): Array<Byte> {
   StdBase64.decodeFromString(content)
}

public func parseQuotedPrintableMailContent(content: String): Array<Byte> {
   let builder = ByteBuffer()
   let reader = StringReader(ByteBuffer(content.trimAscii().toArray()))
   while(let Some(rune) <- reader.read()) {
      if (rune == r'=') {
         let next =String([
            reader.read().getOrThrow({=>MailContentParseException("Invalid quoted printable content", content)}),
            reader.read().getOrThrow({=>MailContentParseException("Invalid quoted printable content", content)})
         ])
         if (next == "\r\n") {
            continue
         }
         let byte = Byte.parse("0x${next}");
         builder.write([byte])
      } else {
         let bytes = String([rune]).toArray();
         builder.write(bytes)
      }
   }
   builder.bytes()
}

let subjectEncodeRegexp = Regex("=\\?([a-zA-Z0-9\\-]+)\\?([bqBQ])\\?([^\\?]+)\\?=")

protected func decodeSubject(subjectInput: String): String {
   var subject = subjectInput
   if (subject == "") {
      ""
   } else if (subject.startsWith("=?") && subject.endsWith("?=")) {
      let builder = StringBuilder()
      let sp = subject.split("\n")
      for (spItem in sp) {
         let item = spItem.trimAscii()
         if (let Some(matches) <- regexGroups(subjectEncodeRegexp, item)) {
            let charset = matches[1]
            let encoding = matches[2]
            let text = matches[3]
            let bytes = if (encoding.toAsciiLower() == "b") {
               parseBase64MailContent(text)
            } else if (encoding.toAsciiLower() == "q") {
               parseQuotedPrintableMailContent(text)
            } else {
               builder.append(item)
               continue
            }
            if (let Some(charsetInstance) <- Charsets.forName(charset)) {
               builder.append(charsetInstance.newDecoder().decode(bytes))
               continue
            } else {
               builder.append(item)
               continue
            }
         } else {
            builder.append(item)
         }
      }
      builder.toString()
   } else {
      subject
   }
}

func decodeTextBody(textBody: String, charset: String, contentTransferEncoding: String): String {
   let bytes = if ("base64" == contentTransferEncoding.toAsciiLower()) {
         parseBase64MailContent(textBody)
   } else if ("quoted-printable" == contentTransferEncoding.toAsciiLower()) {
         parseQuotedPrintableMailContent(textBody)
   } else {
      return textBody
   }
   if (let Some(charsetInstance) <- Charsets.forName(charset)) {
      charsetInstance.newDecoder().decode(bytes)
   } else {
      textBody
   }
}

