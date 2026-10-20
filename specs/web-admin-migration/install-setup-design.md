# agentskills-runtime 安装配置功能设计

## 文档信息
- **项目名称**: uctoo v4 web管理后台迁移
- **功能名称**: agentskills-runtime 安装配置功能
- **版本**: 1.0
- **创建日期**: 2026-03-30
- **作者**: SDD Agent
- **状态**: 设计完成

## 1. 功能概述

### 1.1 设计目标
提供一个图形化的安装配置界面，引导用户完成 agentskills-runtime 的完整安装配置流程，最终使 runtime 正确启动并为 web 项目提供后端 API 服务。

### 1.2 设计原则
- **渐进式引导**：分步骤引导用户完成配置
- **自动化检测**：自动检测系统环境和依赖服务
- **可视化反馈**：提供清晰的进度和状态显示
- **容错设计**：支持配置失败回滚和重试
- **用户友好**：提供默认配置和详细说明

## 2. 系统架构

### 2.1 整体架构
```
┌─────────────────────────────────────────────────────────────┐
│                    安装配置系统                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              install.html (静态入口)                   │  │
│  │  - 环境检测                                             │  │
│  │  - Mock 服务启动                                        │  │
│  │  - 基础配置引导                                         │  │
│  │  - Web 服务启动                                         │  │
│  └───────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              setup.vue (动态配置)                      │  │
│  │  - 实时环境检测                                         │  │
│  │  - 服务状态监控                                         │  │
│  │  - 配置管理                                             │  │
│  │  - 服务控制                                             │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│              agentskills-runtime                            │
│  - PostgreSQL 数据库                                        │
│  - Redis 缓存（可选）                                       │
│  - SSL 证书                                                 │
│  - API 服务                                                 │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 技术栈
| 组件 | 技术选型 | 说明 |
|------|---------|------|
| 静态页面 | HTML + CSS + JavaScript | 无需构建，直接访问 |
| 动态页面 | Vue 3 + TypeScript | 提供动态交互能力 |
| Mock 服务 | vite-plugin-mock | 提供安装配置阶段的数据支持 |
| 状态管理 | Pinia | 管理配置状态 |
| UI 组件 | @opentiny/vue | 提供美观的 UI 组件 |
| HTTP 客户端 | axios | API 调用 |
| 进程管理 | Node.js child_process | 启动和管理服务进程 |

## 3. 详细设计

### 3.1 install.html 设计

#### 3.1.1 页面结构
```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>AgentSkills Runtime 安装配置</title>
    <link rel="stylesheet" href="install.css">
</head>
<body>
    <div id="app">
        <!-- 步骤导航 -->
        <nav class="steps-nav">
            <div class="step" data-step="1">环境检测</div>
            <div class="step" data-step="2">数据库配置</div>
            <div class="step" data-step="3">SSL 配置</div>
            <div class="step" data-step="4">API 密钥</div>
            <div class="step" data-step="5">管理员账号</div>
            <div class="step" data-step="6">启动服务</div>
        </nav>

        <!-- 内容区域 -->
        <main class="content">
            <!-- 步骤 1: 环境检测 -->
            <section id="step-1" class="step-content">
                <h2>环境检测</h2>
                <div class="check-list">
                    <div class="check-item" id="check-nodejs">
                        <span class="label">Node.js</span>
                        <span class="status"></span>
                    </div>
                    <div class="check-item" id="check-postgresql">
                        <span class="label">PostgreSQL</span>
                        <span class="status"></span>
                    </div>
                    <div class="check-item" id="check-redis">
                        <span class="label">Redis</span>
                        <span class="status"></span>
                    </div>
                    <div class="check-item" id="check-ports">
                        <span class="label">端口检测</span>
                        <span class="status"></span>
                    </div>
                </div>
            </section>

            <!-- 步骤 2-6 类似结构 -->
        </main>

        <!-- 操作按钮 -->
        <footer class="actions">
            <button id="prev-btn" class="btn-secondary">上一步</button>
            <button id="next-btn" class="btn-primary">下一步</button>
        </footer>
    </div>
    <script src="install.js"></script>
</body>
</html>
```

#### 3.1.2 功能模块

**环境检测模块**：
```javascript
// install.js
class EnvironmentChecker {
    async checkNodeJS() {
        // 检测 Node.js 版本
        const version = await this.executeCommand('node --version');
        return {
            installed: true,
            version: version,
            required: '>= 18.0.0',
            passed: this.compareVersion(version, '18.0.0') >= 0
        };
    }

