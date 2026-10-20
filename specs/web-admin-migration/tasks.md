# agentskills-runtime 安装配置功能 - 实现任务清单

## 文档信息
- **项目名称**: uctoo v4 web管理后台迁移
- **功能名称**: agentskills-runtime 安装配置功能
- **版本**: 1.0
- **创建日期**: 2026-03-30
- **作者**: SDD Agent
- **状态**: 待确认

## 任务概述
本任务清单基于 `install-setup-design.md` 设计文档，实现 agentskills-runtime 的图形化安装配置功能，包括静态安装页面（install.html）、动态配置管理页面（setup.vue）和 Mock API 支持。

**总任务数**: 6 个主任务，18 个子任务
**预计工时**: 10-14 小时
**技术栈**: HTML/CSS/JavaScript, Vue 3, TypeScript, vite-plugin-mock, @opentiny/vue

---

## 任务 1: 静态安装页面开发（install.html）

### 任务描述
开发静态安装配置入口页面，提供环境检测、数据库配置、SSL配置、API密钥配置、管理员账号创建和服务启动功能。

### 输入
- `install-setup-design.md` 第 3.1 节设计规范
- 项目技术栈：HTML + CSS + JavaScript（无需构建）

### 输出
- `install.html` - 安装配置入口页面
- `install.css` - 样式文件
- `install.js` - 脚本文件

### 验收标准
- [ ] 页面包含 6 个步骤导航（环境检测、数据库配置、SSL配置、API密钥、管理员账号、启动服务）
- [ ] 实现环境检测功能（Node.js、PostgreSQL、Redis、端口检测）
- [ ] 实现数据库配置表单（主机、端口、数据库名、用户名、密码）
- [ ] 实现 SSL 证书配置（开发环境自签名、生产环境上传）
- [ ] 实现 API 密钥配置表单（StepFun、SophNet等）
- [ ] 实现管理员账号创建表单（邮箱、密码、确认密码、密码强度验证）
- [ ] 实现服务启动功能（启动 runtime、显示日志、检测状态）
- [ ] 实现步骤导航和前进/后退控制
- [ ] 页面样式美观、响应式设计
- [ ] 支持配置保存到 localStorage

### 子任务

#### 1.1 创建页面基础结构
**描述**: 创建 install.html 的 HTML 结构，包括步骤导航、内容区域和操作按钮。

**实现要点**:
- 使用语义化 HTML 标签
- 创建 5 个步骤的内容区域（section）
- 添加步骤导航栏（nav.steps-nav）
- 添加操作按钮（上一步、下一步）
- 引入 install.css 和 install.js

**代码生成提示**:
```
创建 install.html 文件，参考 install-setup-design.md 第 3.1.1 节的页面结构。
包含完整的 HTML 骨架、步骤导航、内容区域和操作按钮。
```

#### 1.2 开发样式文件
**描述**: 创建 install.css，实现美观的页面样式和响应式设计。

**实现要点**:
- 步骤导航样式（激活状态、完成状态）
- 表单样式（输入框、按钮、提示信息）
- 检测项样式（通过/未通过状态）
- 响应式布局（适配移动端）
- 使用 CSS 变量统一主题色

**代码生成提示**:
```
创建 install.css 文件，实现安装页面的样式。
参考 tiny-pro 的设计风格，使用 @opentiny/vue 的配色方案。
```

#### 1.3 实现环境检测模块
**描述**: 开发 EnvironmentChecker 类，检测 Node.js、PostgreSQL、Redis 和端口占用。

**实现要点**:
- 实现 `checkNodeJS()` 方法：检测 Node.js 版本（>= 18.0.0）
- 实现 `checkPostgreSQL()` 方法：检测 PostgreSQL 服务
- 实现 `checkRedis()` 方法：检测 Redis 服务（可选）
- 实现 `checkPorts()` 方法：检测端口占用（443、5432、6379、8080）
- 提供检测结果可视化展示

**代码生成提示**:
```
在 install.js 中创建 EnvironmentChecker 类，参考 install-setup-design.md 第 3.1.2 节。
实现所有检测方法，返回标准化的检测结果对象。
```

#### 1.4 实现配置管理模块
**描述**: 开发 ConfigManager 类，管理配置的保存、加载和 .env 文件生成。

