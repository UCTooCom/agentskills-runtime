Class Smtp
==========

## 用例

```cangjie
import cj_mail.*

// 链接服务器进行认证并发送邮件
main(): Int64 {
   let smtp = Smtp()
   smtp.host = "smtp.mail.com"
   smtp.tlsPort = 465
   smtp.connect()
   smtp.plain("niuhuan@mail.com", "mailPassword") 
   smtp.send(textMail())
   smtp.disconnect()
   return 0
}

// 文本文件
func textMail(): SendMail {
   let mail = SendMail()
   mail.from.name = "niuhuan"
   mail.from.address = "niuhuan@mail.com"
   mail.to = ArrayList(MailAddress("niuhuan", "niuhuan@mail.com"))
   mail.data = "Hello, World!"
   mail
}

// 多分段带附件的邮件
func mutilPartsMail(): SendMail {
   let mail = SendMail()
   mail.from.name = "niuhuan"
   mail.from.address = "niuhuan@mail.com"
   mail.to = ArrayList([MailAddress("niuhuan", "niuhuan@mail.com")])
   let content = MimeMutilParts()
   mail.data = content
   // html 渲染邮件内容
   content.append(MimeText("<h1>Hello, World!</h1>","text/html")) 
   // 增加一个附件
   let file = MimeFile("Hello, World!".toArray(), "application/octet-stream")
   file.headers.append(("Content-Disposition", "attachment; filename=\"test.txt\""))
   content.append(file)
   mail
}
```

## 成员函数

| 函数 | 说明 |
| -- | :-- |
| isClose | 是否断开链接
| close | 断开链接
| plain | `PLAIN` 方式认证
| login | `LOGIN` 方式认证
| quit | `QUIT` 命令（不是所有服务器都支持）