    async checkPostgreSQL() {
        // 检测 PostgreSQL 服务
        try {
            const result = await this.executeCommand('psql --version');
            return {
                installed: true,
                version: result,
                running: await this.checkServiceRunning('postgresql')
            };
        } catch (error) {
            return { installed: false };
        }
    }

    async checkRedis() {
        // 检测 Redis 服务
        try {
            const result = await this.executeCommand('redis-cli ping');
            return {
                installed: true,
                running: result === 'PONG'
            };
        } catch (error) {
            return { installed: false };
        }
    }

    async checkPorts() {
        // 检测端口占用
        const ports = [443, 5432, 6379, 8080];
        const results = {};
        for (const port of ports) {
            results[port] = await this.isPortAvailable(port);
        }
        return results;
    }
}
```

**Mock 服务管理**：
```javascript
class MockServiceManager {
    async startMock() {
        // 启动 mock 服务
        return await this.executeCommand('npm run mock');
    }

    async stopMock() {
        // 停止 mock 服务
        return await this.executeCommand('npm run mock:stop');
    }

    async getMockStatus() {
        // 获取 mock 服务状态
        return await fetch('/mock/status').then(r => r.json());
    }
}
```

**配置管理模块**：
```javascript
class ConfigManager {
    async saveConfig(config) {
        // 保存配置到 localStorage
        localStorage.setItem('install-config', JSON.stringify(config));
        
        // 同时保存到文件（通过 mock API）
        await fetch('/api/config/save', {
            method: 'POST',
            body: JSON.stringify(config)
        });
    }

    async loadConfig() {
        // 加载配置
        const localConfig = localStorage.getItem('install-config');
        if (localConfig) {
            return JSON.parse(localConfig);
        }
        
        // 从文件加载
        const response = await fetch('/api/config/load');
        return await response.json();
    }

    async generateEnvFile(config) {
        // 生成 .env 文件
        const envContent = this.buildEnvContent(config);
        await fetch('/api/config/generate-env', {
            method: 'POST',
            body: envContent
        });
    }
}
```

**管理员账号创建模块**：
```javascript
class AdminAccountManager {
    async createAdminAccount(account) {
        // 创建管理员账号
        const response = await fetch('/api/setup/create-admin', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                email: account.email,
                password: account.password,
                name: account.name || 'Admin',
                role: 'admin'
            })
        });
        
        const result = await response.json();
        if (result.code === 200) {
            // 保存管理员信息到配置
            await this.saveConfig({ adminEmail: account.email });
            return { success: true, message: '管理员账号创建成功' };
        } else {
            return { success: false, message: result.message };
        }
    }

    async validatePassword(password) {
        // 密码强度验证
        const rules = {
            minLength: password.length >= 8,
            hasUpper: /[A-Z]/.test(password),
            hasLower: /[a-z]/.test(password),
            hasNumber: /[0-9]/.test(password),
            hasSpecial: /[!@#$%^&*]/.test(password)
        };
        
        return {
            valid: Object.values(rules).every(r => r),
            rules: rules,
            strength: this.calculateStrength(rules)
        };
    }

    calculateStrength(rules) {
        const score = Object.values(rules).filter(r => r).length;
        if (score >= 5) return 'strong';
        if (score >= 3) return 'medium';
        return 'weak';
    }
}
```

### 3.2 setup.vue 设计

#### 3.2.1 组件结构
```vue
<template>
  <div class="setup-container">
    <!-- 顶部状态栏 -->
    <header class="status-bar">
      <div class="runtime-status">
        <span :class="runtimeStatus">{{ runtimeStatusText }}</span>
      </div>
      <div class="actions">
        <button @click="restartRuntime">重启服务</button>
        <button @click="stopRuntime">停止服务</button>
      </div>
    </header>

    <!-- 主要内容 -->
    <main class="setup-content">
      <el-tabs v-model="activeTab">
        <!-- 环境检测 -->
        <el-tab-pane label="环境检测" name="environment">
          <EnvironmentCheck />
        </el-tab-pane>

        <!-- 配置管理 -->
        <el-tab-pane label="配置管理" name="config">
          <ConfigManagement />
        </el-tab-pane>

        <!-- 服务监控 -->
        <el-tab-pane label="服务监控" name="monitor">
          <ServiceMonitor />
        </el-tab-pane>

        <!-- 日志查看 -->
        <el-tab-pane label="日志查看" name="logs">
          <LogViewer />
        </el-tab-pane>
      </el-tabs>
    </main>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import EnvironmentCheck from './components/EnvironmentCheck.vue';