**实现要点**:
- 实现 `saveConfig(config)` 方法：保存到 localStorage 和 Mock API
- 实现 `loadConfig()` 方法：从 localStorage 或 Mock API 加载
- 实现 `generateEnvFile(config)` 方法：生成 .env 文件内容
- 实现配置验证逻辑

**代码生成提示**:
```
在 install.js 中创建 ConfigManager 类，参考 install-setup-design.md 第 3.1.2 节。
实现配置的持久化和 .env 文件生成功能。
```

#### 1.5 实现步骤导航和流程控制
**描述**: 开发步骤导航逻辑，控制安装流程的前进和后退。

**实现要点**:
- 实现步骤切换逻辑（显示/隐藏内容区域）
- 实现步骤状态管理（当前步骤、已完成步骤）
- 实现前进/后退按钮控制
- 实现步骤完成验证（每步必须通过验证才能继续）
- 实现最终提交和服务启动

**代码生成提示**:
```
在 install.js 中创建 InstallWizard 类，管理整个安装流程。
实现步骤导航、状态管理和流程控制逻辑。
```

#### 1.6 实现管理员账号创建模块
**描述**: 开发 AdminAccountManager 类，实现管理员账号创建和密码验证功能。

**实现要点**:
- 实现 `createAdminAccount(account)` 方法：创建管理员账号
- 实现 `validatePassword(password)` 方法：密码强度验证
- 实现 `calculateStrength(rules)` 方法：计算密码强度等级
- 实现邮箱格式验证
- 实现密码确认匹配验证
- 调用 `/api/setup/create-admin` API

**代码生成提示**:
```
在 install.js 中创建 AdminAccountManager 类，参考 install-setup-design.md 第 3.1.2 节。
实现管理员账号创建、密码强度验证等功能。
```

---

## 任务 2: 动态配置管理页面开发（setup.vue）

### 任务描述
开发 Vue 3 动态配置管理页面，提供实时环境检测、配置管理、服务监控和日志查看功能。

### 输入
- `install-setup-design.md` 第 3.2 节设计规范
- 项目技术栈：Vue 3 + TypeScript + @opentiny/vue

### 输出
- `src/views/setup.vue` - 主页面组件
- `src/views/components/EnvironmentCheck.vue` - 环境检测组件
- `src/views/components/ConfigManagement.vue` - 配置管理组件
- `src/views/components/ServiceMonitor.vue` - 服务监控组件
- `src/views/components/LogViewer.vue` - 日志查看组件

### 验收标准
- [ ] 主页面包含 4 个标签页（环境检测、配置管理、服务监控、日志查看）
- [ ] 实现实时环境检测功能（每 5 秒刷新）
- [ ] 实现配置管理功能（表单编辑、保存、测试）
- [ ] 实现服务监控功能（CPU、内存、运行时间）
- [ ] 实现日志查看功能（实时日志、过滤、清空）
- [ ] 实现服务控制功能（启动、停止、重启）
- [ ] 使用 @opentiny/vue 组件库
- [ ] 遵循 TypeScript 强类型规范

### 子任务

#### 2.1 创建主页面组件
**描述**: 创建 setup.vue 主页面，包含标签页布局和状态栏。

**实现要点**:
- 使用 `tiny-tabs` 组件实现标签页
- 实现顶部状态栏（runtime 状态、操作按钮）
- 实现 runtime 状态检测（每 5 秒检测一次）
- 实现服务控制方法（启动、停止、重启）
- 引入 4 个子组件

**代码生成提示**:
```
使用 tiny-vue-skill 生成 src/views/setup.vue 文件，参考 install-setup-design.md 第 3.2.1 节。
使用 @opentiny/vue 的 tiny-tabs 组件，实现标签页布局。
```

#### 2.2 开发环境检测组件
**描述**: 创建 EnvironmentCheck.vue，实现实时环境检测功能。

**实现要点**:
- 显示检测项列表（Node.js、PostgreSQL、Redis）
- 显示检测结果（通过/未通过、当前版本、要求版本）
- 实现"重新检测"按钮
- 调用 `/api/setup/check-environment` API

**代码生成提示**:
```
使用 tiny-vue-skill 生成 src/views/components/EnvironmentCheck.vue 文件。
参考 install-setup-design.md 第 3.2.2 节的 EnvironmentCheck.vue 设计。
```

