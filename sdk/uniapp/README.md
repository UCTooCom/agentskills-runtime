# AgentSkills Runtime UniApp SDK

轻量级 SDK，用于在 UniApp 应用中与 AgentSkills Runtime 通信，实现与 AI agent 的实时聊天功能。

## 功能特性

- **HTTP API 通信**：与 AgentSkills Runtime 的 REST API 进行通信
- **WebSocket 实时通信**：实现与 AI agent 的实时聊天
- **心跳机制**：保持 WebSocket 连接的稳定性
- **自动重连**：WebSocket 连接断开时自动重连
- **错误处理**：标准化的错误处理
- **轻量级**：最小化 SDK 体积，仅包含必要功能

## 安装

### 方法一：直接复制到 uni_modules 目录

1. 复制 `agentskills-runtime-uniapp-sdk` 目录到你的 UniApp 项目的 `src/uni_modules` 目录下

2. 确保目录结构如下：

```
src/
└── uni_modules/
    └── agentskills-runtime-uniapp-sdk/
        ├── src/
        │   ├── index.js
        │   ├── client.js
        │   ├── websocket.js
        │   ├── utils.js
        │   └── constants.js
        ├── package.json
        └── README.md
```

### 方法二：通过 HBuilderX 插件市场安装

（如果发布到插件市场后）

1. 在 HBuilderX 中打开你的项目
2. 点击「工具」→「插件安装」
3. 搜索「AgentSkills Runtime UniApp SDK」并安装

## 使用方法

### 1. 初始化客户端

```javascript
import { createClient } from '@/uni_modules/agentskills-runtime-uniapp-sdk/src/index.js';

// 创建客户端实例
const client = createClient({
  baseUrl: 'http://127.0.0.1:8080', // AgentSkills Runtime API 地址
  timeout: 30000 // 请求超时时间
});

// 健康检查
async function checkHealth() {
  try {
    const result = await client.healthCheck();
    console.log('Health check:', result);
  } catch (error) {
    console.error('Health check failed:', error);
  }
}

checkHealth();
```

### 2. 使用 WebSocket 进行实时聊天

```javascript
import { createWebSocketManager } from '@/uni_modules/agentskills-runtime-uniapp-sdk/src/index.js';

// 创建 WebSocket 管理器
const wsManager = createWebSocketManager({
  wsUrl: 'ws://127.0.0.1:8080/ws/chat', // WebSocket 地址
  onMessage: (message) => {
    console.log('Received message:', message);
    // 处理接收到的消息
  },
  onError: (error) => {
    console.error('WebSocket error:', error);
    // 处理错误
  },
  onClose: (res) => {
    console.log('WebSocket closed:', res);
    // 处理连接关闭
  },
  onOpen: () => {
    console.log('WebSocket connected');
    // 处理连接打开
  }
});

// 连接 WebSocket
wsManager.connect();

// 发送消息
function sendMessage(content) {
  const message = {
    type: 'message',
    content: content,
    sender: 'user',
    timestamp: Date.now()
  };
  wsManager.send(message);
}

// 断开连接
function disconnect() {
  wsManager.disconnect();
}
```

### 3. 安装和执行技能

```javascript
// 安装技能
async function installSkill() {
  try {
    const result = await client.installSkill({
      source: 'https://gitee.com/example/skill-example.git',
      validate: true
    });
    console.log('Install skill result:', result);
  } catch (error) {
    console.error('Install skill failed:', error);
  }
}

// 执行技能
async function executeSkill() {
  try {
    const result = await client.executeSkill('skill-id', {
      parameter1: 'value1',
      parameter2: 'value2'
    });
    console.log('Execute skill result:', result);
  } catch (error) {
    console.error('Execute skill failed:', error);
  }
}
```

## 配置选项

### createClient 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| baseUrl | string | 'http://127.0.0.1:8080' | AgentSkills Runtime API 基础 URL |
| wsUrl | string | 'ws://127.0.0.1:8080/ws/chat' | WebSocket 连接 URL |
| authToken | string | undefined | 认证令牌 |
| timeout | number | 30000 | 请求超时时间（毫秒） |

### createWebSocketManager 配置选项

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| wsUrl | string | 'ws://127.0.0.1:8080/ws/chat' | WebSocket 连接 URL |
| onMessage | function | () => {} | 消息接收回调 |
| onError | function | () => {} | 错误回调 |
| onClose | function | () => {} | 连接关闭回调 |
| onOpen | function | () => {} | 连接打开回调 |
| reconnectInterval | number | 3000 | 重连间隔（毫秒） |
| maxReconnectAttempts | number | 5 | 最大重连次数 |

