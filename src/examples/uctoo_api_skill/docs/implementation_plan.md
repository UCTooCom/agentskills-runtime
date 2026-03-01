# Uctoo API Skill 实现方案

## 问题分析

### 当前问题
1. **技能执行无实际效果**：从聊天界面手动执行uctoo_api_skill时，技能只返回参数信息，没有执行实际的技能逻辑
2. **缺少实际实现**：BaseSkill的默认execute方法只返回参数信息，需要为uctoo_api_skill实现实际的技能逻辑
3. **依赖关系不清晰**：当前实现依赖于uctoo_api_mcp_server，但用户希望从聊天界面直接执行技能

### 根本原因
- uctoo_api_skill示例项目没有完整的SKILL.cj实现
- 现有的实现位于`src/uctoo_api_skill.cj`，但包声明为`magic.examples.uctoo_api_skill.src`，不符合agentskills标准
- 技能的execute方法没有实现实际的API调用逻辑

## 设计方案

### 方案一：完全符合agentskills标准的内联实现（推荐）

#### 架构设计
```
uctoo_api_skill/
├── SKILL.md                 # 技能定义（已存在）
├── SKILL.cj                 # 技能实现类（需要创建）
├── src/                     # 辅助模块
│   ├── models/              # 数据模型
│   │   ├── api_request.cj
│   │   └── api_response.cj
│   ├── api_mapper.cj        # API端点映射
│   ├── auth_manager.cj       # 认证管理
│   ├── nlp_processor.cj     # 自然语言处理
│   └── utils.cj            # 工具函数
├── scripts/                 # 可执行脚本（可选）
│   └── api_client.py        # Python脚本用于复杂API调用
└── docs/                   # 文档
    ├── implementation_plan.md # 本文档
    └── usage.md            # 使用说明
```