#### 2.3 开发配置管理组件
**描述**: 创建 ConfigManagement.vue，实现配置的编辑、保存和测试。

**实现要点**:
- 使用 `tiny-form` 组件实现表单
- 实现数据库配置表单（主机、端口、数据库名）
- 实现 SSL 证书上传功能
- 实现 API 密钥配置表单（密码类型输入）
- 实现"保存配置"和"测试配置"按钮
- 调用 `/api/setup/save-config` 和 `/api/setup/test-config` API

**代码生成提示**:
```
使用 tiny-vue-skill 生成 src/views/components/ConfigManagement.vue 文件。
参考 install-setup-design.md 第 3.2.2 节的 ConfigManagement.vue 设计。
使用 @opentiny/vue 的 tiny-form、tiny-input、tiny-upload 组件。
```

#### 2.4 开发服务监控组件
**描述**: 创建 ServiceMonitor.vue，实现服务状态监控。

**实现要点**:
- 显示服务列表（agentskills-runtime、PostgreSQL、Redis）
- 显示服务状态（running/stopped）
- 显示服务指标（CPU、内存、运行时间）
- 实现定时刷新（每 3 秒）
- 调用 `/api/setup/service-status` API

**代码生成提示**:
```
使用 tiny-vue-skill 生成 src/views/components/ServiceMonitor.vue 文件。
参考 install-setup-design.md 第 3.2.2 节的 ServiceMonitor.vue 设计。
使用 @opentiny/vue 的 tiny-tag 组件显示状态。
```

#### 2.5 开发日志查看组件
**描述**: 创建 LogViewer.vue，实现实时日志查看和过滤。

**实现要点**:
- 显示日志列表（时间、级别、消息）
- 实现日志级别过滤（全部、错误、警告、信息）
- 实现"清空日志"按钮
- 实现日志自动滚动到最新
- 调用 `/api/setup/logs` API

**代码生成提示**:
```
使用 tiny-vue-skill 生成 src/views/components/LogViewer.vue 文件。
参考 install-setup-design.md 第 3.2.2 节的 LogViewer.vue 设计。
使用 @opentiny/vue 的 tiny-select 组件实现过滤。
```

---

## 任务 3: Mock API 开发

### 任务描述
开发 vite-plugin-mock 的 Mock API，为安装配置阶段提供数据支持。

### 输入
- `install-setup-design.md` 第 3.3 节设计规范
- 项目技术栈：vite-plugin-mock

### 输出
- `mock/setup.ts` - Mock API 定义文件

### 验收标准
- [ ] 实现环境检测 API（`/api/setup/check-environment`）
- [ ] 实现配置保存 API（`/api/setup/save-config`）
- [ ] 实现配置测试 API（`/api/setup/test-config`）
- [ ] 实现服务状态 API（`/api/setup/service-status`）
- [ ] 实现日志获取 API（`/api/setup/logs`）
- [ ] 实现管理员账号创建 API（`/api/setup/create-admin`）
- [ ] Mock 数据符合实际场景
- [ ] 支持 POST 和 GET 方法

### 子任务

#### 3.1 创建 Mock API 文件
**描述**: 创建 setup.ts 文件，定义所有 Mock API 端点。

**实现要点**:
- 使用 vite-plugin-mock 的标准格式
- 定义 6 个 API 端点（环境检测、配置保存、配置测试、服务状态、日志获取、管理员账号创建）
- 返回符合规范的响应格式（`{ code: 200, data: ... }`）
- 模拟真实场景的数据

**代码生成提示**:
```
创建 mock/setup.ts 文件，参考 install-setup-design.md 第 3.3.1 节。
使用 vite-plugin-mock 的格式定义所有 Mock API 端点。
```

#### 3.2 实现环境检测 Mock
**描述**: 实现 `/api/setup/check-environment` Mock API。

**实现要点**:
- 返回 Node.js、PostgreSQL、Redis 的检测结果
- 包含当前版本、要求版本、是否通过
- 模拟部分检测失败的场景（如 Redis 未安装）

**代码生成提示**:
```
在 mock/setup.ts 中实现环境检测 Mock API。
返回包含 3 个检测项的数组，每个检测项包含 name、label、passed、current、required 字段。
```