import ConfigManagement from './components/ConfigManagement.vue';
import ServiceMonitor from './components/ServiceMonitor.vue';
import LogViewer from './components/LogViewer.vue';

const activeTab = ref('environment');
const runtimeStatus = ref('stopped');

// 检测 runtime 状态
onMounted(async () => {
  await checkRuntimeStatus();
  setInterval(checkRuntimeStatus, 5000); // 每 5 秒检测一次
});

async function checkRuntimeStatus() {
  try {
    const response = await fetch('/api/v1/uctoo/health');
    runtimeStatus.value = response.ok ? 'running' : 'error';
  } catch (error) {
    runtimeStatus.value = 'stopped';
  }
}
</script>
```

#### 3.2.2 子组件设计

**EnvironmentCheck.vue**：
```vue
<template>
  <div class="environment-check">
    <h3>系统环境检测</h3>
    
    <div class="check-items">
      <div v-for="check in checks" :key="check.name" class="check-item">
        <div class="check-header">
          <span class="check-name">{{ check.label }}</span>
          <el-tag :type="check.passed ? 'success' : 'danger'">
            {{ check.passed ? '通过' : '未通过' }}
          </el-tag>
        </div>
        <div class="check-detail">
          <p>当前版本: {{ check.current }}</p>
          <p>要求版本: {{ check.required }}</p>
        </div>
      </div>
    </div>

    <el-button @click="runChecks" type="primary">重新检测</el-button>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';

const checks = ref([
  { name: 'nodejs', label: 'Node.js', passed: false, current: '', required: '>= 18.0.0' },
  { name: 'postgresql', label: 'PostgreSQL', passed: false, current: '', required: '>= 14.0' },
  { name: 'redis', label: 'Redis', passed: false, current: '', required: '>= 6.0' },
]);

async function runChecks() {
  // 执行环境检测
  const response = await fetch('/api/setup/check-environment');
  const results = await response.json();
  checks.value = results;
}
</script>
```

**ConfigManagement.vue**：
```vue
<template>
  <div class="config-management">
    <h3>配置管理</h3>
    
    <el-form :model="config" label-width="120px">
      <!-- 数据库配置 -->
      <el-form-item label="数据库主机">
        <el-input v-model="config.dbHost" />
      </el-form-item>
      <el-form-item label="数据库端口">
        <el-input v-model="config.dbPort" />
      </el-form-item>
      <el-form-item label="数据库名称">
        <el-input v-model="config.dbName" />
      </el-form-item>
      
      <!-- SSL 配置 -->
      <el-form-item label="SSL 证书">
        <el-upload :on-change="handleCertUpload">
          <el-button>上传证书</el-button>
        </el-upload>
      </el-form-item>
      
      <!-- API 密钥配置 -->
      <el-form-item label="StepFun API Key">
        <el-input v-model="config.stepfunApiKey" type="password" />
      </el-form-item>
      
      <el-form-item>
        <el-button type="primary" @click="saveConfig">保存配置</el-button>
        <el-button @click="testConfig">测试配置</el-button>
      </el-form-item>
    </el-form>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';

const config = ref({
  dbHost: 'localhost',
  dbPort: '5432',
  dbName: 'uctoo',
  stepfunApiKey: '',
});

async function saveConfig() {
  await fetch('/api/setup/save-config', {
    method: 'POST',
    body: JSON.stringify(config.value)
  });
}

async function testConfig() {
  const response = await fetch('/api/setup/test-config', {
    method: 'POST',
    body: JSON.stringify(config.value)
  });
  const result = await response.json();
  // 显示测试结果
}
</script>
```

**ServiceMonitor.vue**：
```vue
<template>
  <div class="service-monitor">
    <h3>服务监控</h3>
    
    <div class="services">
      <div v-for="service in services" :key="service.name" class="service-item">
        <div class="service-header">
          <span class="service-name">{{ service.name }}</span>
          <el-tag :type="service.status === 'running' ? 'success' : 'danger'">
            {{ service.status }}
          </el-tag>
        </div>
        <div class="service-metrics">
          <p>CPU: {{ service.cpu }}%</p>
          <p>内存: {{ service.memory }}MB</p>
          <p>运行时间: {{ service.uptime }}</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';