#### SKILL.cj实现
```cangjie
/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.examples.uctoo_api_skill

import magic.skill.BaseSkill
import magic.log.LogUtils
import std.collection.HashMap
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonNull}
import magic.utils.http.HttpUtils
import magic.utils.http.HttpException
import std.io.StringReader

/**
 * Uctoo API Skill implementation following agentskills standard
 * Converts natural language requests to uctoo-backend API calls
 */
public class UctooApiSkill <: BaseSkill {
    private var authToken: Option<String> = None
    private var baseUrl: String = "http://localhost:3000"

    /**
     * Constructor that accepts SkillManifest for progressive loading
     */
    public init(
        name: String,
        description: String,
        license: Option<String>,
        compatibility: Option<String>,
        metadata: HashMap<String, String>,
        allowedTools: Option<String>,
        instructions: String,
        skillPath: String
    ) {
        super(
            name: name,
            description: description,
            license: license,
            compatibility: compatibility,
            metadata: metadata,
            allowedTools: allowedTools,
            instructions: instructions,
            skillPath: skillPath
        )

        // 从环境变量或metadata中获取base URL
        if (metadata.contains("base_url")) {
            baseUrl = metadata["base_url"]
        }
    }

    /**
     * Execute skill with given arguments
     * Supports multiple parameter formats for compatibility
     */
    override public func execute(args: HashMap<String, JsonValue>): String {
        LogUtils.info("[UctooApiSkill.execute] Executing with arguments: ${args.toString()}")

        try {
            // 支持多种参数格式
            let requestText = extractRequestText(args)

            // 处理认证请求
            if (isAuthRequest(requestText)) {
                return handleAuthRequest(requestText, args)
            }

            // 处理其他API请求
            return handleApiRequest(requestText, args)
        } catch (ex: Exception) {
            LogUtils.error("[UctooApiSkill.execute] Error: ${ex.message}")
            return formatErrorResponse(ex.message)
        }
    }

    /**
     * Extract request text from various parameter formats
     */
    private func extractRequestText(args: HashMap<String, JsonValue>): String {
        // 支持"request"、"query"、"question"参数
        if (let Some(requestValue) <- args.get("request")) {
            return extractStringValue(requestValue)
        } else if (let Some(queryValue) <- args.get("query")) {
            return extractStringValue(queryValue)
        } else if (let Some(questionValue) <- args.get("question")) {
            return extractStringValue(questionValue)
        } else if (let Some(usernameValue) <- args.get("username")) {
            // 直接的用户名/密码参数
            let username = extractStringValue(usernameValue)
            let password = if (let Some(pwdValue) <- args.get("password")) {
                extractStringValue(pwdValue)
            } else {
                ""
            }
            return "login with username ${username} and password ${password}"
        }

        return ""
    }

    /**
     * Extract string value from JsonValue
     */
    private func extractStringValue(value: JsonValue): String {
        match (value) {
            case JsonString(str) => str
            case _ => value.toString()
        }
    }

    /**
     * Check if request is an authentication request
     */
    private func isAuthRequest(request: String): Bool {
        let lowerRequest = request.toAsciiLower()
        return lowerRequest.contains("login") || lowerRequest.contains("sign in") ||
               lowerRequest.contains("register") || lowerRequest.contains("create account")
    }

    /**
     * Handle authentication requests
     */
    private func handleAuthRequest(request: String, args: HashMap<String, JsonValue>): String {
        LogUtils.info("[UctooApiSkill.handleAuthRequest] Processing auth request")

        // 从参数中提取用户名和密码
        let username = if (let Some(userValue) <- args.get("username")) {
            extractStringValue(userValue)
        } else {
            extractUsernameFromRequest(request)
        }

        let password = if (let Some(pwdValue) <- args.get("password")) {
            extractStringValue(pwdValue)
        } else {
            extractPasswordFromRequest(request)
        }

        if (username.isEmpty() || password.isEmpty()) {
            return formatErrorResponse("Username and password are required")
        }

        // 调用登录API
        let loginUrl = "${baseUrl}/api/uctoo/auth/login"
        let requestBody = buildJsonBody([
            ("username", username),
            ("password", password)
        ])

        let headers = HashMap<String, String>()
        headers.add("Content-Type", "application/json")

        match (HttpUtils.post(loginUrl, headers, requestBody)) {
            case Some(response) =>
                LogUtils.info("[UctooApiSkill.handleAuthRequest] Login response: ${response}")
                // 检查响应是否成功
                if (response.contains("token") || response.contains("success")) {
                    // 提取token并保存
                    authToken = extractTokenFromResponse(response)
                    return formatSuccessResponse("Login successful", response)
                } else {
                    return formatErrorResponse("Login failed: Invalid credentials")
                }
            case None =>
                return formatErrorResponse("Login failed: No response from server")
        }
    }

    /**
     * Handle general API requests
     */
    private func handleApiRequest(request: String, args: HashMap<String, JsonValue>): String {
        LogUtils.info("[UctooApiSkill.handleApiRequest] Processing API request")

        // 简化的API请求处理
        // 实际实现中应该根据请求内容映射到具体的API端点

        // 检查是否已认证
        if (authToken.isNone()) {
            return formatErrorResponse("Authentication required. Please login first.")
        }

        // 根据请求内容映射到API端点
        let (endpoint, method, params) = mapRequestToEndpoint(request)

        let apiUrl = "${baseUrl}${endpoint}"
        let headers = HashMap<String, String>()
        headers.add("Content-Type", "application/json")
        headers.add("Authorization", "Bearer ${authToken.getOrThrow()}")

        let requestBody = if (params.size > 0) {
            buildJsonBody(params)
        } else {
            "{}"
        }

        match (HttpUtils.post(apiUrl, headers, requestBody)) {
            case Some(response) =>
                return formatSuccessResponse("API request completed", response)
            case None =>
                return formatErrorResponse("API request failed: No response from server")
        }
    }

    /**
     * Map natural language request to API endpoint
     */
    private func mapRequestToEndpoint(request: String): (String, String, Array<(String, String)>) {
        let lowerRequest = request.toAsciiLower()

        if (lowerRequest.contains("user")) {
            return ("/api/uctoo/uctoo_user/getList", "POST", [])
        } else if (lowerRequest.contains("product")) {
            return ("/api/uctoo/product/getList", "POST", [])
        } else if (lowerRequest.contains("order")) {
            return ("/api/uctoo/order/getList", "POST", [])
        }

        // 默认返回健康检查端点
        return ("/api/hello", "GET", [])
    }

    /**
     * Extract username from request string
     */
    private func extractUsernameFromRequest(request: String): String {
        let lowerRequest = request.toAsciiLower()

        if (lowerRequest.contains("username") || lowerRequest.contains("account")) {
            let parts = request.split(" ")
            for (i in 0..parts.size) {
                if (parts[i].toAsciiLower() == "username" || parts[i].toAsciiLower() == "account") {
                    if (i + 1 < parts.size) {
                        return parts[i + 1].replace(",", "").replace(".", "").trimAscii()
                    }
                }
            }
        }

        return ""
    }

    /**
     * Extract password from request string
     */
    private func extractPasswordFromRequest(request: String): String {
        let lowerRequest = request.toAsciiLower()

        if (lowerRequest.contains("password")) {
            let parts = request.split("password")
            if (parts.size > 1) {
                let afterKeyword = parts[1].trimAscii()
                let words = afterKeyword.split(" ")
                if (words.size > 0) {
                    return words[0].trimAscii()
                }
            }
        }

        return ""
    }

    /**
     * Extract token from API response
     */
    private func extractTokenFromResponse(response: String): String {
        // 简化的token提取逻辑
        // 实际实现中应该根据响应格式正确提取token
        if (response.contains("\"token\"")) {
            let parts = response.split("\"token\"")
            if (parts.size > 1) {
                let afterToken = parts[1].trimAscii()
                if (afterToken.startsWith(":")) {
                    let tokenPart = afterToken[1..].trimAscii()
                    if (tokenPart.startsWith("\"")) {
                        let endQuote = tokenPart.indexOf("\"", 1)
                        if (endQuote > 0) {
                            return tokenPart[1..endQuote]
                        }
                    }
                }
            }
        }

        return ""
    }

    /**
     * Build JSON body from parameters
     */
    private func buildJsonBody(params: Array<(String, String)>): String {
        let sb = StringBuilder()
        sb.append("{")
        for (i in 0..params.size) {
            let (key, value) = params[i]
            sb.append("\"${key}\":\"${value}\"")
            if (i < params.size - 1) {
                sb.append(",")
            }
        }
        sb.append("}")
        return sb.toString()
    }

    /**
     * Format success response
     */
    private func formatSuccessResponse(message: String, data: String): String {
        return "{\"status\":\"success\",\"message\":\"${message}\",\"data\":${data}}"
    }

    /**
     * Format error response
     */
    private func formatErrorResponse(error: String): String {
        return "{\"status\":\"error\",\"message\":\"${error}\"}"
    }
}
```

