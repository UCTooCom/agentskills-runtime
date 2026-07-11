
CJ_MAIL API文档
==============

## 类

#### - [Smtp](classes/Smtp.md) : 发送邮件的工具类
#### - [Pop](classes/Pop.md) : 使用POP3接收邮件
#### - [Imap](classes/Imap.md) : 使用IMAP接收邮件
#### - [Base64](classes/Base64.md) : Base64编码解码工具

#### - [MailConnection](classes/MailConnection.md) : 网络连接

## 函数
#### - setCjMailLogger() : 设置logger

## 对象

#### - StdBase64 : [Base64](classes/Base64.md)类使用无参构造器构造的对象，方便直接使用
#### - WrappedBase64 : [Base64](classes/Base64.md)构造对象，输出base64编码时会自动追加`\r\n`方便直接使用
#### - StdQuotedPrintable : [QuotedPrintable](classes/QuotedPrintable)构造对象，方便直接使用
