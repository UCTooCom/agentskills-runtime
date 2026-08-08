# 静态文件服务器示例

演示提供静态文件服务，支持目录列表、MIME 类型检测和 Range 请求。

## 构建和运行

```bash
cd sample/file_server
# 创建包含静态文件的 www 目录
mkdir -p www
echo "<h1>Hello</h1>" > www/index.html
cjpm run
```

在浏览器中打开 http://localhost:8080。

## 主要特性

- 通过可配置的 `serveStatic()` 提供静态文件服务
- 根据文件扩展名自动检测 MIME 类型
- HTTP Range 请求（部分内容）
- 可配置 `maxAge` 的 Cache-Control
- 目录索引回退（index.html）

```cangjie
let fileConfig = FileServerConfig()
fileConfig.enableCache = true
fileConfig.maxAge = 7200
router.get("/static/{path}", serveStatic("./www", config: fileConfig))
```

## 预期输出

服务器在 8080 端口启动。访问 http://localhost:8080/ 重定向到 /index.html。./www 目录下的静态文件以适当的内容类型和缓存头提供服务。
