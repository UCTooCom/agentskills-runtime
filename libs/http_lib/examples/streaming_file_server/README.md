# 流式文件服务器

演示流式文件服务，支持 Range 请求（RFC 7233）、条件请求（ETag、If-None-Match）以及基于文件扩展名的 Content-Type 检测。

## 使用方法

```bash
cjpm build
./target/release/bin/main
# 测试: curl -H "Range: bytes=0-99" http://localhost:8080/file.txt
```