### 方案二：脚本化实现（备选）

#### 架构设计
```
uctoo_api_skill/
├── SKILL.md                 # 技能定义
├── SKILL.cj                 # 技能包装器
├── scripts/                 # 可执行脚本
│   ├── api_client.py        # Python API客户端
│   └── requirements.txt       # Python依赖
└── docs/                   # 文档
    ├── implementation_plan.md
    └── usage.md
```

#### SKILL.cj实现（脚本包装器）
```cangjie
/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.examples.uctoo_api_skill

import magic.skill.BaseSkill
import magic.log.LogUtils
import std.collection.HashMap
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}
import magic.utils.newProcess
import std.io.StringReader

/**
 * Uctoo API Skill - Script wrapper implementation
 * Delegates actual API calls to Python script
 */
public class UctooApiSkill <: BaseSkill {
    private let scriptPath: String

    public init(
        name: String,
        description: String,
        license: Option<String>,
        compatibility: Option<String>,
        metadata: HashMap<String, String>,
        allowedTools: Option<String>,
        instructions: String,
        skillPath: String
    ) {
        super(
            name: name,
            description: description,
            license: license,
            compatibility: compatibility,
            metadata: metadata,
            allowedTools: allowedTools,
            instructions: instructions,
            skillPath: skillPath
        )

        // 设置脚本路径
        scriptPath = "${skillPath}/scripts/api_client.py"
    }

    /**
     * Execute skill by calling Python script
     */
    override public func execute(args: HashMap<String, JsonValue>): String {
        LogUtils.info("[UctooApiSkill.execute] Executing with arguments: ${args.toString()}")

        // 构建命令行参数
        let cmdArgs = ArrayList<String>()
        cmdArgs.add("python3")
        cmdArgs.add(scriptPath)

        // 添加参数
        for ((key, value) in args) {
            cmdArgs.add("--${key}")
            cmdArgs.add(value.toString())
        }

        try {
            // 执行Python脚本
            let process = newProcess("python3", cmdArgs.toArray(), redirectErr: true)
            let output = StringReader(process.stdOutPipe).readToEnd()
            let exitCode = process.wait()

            if (exitCode == 0) {
                LogUtils.info("[UctooApiSkill.execute] Script executed successfully")
                return output
            } else {
                let errorOutput = StringReader(process.stdErrPipe).readToEnd()
                LogUtils.error("[UctooApiSkill.execute] Script failed: ${errorOutput}")
                return "{\"status\":\"error\",\"message\":\"Script execution failed: ${errorOutput}\"}"
            }
        } catch (ex: Exception) {
            LogUtils.error("[UctooApiSkill.execute] Error: ${ex.message}")
            return "{\"status\":\"error\",\"message\":\"${ex.message}\"}"
        }
    }
}
```

