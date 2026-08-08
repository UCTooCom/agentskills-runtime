# 流式上传

演示使用 ResponseBuilder 的流式 API 处理流式/分块请求体。增量读取请求体而无需在内存中缓冲所有内容。

## 使用方法

```bash
cjpm build
./target/release/bin/main
# 测试: curl -X POST --data-binary @largefile.bin http://localhost:8080/upload
```