const services = ref([
  { name: 'agentskills-runtime', status: 'stopped', cpu: 0, memory: 0, uptime: '' },
  { name: 'PostgreSQL', status: 'stopped', cpu: 0, memory: 0, uptime: '' },
  { name: 'Redis', status: 'stopped', cpu: 0, memory: 0, uptime: '' },
]);

onMounted(() => {
  setInterval(updateServiceStatus, 3000);
});

async function updateServiceStatus() {
  const response = await fetch('/api/setup/service-status');
  services.value = await response.json();
}
</script>
```

**LogViewer.vue**：
```vue
<template>
  <div class="log-viewer">
    <h3>日志查看</h3>
    
    <div class="log-controls">
      <el-select v-model="logType">
        <el-option label="全部" value="all" />
        <el-option label="错误" value="error" />
        <el-option label="警告" value="warn" />
        <el-option label="信息" value="info" />
      </el-select>
      <el-button @click="clearLogs">清空日志</el-button>
    </div>
    
    <div class="log-content">
      <div v-for="log in filteredLogs" :key="log.id" :class="['log-item', log.level]">
        <span class="log-time">{{ log.time }}</span>
        <span class="log-level">[{{ log.level }}]</span>
        <span class="log-message">{{ log.message }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';

const logs = ref([]);
const logType = ref('all');

const filteredLogs = computed(() => {
  if (logType.value === 'all') return logs.value;
  return logs.value.filter(log => log.level === logType.value);
});

async function loadLogs() {
  const response = await fetch('/api/setup/logs');
  logs.value = await response.json();
}
</script>
```

### 3.3 Mock API 设计

#### 3.3.1 Mock API 端点
```typescript
// mock/setup.ts
export default [
  // 环境检测
  {
    url: '/api/setup/check-environment',
    method: 'get',
    response: () => {
      return {
        code: 200,
        data: [
          { name: 'nodejs', label: 'Node.js', passed: true, current: 'v18.17.0', required: '>= 18.0.0' },
          { name: 'postgresql', label: 'PostgreSQL', passed: true, current: 'v14.5', required: '>= 14.0' },
          { name: 'redis', label: 'Redis', passed: false, current: '', required: '>= 6.0' },
        ]
      };
    }
  },

  // 配置保存
  {
    url: '/api/setup/save-config',
    method: 'post',
    response: (config) => {
      // 保存配置到文件
      return { code: 200, message: '配置保存成功' };
    }
  },

  // 配置测试
  {
    url: '/api/setup/test-config',
    method: 'post',
    response: (config) => {
      // 测试配置是否正确
      return { code: 200, message: '配置测试通过' };
    }
  },

  // 服务状态
  {
    url: '/api/setup/service-status',
    method: 'get',
    response: () => {
      return {
        code: 200,
        data: [
          { name: 'agentskills-runtime', status: 'running', cpu: 15, memory: 256, uptime: '2h 30m' },
          { name: 'PostgreSQL', status: 'running', cpu: 5, memory: 128, uptime: '2h 30m' },
          { name: 'Redis', status: 'stopped', cpu: 0, memory: 0, uptime: '' },
        ]
      };
    }
  },

  // 日志获取
  {
    url: '/api/setup/logs',
    method: 'get',
    response: () => {
      return {
        code: 200,
        data: [
          { id: 1, time: '2026-03-30 10:00:00', level: 'info', message: 'Runtime started' },
          { id: 2, time: '2026-03-30 10:00:05', level: 'info', message: 'Database connected' },
          { id: 3, time: '2026-03-30 10:00:10', level: 'error', message: 'Redis connection failed' },
        ]
      };
    }
  },

  // 创建管理员账号
  {
    url: '/api/setup/create-admin',
    method: 'post',
    response: (config) => {
      const { email, password, name, role } = config.body;
      
      // 验证必填字段
      if (!email || !password) {
        return { code: 400, message: '邮箱和密码为必填项' };
      }
      
      // 验证邮箱格式
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(email)) {
        return { code: 400, message: '邮箱格式不正确' };
      }
      
      // 验证密码强度
      if (password.length < 8) {
        return { code: 400, message: '密码长度至少为8位' };
      }
      
      // 模拟创建管理员账号
      return { 
        code: 200, 
        message: '管理员账号创建成功',
        data: {
          email: email,
          name: name || 'Admin',
          role: role || 'admin',
          createdAt: new Date().toISOString()
        }
      };
    }
  }
];