#### Python API客户端（scripts/api_client.py）
```python
#!/usr/bin/env python3
"""
Uctoo API Client - Python implementation
Handles HTTP requests to uctoo-backend API
"""

import argparse
import json
import requests
import sys

class UctooAPIClient:
    def __init__(self, base_url="http://localhost:3000"):
        self.base_url = base_url
        self.auth_token = None

    def login(self, username, password):
        """Login to get authentication token"""
        url = f"{self.base_url}/api/uctoo/auth/login"
        data = {
            "username": username,
            "password": password
        }

        try:
            response = requests.post(url, json=data)
            if response.status_code == 200:
                result = response.json()
                if "token" in result:
                    self.auth_token = result["token"]
                    return json.dumps({
                        "status": "success",
                        "message": "Login successful",
                        "data": result
                    })
                else:
                    return json.dumps({
                        "status": "error",
                        "message": "Login failed: Invalid credentials"
                    })
            else:
                return json.dumps({
                    "status": "error",
                    "message": f"Login failed: HTTP {response.status_code}"
                })
        except Exception as e:
            return json.dumps({
                "status": "error",
                "message": f"Login failed: {str(e)}"
            })

    def get_users(self):
        """Get list of users"""
        if not self.auth_token:
            return json.dumps({
                "status": "error",
                "message": "Authentication required"
            })

        url = f"{self.base_url}/api/uctoo/uctoo_user/getList"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.auth_token}"
        }

        try:
            response = requests.post(url, json={}, headers=headers)
            if response.status_code == 200:
                return json.dumps({
                    "status": "success",
                    "message": "Users retrieved successfully",
                    "data": response.json()
                })
            else:
                return json.dumps({
                    "status": "error",
                    "message": f"Failed to get users: HTTP {response.status_code}"
                })
        except Exception as e:
            return json.dumps({
                "status": "error",
                "message": f"Failed to get users: {str(e)}"
            })

def main():
    parser = argparse.ArgumentParser(description='Uctoo API Client')
    parser.add_argument('--username', type=str, help='Username for login')
    parser.add_argument('--password', type=str, help='Password for login')
    parser.add_argument('--request', type=str, help='Natural language request')
    parser.add_argument('--query', type=str, help='Query parameter')
    parser.add_argument('--action', type=str, default='help', help='Action to perform')

    args = parser.parse_args()

    client = UctooAPIClient()

    # 处理登录请求
    if args.username and args.password:
        result = client.login(args.username, args.password)
        print(result)
        return

    # 处理其他请求
    if args.request or args.query:
        request_text = args.request or args.query
        lower_request = request_text.lower()

        if 'user' in lower_request:
            result = client.get_users()
            print(result)
            return

    # 默认帮助信息
    print(json.dumps({
        "status": "info",
        "message": "Uctoo API Client - Use --username and --password to login, or --request to make API calls"
    }))

if __name__ == "__main__":
    main()
```

