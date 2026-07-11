class Base64
============

## 成员函数

| 函数 | 说明 |
| -- | :-- |
| encoder | 生成一个编码器
| decoder | 生成一个解码器
| inputStream | 读取Base64的流
| outputStram | 以base64写入 (写入结束后需要用 finish 将剩余字节编码并pad, 写入缓冲区)
| encodeToString | 编码字节数组到String
| decodeFromString | 将文本解码成字节数组


class Base64Encoder
====================

| 函数 | 说明 |
| -- | :-- |
| encode | 编码
| finish | 编码结束并返回缓存中的数据

| 属性 | 说明 |
| -- | :-- |
| finished | 是否已经结束


class Base64Decoder
====================

| 函数 | 说明 |
| -- | :-- |
| decode | 解码
| finish | 解码结束并返回缓存中的数据, 若结尾不足4字节，当作pad被省略处理

| 属性 | 说明 |
| -- | :-- |
| finished | 是否已经结束


class Base64OutputStream
========================

以base64写入

写入结束后需要用 finish 将剩余字节编码并pad, 写入缓冲区

| 属性 | 说明 |
| -- | :-- |
| finished | 是否已经结束



class Base64InputStream
=======================

读取base64文件, 若结尾不足4字节，当作pad被省略处理

| 属性 | 说明 |
| -- | :-- |
| finished | 是否已经结束
