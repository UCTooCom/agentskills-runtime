class QuotedPrintable
=====================

## 成员函数

| 函数 | 说明 |
| -- | :-- |
| encoder | 生成一个编码器
| decoder | 生成一个解码器
| inputStream | 读取QuotedPrintable的流
| outputStram | 以QuotedPrintable写入 (写入结束后 flushLine 方法, 将缓冲区写入输出流)
| encodeToString | 编码字节数组到String
| decodeFromString | 将文本解码成字节数组


class QuotedPrintableEncoder
============================

| 函数 | 说明 |
| -- | :-- |
| encode | 编码
| finish | 编码结束并返回缓存中的数据

| 属性 | 说明 |
| -- | :-- |
| finished | 是否已经结束

class QuotedPrintableDecoder
============================

| 函数 | 说明 |
| -- | :-- |
| decode | 解码
| finish | 解码结束并返回缓存中的数据

| 属性 | 说明 |
| -- | :-- |
| finished | 是否已经结束


class QuotedPrintableOutputStream
=================================

以QuotedPrintable写入 (写入结束后 flushLine 方法, 将缓冲区写入输出流)


class QuotedPrintableInputStream
================================

读取QuotedPrintable格式的输入流
