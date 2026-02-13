# API 接口测试指南

## 测试 API 接口是否正常工作

要验证 AgentSkills Runtime API 接口是否正常工作，您可以按照以下步骤进行测试：

### 1. 启动 API 服务

首先，确保您已经启动了 API 服务：

```bash
# 构建项目
cjpm build

# 运行 API 服务（默认在 8080 端口）
cjpm run --skip-build --name magic.api
```

### 2. 测试健康检查接口

打开另一个终端窗口，使用 curl 命令测试 hello 接口：

```bash
curl -X GET http://localhost:8080/hello
```

预期响应：
```json
{
  "message": "Hello World"
}
```

### 3. 测试其他 API 接口

测试获取技能列表接口：
```bash
curl -X GET http://localhost:8080/skills
```

测试 MCP 流接口：
```bash
curl -X GET http://localhost:8080/mcp/stream
```

### 4. 使用 Postman 或其他 API 测试工具

您也可以使用 Postman、Insomnia 或任何其他 API 测试工具来测试这些端点：

1. 设置 GET 请求到 `http://localhost:8080/hello`
2. 验证响应状态码为 200
3. 验证响应体包含 "Hello World" 消息

### 5. 检查服务日志

在 API 服务运行的终端中，您应该能看到请求处理的日志信息，这表明服务正在接收和处理请求。

### 注意事项

- 确保端口 8080 没有被其他服务占用
- 如果您指定了其他端口，请相应地调整测试 URL
- 如果服务无法启动，请检查错误日志以排查问题