#### 3.3 实现配置管理 Mock
**描述**: 实现配置保存和测试的 Mock API。

**实现要点**:
- `/api/setup/save-config`：保存配置到文件（模拟）
- `/api/setup/test-config`：测试配置是否正确（模拟连接测试）
- 返回成功或失败的响应

**代码生成提示**:
```
在 mock/setup.ts 中实现配置保存和测试 Mock API。
模拟配置验证逻辑，返回相应的成功或失败消息。
```

#### 3.4 实现服务状态和日志 Mock
**描述**: 实现服务状态查询和日志获取的 Mock API。

**实现要点**:
- `/api/setup/service-status`：返回服务列表和状态指标
- `/api/setup/logs`：返回日志列表（包含时间、级别、消息）
- 模拟真实的服务状态和日志数据

**代码生成提示**:
```
在 mock/setup.ts 中实现服务状态和日志 Mock API。
返回包含 3 个服务的状态数据和 10 条模拟日志。
```

#### 3.5 实现管理员账号创建 Mock
**描述**: 实现 `/api/setup/create-admin` Mock API。

**实现要点**:
- 接收管理员账号信息（email、password、name、role）
- 验证必填字段（邮箱、密码）
- 验证邮箱格式
- 验证密码强度（至少8位）
- 返回创建成功或失败的响应

**代码生成提示**:
```
在 mock/setup.ts 中实现管理员账号创建 Mock API。
参考 install-setup-design.md 第 3.3.1 节的 create-admin API 设计。
实现完整的验证逻辑和响应。
```

---

## 任务 4: 路由和导航配置

### 任务描述
配置安装配置页面的路由和导航入口。

### 输入
- 项目路由配置：`src/router/`
- 项目菜单配置

### 输出
- 更新路由配置文件
- 更新菜单配置（可选）

### 验收标准
- [ ] 配置 `/setup` 路由指向 setup.vue
- [ ] 配置路由元信息（标题、权限）
- [ ] 确保路由可访问
- [ ] install.html 可通过静态方式访问

### 子任务

#### 4.1 配置 setup.vue 路由
**描述**: 在路由配置中添加 setup 页面的路由。

**实现要点**:
- 路由路径：`/setup`
- 路由组件：`() => import('@/views/setup.vue')`
- 路由元信息：`{ title: '安装配置', icon: 'setting' }`
- 不需要权限验证（安装阶段）

**代码生成提示**:
```
在 src/router/routes/modules/ 中创建 setup.ts 路由配置文件。
定义 /setup 路由，指向 setup.vue 组件。
```

#### 4.2 配置静态文件访问
**描述**: 确保 install.html 可以通过静态方式访问。

**实现要点**:
- 将 install.html、install.css、install.js 放在 public/ 目录
- 配置 Vite 静态文件服务
- 确保可以通过 `http://localhost/install.html` 访问

**代码生成提示**:
```
将 install.html、install.css、install.js 移动到 public/ 目录。
确保 Vite 配置支持静态文件访问。
```

---

## 任务 5: 集成测试和文档

### 任务描述
进行集成测试，确保安装配置功能正常工作，并编写使用文档。

### 输入
- 已完成的所有代码文件
- 测试环境

### 输出
- 测试报告
- 使用文档

### 验收标准
- [ ] install.html 可以正常访问和使用
- [ ] setup.vue 可以正常访问和使用
- [ ] Mock API 返回正确的数据
- [ ] 环境检测功能正常
- [ ] 配置保存和加载功能正常
- [ ] 管理员账号创建功能正常
- [ ] 服务监控功能正常
- [ ] 日志查看功能正常
- [ ] 编写使用文档

### 子任务

#### 5.1 功能测试
**描述**: 测试所有功能是否正常工作。

**实现要点**:
- 测试 install.html 的 6 个步骤流程
- 测试 setup.vue 的 4 个标签页功能
- 测试 Mock API 的响应
- 测试配置保存和加载
- 测试管理员账号创建
- 记录测试结果

**代码生成提示**:
```
执行功能测试，记录每个功能的测试结果。
创建测试报告文档，包含测试项、预期结果、实际结果、是否通过。
```

#### 5.2 编写使用文档
**描述**: 编写安装配置功能的使用文档。

