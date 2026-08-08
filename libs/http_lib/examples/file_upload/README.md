# 文件上传服务器示例

演示使用 multipart/form-data 的文件上传服务器。

## 构建和运行

```bash
cd sample/file_upload
mkdir -p uploads
cjpm build
cjpm run
```

在浏览器中打开 http://127.0.0.1:8081。

## 主要特性

- 简洁样式的 HTML 上传表单
- 通过 `parseMultipartBody()` 解析多部分文件
- 将文件保存到磁盘
- 已上传文件列表
- 最大 100 MB 上传大小

```cangjie
let fields = parseMultipartBody(req)
match (fields.get("file")) {
    case Some(fileField) =>
        let outputPath = Path("./uploads/${fileField.fileName}")
        File.writeTo(outputPath, fileField.data)
}
```

## 预期输出

服务器在 8081 端口监听。访问根 URL 获取上传表单。上传的文件保存到 `./uploads` 目录并在页面上列出。