## 错误处理

```javascript
import { handleApiError } from '@/uni_modules/agentskills-runtime-uniapp-sdk/src/index.js';

try {
  // 执行操作
} catch (error) {
  const formattedError = handleApiError(error);
  console.error('Error:', formattedError.errmsg);
}
```

## 示例代码

### 完整聊天页面示例

```vue
<template>
  <view class="chat-container">
    <view class="chat-header">
      <text>AI 聊天</text>
    </view>
    <view class="chat-messages">
      <view 
        v-for="msg in messages" 
        :key="msg.id"
        :class="['message', msg.sender === 'user' ? 'user-message' : 'ai-message']"
      >
        <text>{{ msg.content }}</text>
      </view>
    </view>
    <view class="chat-input">
      <input 
        v-model="inputText" 
        type="text" 
        placeholder="输入消息..."
      />
      <button @click="sendMessage">发送</button>
    </view>
  </view>
</template>

<script>
import { createWebSocketManager } from '@/uni_modules/agentskills-runtime-uniapp-sdk/src/index.js';

export default {
  data() {
    return {
      messages: [],
      inputText: '',
      wsManager: null
    };
  },
  onLoad() {
    this.initWebSocket();
  },
  onUnload() {
    if (this.wsManager) {
      this.wsManager.disconnect();
    }
  },
  methods: {
    initWebSocket() {
      this.wsManager = createWebSocketManager({
        wsUrl: 'ws://127.0.0.1:8080/ws/chat',
        onMessage: (message) => {
          this.messages.push(message);
        },
        onError: (error) => {
          console.error('WebSocket error:', error);
        },
        onClose: () => {
          console.log('WebSocket closed');
        },
        onOpen: () => {
          console.log('WebSocket connected');
        }
      });
      
      this.wsManager.connect();
    },
    sendMessage() {
      if (!this.inputText.trim()) return;
      
      const message = {
        id: Date.now().toString(),
        type: 'message',
        content: this.inputText,
        sender: 'user',
        timestamp: Date.now()
      };
      
      this.messages.push(message);
      this.wsManager.send(message);
      this.inputText = '';
    }
  }
};
</script>

<style scoped>
.chat-container {
  display: flex;
  flex-direction: column;
  height: 100vh;
}

.chat-header {
  padding: 16px;
  background-color: #f5f5f5;
  border-bottom: 1px solid #e0e0e0;
}

.chat-messages {
  flex: 1;
  padding: 16px;
  overflow-y: auto;
}

.message {
  margin-bottom: 16px;
  padding: 12px;
  border-radius: 8px;
}

.user-message {
  background-color: #e3f2fd;
  align-self: flex-end;
  margin-left: 40%;
}

.ai-message {
  background-color: #f5f5f5;
  align-self: flex-start;
  margin-right: 40%;
}

.chat-input {
  display: flex;
  padding: 16px;
  border-top: 1px solid #e0e0e0;
}

input {
  flex: 1;
  padding: 12px;
  border: 1px solid #e0e0e0;
  border-radius: 4px;
  margin-right: 8px;
}

button {
  padding: 0 24px;
  background-color: #1890ff;
  color: white;
  border: none;
  border-radius: 4px;
}
</style>
```

## 注意事项

1. **确保 AgentSkills Runtime 已启动**：在使用 SDK 前，确保 AgentSkills Runtime 服务已在指定的地址和端口上运行

2. **网络权限**：确保你的 UniApp 应用有网络访问权限

3. **跨域问题**：如果 AgentSkills Runtime 运行在不同的域名或端口上，可能需要配置 CORS

4. **WebSocket 支持**：确保目标平台支持 WebSocket（微信小程序、App、H5 等均支持）

5. **错误处理**：在实际应用中，建议添加完善的错误处理和用户提示

## 兼容性

- ✅ 微信小程序
- ✅ 支付宝小程序
- ✅ 百度小程序
- ✅ 字节跳动小程序
- ✅ QQ 小程序
- ✅ 京东小程序
- ✅ 华为快应用
- ✅ App 端（iOS/Android）
- ✅ H5 端

## 版本历史

### v0.0.1
- 初始版本
- 实现 HTTP API 通信
- 实现 WebSocket 实时通信
- 添加心跳机制
- 添加自动重连功能

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个 SDK。

## 许可证

MIT
