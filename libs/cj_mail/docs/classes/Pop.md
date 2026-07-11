Class Pop
=========

## 用例

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

## 成员函数

| 函数 | 说明 |
| -- | :-- |
| isClose | 是否断开链接
| close | 断开链接
| auth | `USER` `PASS` 方式认证
| apop | `APOP` 方式认证（不是所有服务器都支持）
| quit | `QUIT` 命令
| stat | `STAT` 命令
| list | `LIST` 列出邮件 返回 List<(索引、大小)>
| retr | `RETR` 获取邮件 原文
| retrParse | 获取邮件、并解析成方便操作的对象