## 方案对比

| 特性 | 方案一（内联实现） | 方案二（脚本化） |
|------|---------------------|-------------------|
| **性能** | 高（直接HTTP调用） | 中（需要进程间通信） |
| **依赖** | 仅依赖agentskills-runtime | 需要Python环境 |
| **维护性** | 高（单一语言） | 中（多语言混合） |
| **兼容性** | 完全符合agentskills标准 | 需要额外依赖 |
| **复杂度** | 中（需要实现HTTP客户端） | 低（Python处理HTTP） |
| **调试难度** | 中（仓颉语言调试） | 低（Python调试简单） |

## 推荐方案

**推荐使用方案一（完全符合agentskills标准的内联实现）**，原因如下：

1. **完全符合agentskills标准**：不依赖外部脚本，直接使用agentskills-runtime提供的HttpUtils
2. **性能最优**：避免了进程间通信的开销
3. **部署简单**：不需要额外的Python环境配置
4. **维护性好**：单一语言实现，便于维护和调试
5. **扩展性强**：可以方便地添加新的API端点和功能

## 实施步骤

### 阶段一：基础实现
1. 创建SKILL.cj文件，实现基础的execute方法
2. 实现认证功能（login）
3. 实现基本的API调用功能
4. 测试登录功能

### 阶段二：功能完善
1. 实现自然语言处理（NLP）
2. 实现API端点映射
3. 添加错误处理和重试机制
4. 完善日志记录

### 阶段三：测试和优化
1. 编写单元测试
2. 进行集成测试
3. 性能优化
4. 文档完善

## 注意事项

1. **API端点规范**：严格遵循uctooAPI设计规范，仅使用GET和POST方法
2. **认证机制**：使用JWT token进行认证
3. **错误处理**：提供清晰的错误信息和恢复建议
4. **日志记录**：记录关键操作和错误，便于调试
5. **参数验证**：验证所有输入参数，防止注入攻击
6. **兼容性**：保持与现有MCP服务器实现的兼容性

## 待确认事项

1. **方案选择**：确认使用方案一还是方案二
2. **API端点**：确认需要支持哪些API端点
3. **认证方式**：确认是否需要支持JWT token认证
4. **错误处理**：确认错误处理的具体要求
5. **测试环境**：确认测试环境的配置和可用性

## 参考资料

1. `apps/agentskills-runtime/docs/skill-development.md` - 技能开发指南
2. `apps/agentskills-runtime/docs/agentskills-api-reference.md` - API参考文档
3. `apps/agentskills-runtime/src/examples/uctoo_api_skill/DEPLOYMENT.md` - 部署指南
4. `apps/backend/docs/uctooAPI设计规范.md` - API设计规范
5. `specs/003-agentskills-enhancement/` - agentskills增强规范
