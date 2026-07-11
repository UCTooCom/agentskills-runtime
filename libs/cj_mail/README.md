CJ_MAIL 仓颉邮件工具
==================

仓颉编程语言实现的 邮件、编码 工具包

## 💡 设计

- 做一个可以收发邮件的工具库、可以收发邮件、进行常见的编码格式
- 保持较少的代码行数、（收取邮件功能使用频率极低）

## 📦 安装

1.&nbsp;使用git方式进行引入, 将依赖放入`cjpm.toml`

```yaml
[dependencies]

cj_mail = { git = "https://gitcode.com/niuhuan_cn/cj_mail.git" }
```

如果您无法使用`Canary`版本, 请使用`cjc_0.53.13`分支

2.&nbsp;执行 `cjpm update` 命令进行依赖更新 

3.&nbsp;在需要使用的仓颉代码中进行引入`import cj_mail.*`

4.&nbsp;后续更新需要再次执行`cjpm update`进行代码拉取。当仓颉包管理器完善时，本项目将尽快会推送到仓库, 使用版本依赖使用

## 🔖 用例

### SMTP

[文档](docs/classes/Smtp.md)

连接邮件服务器并发送 

```cangjie
import cj_mail.*

main(): Int64 {
   let smtp = Smtp("smtp.mail.com")
   smtp.plain("niuhuan@mail.com", "mailPassword") 
   smtp.send(textMail())
   smtp.close()
   return 0
}

func textMail(): SendMail {
   let mail = SendMail()
   mail.from.name = "niuhuan"
   mail.from.address = "niuhuan@mail.com"
   mail.to = ArrayList(MailAddress("niuhuan", "niuhuan@mail.com"))
   mail.data = "Hello, World!"
   mail
}
```

### POP

[文档](docs/classes/Pop.md)

连接POP3服务器并读取邮件

```cangjie
main() : Int64{
    let pop = Pop("pop3.mail.com")
    pop.auth("niuhuan@mail.com", "password")
    let(count, mails) = pop.list()  
    let mailIndex = mails[0][0]
    let mail = pop.retrParse(mailIndex) 
    let(size,text) = pop.retr(mailIndex) 
    pop.quit()
    pop.close()
    0
}
```

### IMAP

[文档](docs/classes/Imap.md)

```cangjie
main(): Int64 {
    let imap = Imap("imap.mail.com")
    imap.login("niuhuan@mail.com", "password")
    imap.select("INBOX")
    // 列出收件箱中的邮件
    let mails = imap.fetchInfo("1:*")
    for (mail in mails) { 
        println("mail : ${mail}")
    }
    0
}
```

### Base64

[更多用例](src/tests/base64_tests.cj) [文档](docs/classes/Base64.md)

```cangjie
main(): Int64 {
    // 直接编码或解码
    let enc = StdBase64.encodeToString(buff)
    let dec = StdBase64.decodeFromString(content)
    // 对流编码或解码
    let encoder = StdBase64.encoder()
    encoder.encode(buff)
    encoder.finish()
}
```

## 📖 特性

| 传输协议 | 详情 |
| -- | -- |
| SMTP | https://datatracker.ietf.org/doc/html/rfc5321 |
| POP | https://datatracker.ietf.org/doc/html/rfc1939 |
| IMAP | https://datatracker.ietf.org/doc/html/rfc3501 |
| SubTypes | https://www.w3.org/Protocols/rfc1341/7_2_Multipart.html |
| Base64 / QuotedPrintable | https://datatracker.ietf.org/doc/html/rfc2045 |

- [x] SMTP
    - [x] 基础认证
    - [x] LOGIN认证
    - [x] 发送邮件
        - [x] 抄送 / 密送
        - [x] 发送文本/html邮件
        - [x] 发送附件
- [x] POP
    - [x] 基础认证
    - [x] `STAT` 获取邮件数
    - [x] `LIST` 列出邮件
    - [x] `RETR` 读取邮件
        - [x] `retr` 获取文件
        - [x] `retrParse` 获取邮件内容并解析
    - [x] `DELE` 删除邮件
- [x] IMAP
    - [x] `LOGIN` 登录
    - [x] `SELECT` 获取收件箱邮件数量
    - [x] `SEARCH` 搜索邮件、返回UID列表
    - [x] `FETCH` 获取邮件内容
        - [x] `fetch` 执行`FETCH`获取邮件内容
        - [x] `fetchInfo` 获取邮件内容并解析（不包含邮件正文）
        - [x] `fetchFlags` 获取UID和Flags
        - [x] `fetchFullParse` 获取邮件内容并解析 (包含邮件正文、正文：文本、附件)
        - [x] `fetchFullText` 获取邮件内容并解析 (包含邮件正文、正文：正文保持纯文本未解析)
    - [x] `STORE` 增改标记（例如已读标记、删除标记、旗帜标记）
    - [x] `MOVE` 移动到其他文件夹
    - [x] `ID` 告知服务器客户端的类型以及特征
- [x] Encoding
    - [x] base64
    - [x] quoted-printable

## 🏗️ 构建

### 经过验证的仓颉版本

| 版本 | 分支 | 
| -- | -- |
| 0.58.3 | main |
| 0.59.6 | main |

### 单元测试
`cjpm test -V src/tests`

## 🏆 贡献

欢迎您的issue或pull request到仓颉TCP或上游仓库地址

fork时请保留上游仓库地址 [https://gitcode.com/niuhuan_cn/cj_mail](https://gitcode.com/niuhuan_cn/cj_mail)

## 📕 协议

参考 [LICENSE](LICENSE) 文件

