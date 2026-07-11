class Imap
==========

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

## 成员函数

| 函数 | 说明 |
| -- | :-- |
| isClose | 是否断开链接
| close | 断开链接
| login | `LOGIN` 方式认证
| select | `SELECT` 命令 , 选择文件夹
| examine | `EXAMINE` 命令 , 选择文件夹 (只读)
| search | `SEARCH` 搜索邮件
| fetch | 获取邮件、返回 (命令编码, 原文)
| fetchInfo | 获取邮件基本信息（不返回正文）
| fetchFlags | 获取邮件标志信息（不返回正文）
| store | `STORE` 对邮件增减标记（已读、标星）或删除邮件
| id | `ID` 执行ID命令、服务器会对客户端的特征进行不同处理
| quit | `QUIT`