**实现要点**:
- 说明如何访问 install.html 和 setup.vue
- 说明每个步骤的操作方法
- 说明常见问题的解决方法
- 提供配置示例

**代码生成提示**:
```
创建 docs/install-setup-guide.md 文件，编写详细的使用文档。
包含访问方式、操作步骤、配置示例、常见问题等内容。
```

---

## 任务依赖关系

```
任务 1 (静态页面) ──┐
                    │
任务 2 (动态页面) ──┼──> 任务 4 (路由配置) ──> 任务 5 (测试文档)
                    │
任务 3 (Mock API) ──┘
```

**并行开发建议**:
- 任务 1、任务 2、任务 3 可以并行开发
- 任务 4 依赖任务 1、任务 2 完成
- 任务 5 依赖所有任务完成

---

## 技术要点

### 1. 环境检测实现
- 使用 `child_process` 执行系统命令检测软件版本
- 使用端口检测库检测端口占用
- 提供友好的错误提示和安装指引

### 2. 配置管理实现
- 使用 localStorage 存储临时配置
- 通过 Mock API 模拟配置保存到文件
- 生成符合规范的 .env 文件内容

### 3. Mock API 实现
- 使用 vite-plugin-mock 提供开发阶段的 API 支持
- Mock 数据应模拟真实场景
- 支持成功和失败的响应

### 4. Vue 组件开发
- 使用 @opentiny/vue 组件库
- 遵循 TypeScript 强类型规范
- 使用 Composition API（`<script setup>`）
- 实现响应式数据绑定

### 5. 样式设计
- 参考 tiny-pro 的设计风格
- 使用 CSS 变量统一主题色
- 实现响应式布局

### 6. 管理员账号创建
- 实现密码强度验证（长度、大小写、数字、特殊字符）
- 实现邮箱格式验证
- 实现密码确认匹配验证
- 提供密码强度可视化指示器

---

## 风险和注意事项

### 1. 环境检测的跨平台兼容性
- **风险**: 不同操作系统的命令可能不同
- **解决方案**: 提供跨平台的检测方法，或提供手动输入选项

### 2. 配置安全性
- **风险**: API 密钥等敏感信息的存储和传输
- **解决方案**: 使用 `type="password"` 输入，配置文件加密存储，HTTPS 传输

### 3. Mock API 与真实 API 的切换
- **风险**: 开发阶段使用 Mock API，生产阶段需要切换到真实 API
- **解决方案**: 使用环境变量控制 API 基础路径，提供平滑切换机制

### 4. 服务启动的权限问题
- **风险**: 启动 agentskills-runtime 可能需要特定权限
- **解决方案**: 提供权限检查和提升指引，或使用服务管理工具

### 5. 管理员账号安全
- **风险**: 管理员账号密码的安全性
- **解决方案**: 密码强度验证、加密存储、HTTPS 传输、不记录明文密码

---

## 验收检查清单

### 功能验收
- [ ] install.html 可以正常访问
- [ ] install.html 的 6 个步骤可以正常执行
- [ ] setup.vue 可以正常访问
- [ ] setup.vue 的 4 个标签页功能正常
- [ ] Mock API 返回正确的数据
- [ ] 配置可以保存和加载
- [ ] 管理员账号可以正常创建
- [ ] 环境检测功能正常
- [ ] 服务监控功能正常
- [ ] 日志查看功能正常

### 代码质量验收
- [ ] 代码符合项目规范
- [ ] TypeScript 类型定义完整
- [ ] 组件使用 Composition API
- [ ] 样式使用 CSS 变量
- [ ] 代码包含必要注释

### 文档验收
- [ ] 使用文档完整
- [ ] 配置示例清晰
- [ ] 常见问题解答完整

---

## 附录

### 相关文档
- `install-setup-design.md` - 详细设计文档
- `spec.md` - 需求规格文档
- `design.md` - 技术设计文档

### 技术参考
- vite-plugin-mock 文档：https://github.com/vbenjs/vite-plugin-mock
- @opentiny/vue 文档：https://opentiny.design/
- Vue 3 文档：https://vuejs.org/
- TypeScript 文档：https://www.typescriptlang.org/

### 变更历史
| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0  | 2026-03-30 | SDD Agent | 初始版本 |