## 4. 配置流程设计
    }
  }
];
```

## 4. 配置流程设计

### 4.1 完整配置流程
```
1. 用户访问 install.html
   ↓
2. 自动检测系统环境
   - Node.js 版本
   - PostgreSQL 安装和运行
   - Redis 安装和运行（可选）
   - 端口占用情况
   ↓
3. [环境不满足] → 显示安装指引
   [环境满足] → 进入下一步
   ↓
4. 配置 PostgreSQL
   - 输入数据库连接信息
   - 测试连接
   - 创建 uctoo 数据库（如不存在）
   ↓
5. 配置 Redis（可选）
   - 输入 Redis 连接信息
   - 测试连接
   ↓
6. 初始化数据库
   - 导入 SQL 初始化脚本
   - 显示进度
   - 验证结果
   ↓
7. 配置 SSL 证书
   - [开发环境] 生成自签名证书
   - [生产环境] 上传自定义证书
   ↓
8. 配置 API 密钥
   - 输入必需的 API 密钥
   - 测试 API 连接
   ↓
9. 创建管理员账号
   - 输入管理员邮箱
   - 输入管理员密码（含强度验证）
   - 确认密码
   - 创建管理员账号到数据库
   ↓
10. 生成 .env 文件
    - 根据配置生成 .env 文件
    - 显示配置预览
    ↓
11. 启动 runtime
    - 启动 agentskills-runtime 进程
    - 显示启动日志
    - 检测启动状态
    ↓
12. 验证集成
    - 测试 API 连接
    - 测试认证流程
    - 测试权限控制
    ↓
13. [全部成功] → 显示成功信息
    - 提供跳转到主应用的链接
    - 提供配置管理入口
    - 显示管理员登录信息
```

### 4.2 错误处理流程
```
[配置失败] → 显示错误信息
    ↓
提供解决方案：
    - 检查配置是否正确
    - 检查服务是否运行
    - 检查网络连接
    - 查看详细日志
    ↓
[用户修复] → 重试配置
    ↓
[重试成功] → 继续下一步
[重试失败] → 提供更多帮助信息
```

## 5. 安全设计

### 5.1 敏感信息保护
- API 密钥使用 `type="password"` 输入
- 配置文件使用加密存储
- 传输使用 HTTPS
- 不在日志中输出敏感信息

### 5.2 访问控制
- 安装配置页面仅在首次安装时可用
- 配置完成后禁用安装页面
- 提供配置访问密码保护

## 6. 性能设计

### 6.1 性能目标
- 页面加载时间 < 2 秒
- 环境检测时间 < 5 秒
- 配置保存时间 < 1 秒
- 服务启动时间 < 30 秒

### 6.2 优化策略
- 使用静态 HTML 减少构建时间
- Mock 服务提供快速响应
- 异步执行检测和配置任务
- 提供进度反馈避免用户等待

## 7. 部署设计

### 7.1 文件部署
```
web-admin/
├── install.html          # 安装配置入口
├── install.css           # 样式文件
├── install.js            # 脚本文件
├── src/
│   └── views/
│       └── setup.vue     # 动态配置页面
└── mock/
    └── setup.ts          # Mock API
```

### 7.2 访问方式
- 静态页面：`http://localhost/install.html`
- 动态页面：`http://localhost/setup`
- Mock API：`http://localhost/api/setup/*`

## 8. 测试设计

### 8.1 功能测试
- 环境检测功能测试
- 配置保存和加载测试
- 服务启动和停止测试
- 错误处理测试

### 8.2 集成测试
- 完整配置流程测试
- 与 runtime 集成测试
- 与数据库集成测试

### 8.3 用户测试
- 易用性测试
- 错误提示测试
- 帮助信息测试

## 9. 附录

### 9.1 配置示例
```env
# 数据库配置
DATABASE_URL=postgresql://postgres:password@localhost:5432/uctoo
orm_drivers=opengauss
orm_defaultDriver=opengauss

# Redis 配置
REDIS_HOST=localhost
REDIS_PORT=6379

# SSL 配置
CERT_FILE_NAME=ssl/server.crt
KEY_FILE_NAME=ssl/server.key

# API 密钥
STEPFUN_API_KEY=your_api_key
SOPHNET_API_KEY=your_api_key

# 服务配置
PORT=443
LOG_LEVEL=info
```

### 9.2 参考文档
- vite-plugin-mock 文档
- PostgreSQL 安装文档
- Redis 安装文档
- SSL 证书生成文档
