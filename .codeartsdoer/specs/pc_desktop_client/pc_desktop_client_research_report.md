# PC 桌面客户端技术选型与开发方案研究报告

> **文档定位**：本报告为 agentskills-runtime PC 桌面客户端的规范驱动开发（SDD）初始化文档，聚焦技术选型与开发方案建议，为后续 `spec.md`（需求规格）、`design.md`（技术设计）、`tasks.md`（任务清单）的生成提供决策依据。
>
> **生成日期**：2026-08-03 | **更新日期**：2026-08-03
> **目标产物**：一款面向 toC 个人用户的 PC 桌面客户端，实现 agentskills-runtime 的开箱即用
> **规范目录**：`apps/agentskills-runtime/.codeartsdoer/specs/pc_desktop_client/`

---

## 1. 项目背景与目标

### 1.1 项目背景

agentskills-runtime 是基于仓颉语言实现的 AI 智能体技能运行时，提供 RESTful API、MCP、WebSocket 等接口，是 UCToo v4 体系的智能体内核。目前已有两种集成方式：

| 集成方式 | 位置 | 面向用户 | 使用门槛 |
|---------|------|---------|---------|
| JavaScript SDK + 二进制发行版 | `apps/web-admin/` | 开发者 | 需安装 Node.js、pnpm，执行 `start-installer.bat`，配置 `.env` |
| 手动下载二进制包 | `apps/agentskills-runtime/release/` | 高级开发者 | 需手动解压、配置 `.env`、命令行启动 |

**现状痛点**：

1. **环境依赖重**：用户需预装 Node.js ≥ 18、pnpm，并通过 `start-installer.bat` 安装前后端依赖（`pnpm install`），耗时且易失败
2. **配置工作多**：需手动配置 `.env` 文件（数据库连接、AI 模型 API Key、SSL、存储等十余项分组配置）
3. **多进程协调难**：需同时启动 NestJS 后端（端口 3000）+ Vue 前端（端口 3031）+ runtime（端口 8080/443），用户需理解进程关系
4. **面向开发者**：整个流程假设用户具备命令行、包管理、端口调试能力，无法触达 toC 个人用户
5. **已有 PC 端非真桌面**：`apps/uctoo-app-client-pc/` 虽名为 PC 客户端，实为 Vue 3 + Vite 的 Web 应用，仍需浏览器访问，未解决环境依赖问题

### 1.2 项目目标

**核心目标**：开发一款真正的 PC 桌面客户端应用，将 agentskills-runtime 使用前的所有配置工作集成掉，使 toC 个人用户能快速安装使用，达到开箱即用。

**成功标准**：

| 维度 | 指标 |
|------|------|
| 安装体验 | 双击安装包即可完成安装，无需预装任何运行时环境 |
| 启动体验 | 双击桌面图标即可启动，自动拉起 runtime 服务，无需命令行 |
| 配置体验 | 首次启动向导化配置（数据库、AI Key 等关键项），其余采用合理默认值 |
| 体积 | 安装包 ≤ 250MB（含 runtime 二进制 ~170MB + 客户端壳 ~50MB + 资源） |
| 平台 | 首版支持 Windows x64，后续支持 macOS x64/ARM64、Linux x64 |
| 复用 | 最大化复用现有 `web-admin/web` 的 Vue 3 前端代码与 `@opencangjie/skills` SDK |

### 1.3 与现有体系的关系

```
┌─────────────────────────────────────────────────────────────────┐
│                    UCToo v4 产品矩阵                            │
│                                                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐  │
│  │  toC 个人用户     │  │  开发者/企业      │  │  嵌入式集成   │  │
│  │                  │  │                  │  │              │  │
│  │  ★ PC 桌面客户端  │  │  web-admin      │  │  JS/Python/  │  │
│  │  (本项目)        │  │  (Vue+NestJS)    │  │  Go SDK      │  │
│  │                  │  │                  │  │              │  │
│  └────────┬─────────┘  └────────┬─────────┘  └──────┬───────┘  │
│           └────────────┬────────┴───────────────────┘          │
│                        ▼                                        │
│           ┌────────────────────────────────┐                    │
│           │   agentskills-runtime (仓颉)    │                    │
│           │   二进制发行版 + RESTful API    │                    │
│           └────────────────────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

PC 桌面客户端是产品矩阵中面向 toC 用户的最后一环，与 web-admin 共享 runtime 内核与前端业务代码，但交付形态从"Web 应用 + 脚本"升级为"原生桌面安装包"。

---

## 2. 现状分析

### 2.1 现有集成方式深度剖析

#### 2.1.1 web-admin 集成方式

> **修正说明**：`apps/web-admin/` 是一个 monorepo 项目，其中 `web/` 是前端（Vue 3 + TypeScript + OpenTiny Vue + Pinia ORM），`nestJs/` 仅用于快捷安装过程（端口 3000），并非主工程后端。uctoo-admin 项目与 Java 没有关系，runtime 后端由仓颉语言实现。

```
web-admin/
├── nestJs/                 # NestJS 后端（仅用于安装过程，端口 3000）
├── web/                    # Vue 3 前端（端口 3031）
│   ├── package.json        # 依赖 @opencangjie/skills SDK
│   └── src/store/models/   # Pinia ORM 模型（UMI 同构）
└── start-installer.bat     # 一键安装脚本
```

**工作流程**（`start-installer.bat`）：
1. 检查 Node.js → 检查 pnpm
2. `cd nestJs && pnpm install` → `pnpm run start:dev`（启动后端）
3. `cd web && pnpm install` → `pnpm run start`（启动前端）
4. 轮询端口 3000、3031 就绪
5. 打开浏览器访问 `http://localhost:3031/install.html`

**痛点**：步骤 1 的环境检查可能失败；步骤 2、3 的依赖安装耗时（数分钟）且受网络影响；整个过程需要保持命令行窗口开启。

#### 2.1.2 JavaScript SDK 集成方式

`@opencangjie/skills` SDK（`apps/agentskills-runtime/sdk/javascript/`）：
- `postinstall` 脚本自动下载 runtime 二进制发行版（~170MB）
- 提供 CLI 工具 `skills`：`install-runtime`、`start`、`restart` 等
- 支持 win32-x64、darwin-x64/arm64、linux-x64/arm64 五个平台

**痛点**：`postinstall` 下载依赖网络，国内访问 atomgit.com releases 可能缓慢；CLI 仍需命令行操作；SDK 本身需要 Node.js ≥ 18 环境。

#### 2.1.3 runtime 二进制发行版

`apps/agentskills-runtime/release/agentskills-runtime-win-x64.tar.gz`（~170MB）：
- 仓颉编译产物，包含所有依赖 DLL
- 解压后需手动配置 `.env`、命令行启动 `agentskills-runtime.exe 443`
- v0.0.25 已实现可视化系统配置管理（CLI/API/Web 三通道），但 Web 通道仍依赖 web-admin

### 2.2 用户画像与场景

| 用户类型 | 当前能力假设 | 期望操作 |
|---------|------------|---------|
| toC 个人用户 | 无命令行经验，无 Node.js 环境 | 下载安装包 → 双击安装 → 双击启动 → 向导配置 → 使用 |
| 小团队用户 | 基础 IT 能力，希望快速部署 | 安装包部署到团队机器，共享配置 |
| 开发者（现有） | 命令行熟练，Node.js 环境完备 | 继续使用 web-admin 或 SDK（不强制迁移） |

**结论**：PC 桌面客户端的核心受众是前两类用户，不应破坏现有开发者路径，而是作为新增的"低门槛通道"。

---

## 3. 技术选型方案对比

### 3.1 候选方案概览

PC 桌面客户端主流技术方案对比：

| 方案 | 技术栈 | 安装包体积 | 前端复用 | Node.js 生态 | 跨平台 | 成熟度 | 学习曲线 |
|------|--------|-----------|---------|-------------|--------|--------|---------|
| **Electron** | Chromium + Node.js | 大（~80-150MB） | ★★★★★ 完美 | ★★★★★ 原生 | ★★★★★ | ★★★★★ | ★★★★★ 低 |
| **Tauri** | Rust + 系统 WebView | 小（~5-15MB） | ★★★★☆ 好 | ★★★☆☆ 需 sidecar | ★★★★☆ | ★★★★☆ | ★★★☆☆ 中 |
| **Wails** | Go + 系统 WebView | 小（~8-20MB） | ★★★★☆ 好 | ★★☆☆☆ 需 sidecar | ★★★★☆ | ★★★☆☆ | ★★★☆☆ 中 |
| **VSCode 魔改** | VSCode OSS + 扩展 | 大（~300-400MB） | ★★☆☆☆ 需重写 | ★★★★★ 原生 | ★★★★★ | ★★★★☆ | ★★☆☆☆ 高 |
| **Flutter Desktop** | Dart | 中（~20-40MB） | ★☆☆☆☆ 无法复用 Vue | ★☆☆☆☆ | ★★★★☆ | ★★★☆☆ | ★★☆☆☆ 高 |
| **Qt (Python/C++)** | Qt + PySide/Qt C++ | 中（~30-60MB） | ★☆☆☆☆ 无法复用 | ★☆☆☆☆ | ★★★★★ | ★★★★★ | ★★☆☆☆ 高 |
| **NW.js** | Chromium + Node.js | 大（~80-150MB） | ★★★★★ 完美 | ★★★★★ 原生 | ★★★★☆ | ★★★☆☆ | ★★★★★ 低 |

### 3.2 关键决策因素分析

#### 3.2.1 前端代码复用（权重：高）

现有 `web-admin/web` 是 Vue 3.5 + TypeScript + OpenTiny Vue + Pinia ORM 体系，构建产物为静态 HTML/JS/CSS。

- **Electron / NW.js**：可直接加载本地 HTML 文件或内嵌 Web 服务，Vue 代码零改动复用
- **Tauri / Wails**：前端仍用 Vue 3，但需适配 Tauri/Wails 的 IPC 通信层，改动较小
- **VSCode 魔改**：VSCode 自身是 React 体系，需将 Vue 3 前端重写为 VSCode Webview 扩展或嵌入 iframe，复用度极低
- **Flutter / Qt**：需用 Dart/Qt 重写全部 UI，无法复用，工作量巨大

#### 3.2.2 Node.js 生态集成（权重：高）

`@opencangjie/skills` SDK 是 Node.js 包，依赖 `axios`、`execa`、`tar`、`inquirer` 等 Node.js 库。

- **Electron / NW.js**：主进程即 Node.js 环境，可直接 `require('@opencangjie/skills')`，完美复用 SDK
- **VSCode 魔改**：VSCode 扩展宿主也是 Node.js 环境，可调用 SDK，但受扩展 API 沙箱限制
- **Tauri / Wails**：Rust/Go 主进程无法直接用 Node.js 包，需通过 sidecar（子进程）方式调用 Node.js，或改用 Rust/Go 重写 SDK 逻辑
- **Flutter / Qt**：同上，需重写

#### 3.2.3 runtime 二进制生命周期管理（权重：高）

PC 客户端需管理 runtime 进程的启动、停止、重启、健康检查、日志收集。

- **Electron**：主进程可用 `child_process.spawn` 直接拉起 `agentskills-runtime.exe`，成熟的进程管理 API
- **Tauri**：Rust 的 `std::process::Command` 同样强大，且内存安全
- **Wails**：Go 的 `os/exec` 包成熟稳定
- **VSCode 魔改**：VSCode 扩展可用 `vscode.tasks` 或子进程 API，但进程管理能力受限，不如 Electron 灵活
- 三者均可胜任，差异不大

#### 3.2.4 安装包体积（权重：中）

runtime 二进制本身 ~170MB，客户端壳的体积增量：

- **Electron**：+80-100MB（Chromium + Node.js），总包 ~250-270MB
- **Tauri**：+5-15MB（系统 WebView），总包 ~175-185MB
- **Wails**：+8-20MB，总包 ~178-190MB
- **VSCode 魔改**：+300-400MB（完整 VSCode 基础 + 扩展），总包 ~470-570MB

对 toC 用户下载体验，Tauri/Wails 有优势，但 Electron 的体积在宽带时代可接受（参考 VS Code ~90MB、Slack ~300MB）。VSCode 魔改方案体积最大，是显著劣势。

#### 3.2.5 自动更新（权重：中）

- **Electron**：`electron-updater` 成熟方案，支持差量更新
- **Tauri**：`@tauri-apps/updater` 官方插件
- **Wails**：需自行实现或用第三方库
- **VSCode 魔改**：可复用 VSCode 内置更新机制，但定制化困难

#### 3.2.6 团队技能栈匹配（权重：中）

根据项目偏好与现有代码：
- 前端：Vue 3 + TypeScript（强偏好）
- 后端：仓颉（runtime）+ NestJS（安装时服务，仅用于快捷安装）
- `web-admin/` 是 monorepo 项目：`web/` 为前端，`nestJs/` 仅用于安装过程
- 团队对 Node.js / TypeScript 生态熟悉

Electron 的纯 JS/TS 技术栈与团队技能最匹配；Tauri 需引入 Rust，Wails 需引入 Go；VSCode 魔改需深入理解 VSCode 扩展架构。

### 3.3 方案深度对比

#### 3.3.1 方案 A：Electron（推荐）

```
┌─────────────────────────────────────────────────────────┐
│                  Electron 应用架构                       │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │            Main Process (Node.js)                │   │
│  │                                                 │   │
│  │  ┌─────────────┐  ┌─────────────────────────┐  │   │
│  │  │ 窗口管理     │  │ Runtime 进程管理         │  │   │
│  │  │ BrowserWindow│  │ spawn/kill/healthCheck  │  │   │
│  │  └─────────────┘  └─────────────────────────┘  │   │
│  │  ┌─────────────┐  ┌─────────────────────────┐  │   │
│  │  │ 系统托盘     │  │ @opencangjie/skills SDK │  │   │
│  │  │ Tray/Menu   │  │ install-runtime/start   │  │   │
│  │  └─────────────┘  └─────────────────────────┘  │   │
│  │  ┌─────────────┐  ┌─────────────────────────┐  │   │
│  │  │ 自动更新     │  │ 本地 HTTP 服务(可选)    │  │   │
│  │  │ autoUpdater │  │ 加载 Vue 前端静态资源   │  │   │
│  │  └─────────────┘  └─────────────────────────┘  │   │
│  └─────────────────────────────────────────────────┘   │
│                         ↕ IPC                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │          Renderer Process (Vue 3 + TS)           │   │
│  │                                                  │   │
│  │   复用 web-admin/web 的 Vue 3 前端代码           │   │
│  │   - Pinia ORM 模型                               │   │
│  │   - OpenTiny Vue 组件                            │   │
│  │   - 路由/视图/状态管理                           │   │
│  │   - 通过 IPC 调用 Main Process 能力              │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**优势**：
1. **前端零改动复用**：Vue 3 构建产物直接作为 Electron 渲染进程内容
2. **SDK 原生集成**：Main Process 直接 `import { SkillsClient } from '@opencangjie/skills'`
3. **生态成熟**：electron-builder、electron-updater、electron-store 等工具链完备
4. **团队技能匹配**：纯 TypeScript，无新语言学习成本
5. **文档丰富**：大量最佳实践与社区支持

**劣势**：
1. **体积大**：客户端壳 ~80-100MB，总包 ~250-270MB
2. **内存占用**：Chromium 多进程架构，内存占用较高（~200-400MB）
3. **安全面**：Node.js 集成在主进程，需注意 `nodeIntegration`、`contextIsolation` 配置

**适用场景**：优先追求开发效率与代码复用，体积非硬性约束。

#### 3.3.2 方案 B：Tauri（轻量替代）

```
┌─────────────────────────────────────────────────────────┐
│                   Tauri 应用架构                         │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │            Core Process (Rust)                   │   │
│  │                                                 │   │
│  │  ┌─────────────┐  ┌─────────────────────────┐  │   │
│  │  │ 窗口管理     │  │ Runtime 进程管理         │  │   │
│  │  │ tauri::Webview│ │ std::process::Command  │  │   │
│  │  └─────────────┘  └─────────────────────────┘  │   │
│  │  ┌─────────────┐  ┌─────────────────────────┐  │   │
│  │  │ 系统托盘     │  │ Sidecar: Node.js(可选)  │  │   │
│  │  │ tray plugin │  │ 调用 @opencangjie/skills│  │   │
│  │  └─────────────┘  └─────────────────────────┘  │   │
│  │  ┌─────────────┐  ┌─────────────────────────┐  │   │
│  │  │ 自动更新     │  │ 配置管理(Rust实现)      │  │   │
│  │  │ updater     │  │ .env 读写/验证          │  │   │
│  │  └─────────────┘  └─────────────────────────┘  │   │
│  └─────────────────────────────────────────────────┘   │
│                         ↕ IPC                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │        WebView (Vue 3 + TS, 系统 WebView)        │   │
│  │                                                  │   │
│  │   复用 web-admin/web 的 Vue 3 前端代码           │   │
│  │   - 通过 @tauri-apps/api 调用 Rust 命令          │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**优势**：
1. **体积小**：客户端壳 ~5-15MB，总包 ~175-185MB
2. **内存占用低**：系统 WebView，内存 ~100-200MB
3. **安全性强**：Rust 内存安全，默认严格 CSP
4. **性能好**：Rust 后端无 GC 暂停

**劣势**：
1. **SDK 集成复杂**：需通过 sidecar 方式运行 Node.js 子进程调用 SDK，或用 Rust 重写 SDK 逻辑（工作量大）
2. **Rust 学习曲线**：团队需引入 Rust 技能
3. **WebView 差异**：Windows 的 WebView2（Chromium Edge）、macOS 的 WKWebView（Safari）、Linux 的 webkitgtk 行为不完全一致，需兼容测试
4. **生态较新**：相比 Electron，社区资源较少

**适用场景**：体积是硬性约束，且团队愿意引入 Rust。

#### 3.3.3 方案 C：Wails（备选）

与 Tauri 类似的轻量方案，但用 Go 替代 Rust。

**优势**：Go 学习曲线低于 Rust；`os/exec` 进程管理简洁；编译速度快。
**劣势**：Go 生态对桌面应用支持弱于 Rust；Wails 社区小于 Tauri；同样需 sidecar 调用 Node.js SDK。

#### 3.3.4 方案 D：VSCode 魔改方案

市面上已有多个智能体桌面客户端采用 VSCode 魔改方案，如 Cursor、Windsurf (Codeium)、Cline 等。本节对该方案的可行性进行深入评估。

**VSCode 魔改方案概述**：

VSCode 魔改（fork）是指基于 VSCode OSS（开源版，MIT 协议）进行二次开发，替换品牌标识、内置 AI 功能扩展、修改默认配置，构建独立品牌的桌面 IDE/客户端。

```
┌─────────────────────────────────────────────────────────┐
│               VSCode 魔改应用架构                        │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │            VSCode OSS Shell (Electron)           │   │
│  │                                                 │   │
│  │  ┌─────────────┐  ┌─────────────────────────┐  │   │
│  │  │ Workbench   │  │ Extension Host          │  │   │
│  │  │ (React UI)  │  │ (Node.js 沙箱)          │  │   │
│  │  └─────────────┘  └─────────────────────────┘  │   │
│  │  ┌─────────────┐  ┌─────────────────────────┐  │   │
│  │  │ AI 扩展      │  │ Terminal/Task           │  │   │
│  │  │ (内置)       │  │ (进程管理)              │  │   │
│  │  └─────────────┘  └─────────────────────────┘  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  agentskills-runtime (子进程, 仓颉二进制)        │   │
│  │  通过 Terminal/Task API 或扩展子进程管理          │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**优势**：
1. **AI 集成天然优势**：VSCode 本身是代码编辑器，AI 代码补全/对话/编辑是核心交互，Cursor 等已验证此路径
2. **编辑器能力开箱即用**：文件管理、终端、Git、语言服务、调试等无需开发
3. **扩展生态**：可复用 VSCode Marketplace 的海量扩展
4. **用户心智模型匹配**：开发者已习惯 VSCode 系 IDE，学习成本为零
5. **内置终端**：可直接在终端中运行 runtime 命令，进程管理有基础支持
6. **自动更新**：VSCode 内置完善的更新机制

**劣势**：
1. **前端代码无法复用**：VSCode Workbench 是 React 体系，现有 Vue 3 前端代码（views/store/components/router）完全无法复用，需重新实现所有 UI
2. **体积巨大**：VSCode 基础 ~300MB + 扩展，总包 ~470-570MB，远超 Electron 方案
3. **fork 维护成本极高**：VSCode 每月发布更新，fork 版需持续同步上游代码、解决冲突、重新构建。Cursor 团队数十人专职维护
4. **产品定位错配**：agentskills-runtime PC 客户端的核心定位是"AI 智能体运行时管理面板"，不是"代码编辑器"。用户期望的是配置向导、技能管理、运行时监控等管理功能，而非编辑代码
5. **扩展 API 受限**：VSCode 扩展运行在沙箱中，进程管理、系统操作、网络配置等能力受限，不如 Electron 主进程灵活
6. **构建复杂**：VSCode 构建系统复杂（gulp + webpack + electron），定制构建流程学习成本高
7. **品牌合规风险**：VSCode OSS 虽为 MIT 协议，但微软对 fork 品牌有商标限制，需完全替换品牌标识和 Marketplace 连接

**与 Electron 方案的关键对比**：

| 对比维度 | Electron + Vue 3 | VSCode 魔改 |
|---------|-------------------|-------------|
| 前端代码复用 | ★★★★★ 零改动复用 Vue 3 | ★☆☆☆☆ 需用 React 重写全部 UI |
| 安装包体积 | ~250MB | ~470-570MB |
| 开发周期 | 9 周（首版） | 20+ 周（含 UI 重写 + fork 维护体系搭建） |
| 产品定位匹配 | ★★★★★ 管理面板型应用 | ★★★☆☆ IDE 型应用，管理功能需扩展实现 |
| 维护成本 | 低（独立项目） | 高（持续同步 VSCode 上游） |
| AI 交互体验 | 需自建对话 UI | ★★★★★ 内置编辑器 AI 交互 |
| 进程管理灵活性 | ★★★★★ 主进程全权 | ★★★☆☆ 受扩展 API 限制 |
| 系统集成 | ★★★★★ 托盘/通知/自启 | ★★★★☆ VSCode 已有但定制受限 |
| 团队技能匹配 | ★★★★★ 纯 TypeScript | ★★★☆☆ 需学 VSCode 扩展架构 |

**可行性结论**：

**不推荐采用 VSCode 魔改方案**，理由如下：

1. **产品定位不匹配**：agentskills-runtime PC 客户端的核心用户场景是"安装配置 → 启动运行时 → 管理技能 → 监控状态"，这是一个管理面板型应用，不是代码编辑器。VSCode 魔改带来的编辑器能力对本项目是冗余的
2. **代码复用率为零**：现有 Vue 3 前端代码（views/store/components/router/locale）完全无法复用，需用 React/VSCode Webview API 重写，工作量巨大
3. **维护成本不成比例**：VSCode 每月更新，fork 维护需要专职团队。Cursor 有 40+ 人的团队，本项目的资源规模无法支撑
4. **体积翻倍**：~500MB 的安装包对 toC 用户下载体验是严重负面影响

**适用场景**：如果未来产品定位转向"AI 代码编辑器 + 运行时管理"的复合形态（类似 Cursor + runtime），可重新评估此方案。当前阶段，应聚焦管理面板型应用。

### 3.4 推荐方案

**首选方案：Electron + Vue 3 + TypeScript**

**推荐理由**：

1. **最大化复用现有基础设施**（符合项目偏好"复用和完善优化已有的基础设施，而不是重新开发"）
   - Vue 3 前端代码零改动复用
   - `@opencangjie/skills` SDK 原生集成
   - NestJS 安装时服务的逻辑可迁移到 Main Process
   - Pinia ORM 模型层直接复用

2. **团队技能零缺口**
   - 纯 TypeScript 技术栈，与现有 web-admin 一致
   - 无需引入 Rust/Go/Dart 等新语言

3. **开发效率最高**
   - 成熟的 electron-vite 脚手架
   - 完善的 electron-builder 打包（NSIS/DMG/AppImage）
   - electron-updater 自动更新
   - electron-store 配置持久化

4. **体积可接受**
   - 总包 ~250-270MB，与 Slack（~300MB）、Notion（~200MB）同级别
   - 可通过 `asar` 打包、按需加载、差量更新优化下载体验

5. **toC 体验完整**
   - 系统托盘常驻
   - 单实例锁
   - 开机自启
   - 原生通知
   - 深度系统集成

**备选方案：Tauri + Vue 3 + TypeScript（轻量版）**

若后续体积成为硬性约束（如移动端分发、弱网下载），可考虑 Tauri 方案。建议作为 v2 演进方向，首版优先用 Electron 快速交付。

---

## 4. 开源起始项目调研（Electron + Vue 3）

为避免从零搭建项目脚手架，本节调研 GitHub、Gitee、AtomGit 等开源社区中可复用的 Electron + Vue 3 模板/脚手架项目。

### 4.1 GitHub 社区

| 项目 | Stars | 技术栈 | 特点 | 适用性 |
|------|-------|--------|------|--------|
| **[electron-vite/electron-vite-vue](https://github.com/alex8088/quick-start/tree/master/packages/create-electron/playground/vue-ts)** | ★5k+ (electron-vite) | Electron + Vue 3 + TS + Vite | electron-vite 官方模板，HMR 极快，TypeScript 原生支持，项目结构清晰 | ★★★★★ **首选** |
| **[electron-vite/electron-vite](https://github.com/alex8088/electron-vite)** | ★5k+ | Vite 插件 | Electron 的 Vite 构建工具，支持 Main/Renderer/Preload 三进程构建 | ★★★★★ |
| **[nicolo-ribaudo/electron-vite-vue3](https://github.com/nicolo-ribaudo/electron-vite-vue3)** | ★100+ | Electron + Vue 3 + Vite | 轻量级模板，适合快速起步 | ★★★★☆ |
| **[nklayman/vue-cli-plugin-electron-builder](https://github.com/nklayman/vue-cli-plugin-electron-builder)** | ★2k+ | Vue CLI + Electron | Vue 2/3 支持，但基于 webpack，构建较慢 | ★★★☆☆ |
| **[electron/electron-quick-start](https://github.com/electron/electron-quick-start)** | ★10k+ | Electron 原生 | 最简模板，无框架集成，需自行集成 Vue | ★★☆☆☆ |
| **[gothinkster/vue-electron](https://github.com/gothinkster/vue-electron)** | ★1k+ | Vue + Electron | 全栈模板，偏重，需裁剪 | ★★☆☆☆ |

### 4.2 Gitee 社区

| 项目 | 技术栈 | 特点 | 适用性 |
|------|--------|------|--------|
| **[electron-vite-vue3-template](https://gitee.com/)** | Electron + Vue 3 + Vite + TS | 国内镜像/搬运项目，与 GitHub 版本对应 | ★★★★☆ |
| **[electron-vue3-vite](https://gitee.com/)** | Electron + Vue 3 + Vite | 轻量级中文模板 | ★★★★☆ |

> 注：Gitee 上多数 Electron + Vue 3 项目为 GitHub 项目的国内镜像，建议直接使用上游项目。

### 4.3 AtomGit 社区

| 项目 | 技术栈 | 特点 | 适用性 |
|------|--------|------|--------|
| **[electron-quick-start](https://atomgit.com/)** | Electron 原生 | 基础模板 | ★★☆☆☆ |

> 注：AtomGit 社区以鸿蒙/仓颉生态为主，Electron 相关项目较少。

### 4.4 推荐起始项目

**首选推荐：electron-vite 官方 Vue 3 + TypeScript 模板**

```
# 创建项目
npm create @quick-start/electron my-app -- --template vue-ts

# 或使用 pnpm
pnpm create @quick-start/electron my-app -- --template vue-ts
```

**推荐理由**：

1. **electron-vite 是 Electron 生态的 Vite 构建标准**：由 antfu（Anthony Fu）核心贡献者维护，Star 数 5k+，社区活跃
2. **三进程构建**：Main Process、Renderer Process、Preload Script 分别构建，HMR 极快（<100ms）
3. **TypeScript 原生支持**：三进程均支持 TS，与项目技术栈一致
4. **electron-builder 集成**：内置打包配置，支持 NSIS/DMG/AppImage
5. **项目结构清晰**：
   ```
   ├── electron/          # Main Process + Preload
   ├── src/               # Renderer Process (Vue 3)
   ├── electron.vite.config.ts
   └── package.json
   ```
6. **与 web-admin/web 的 Vue 3 代码复用路径清晰**：Renderer Process 目录结构与 Vite Vue 3 项目一致

**备选推荐**：若需要更完整的开箱即用功能（如系统托盘、自动更新、多窗口管理等），可参考以下项目进行裁剪：

- **[electron-vite/electron-vite-react](https://github.com/alex8088/quick-start)**：React 版本，可参考其 Main Process 模块化架构
- **[nicedoc/electron-vite-vue3](https://github.com/nicedoc/electron-vite-vue3)**：含自动更新、系统托盘示例

### 4.5 起始项目与本项目适配建议

基于 electron-vite 模板创建项目后，需进行以下适配：

| 适配项 | 操作 | 工作量 |
|--------|------|--------|
| 前端代码复用 | 将 `src/` 替换为 web-admin/web 的 Vue 3 代码（monorepo workspace 或软链） | 小 |
| Main Process 模块化 | 新增 runtime 进程管理、配置向导、系统托盘等模块 | 中 |
| Preload 脚本 | 定义 IPC 接口（runtime:status、config:get/set 等） | 小 |
| electron-builder 配置 | 定制 NSIS 安装脚本、文件关联、协议注册 | 小 |
| OpenTiny Vue 适配 | 确认 OpenTiny Vue 组件在 Electron 渲染进程中正常渲染 | 小 |

---

## 5. 数据库兼容性深度分析

### 5.1 现状

agentskills-runtime 当前数据库配置：

| 配置项 | 当前值 | 来源 |
|--------|--------|------|
| 数据库类型 | PostgreSQL 16 | `.env` 中 `orm_drivers=opengauss` |
| 连接串 | `postgresql://postgres:uctoo123@127.0.0.1:5432/uctoo` | `.env` 中 `orm_connectionUrl` |
| 驱动 | `pgsql-driver`（仓颉纯实现） | `cjpm.toml` 中 `pgsql = { path = "./libs/pgsql-driver" }` |
| 连接池 | Init=5, Min=3, Max=30 | `.env` 中 `orm_databasePool*` |
| Schema 规模 | 8319 行 DDL，大量业务表 | `sql/uctooDB.sql` |
| SQLite 状态 | **已禁用**（`sqlite=disable`） | `cjpm.toml` 编译选项 |

**关键约束**：
- 项目采用 UMI 架构，设计理念是以统一模型层 ORM+API 建立分布式数据总线，屏蔽不同数据库的差异
- **但仓颉生态目前没有兼容多数据库的 ORM 库**，runtime 实际使用的是 `pgsql-driver` 这个专用驱动
- `pgsql-driver` 实现了 `std.database.sql` 接口（仓颉标准库数据库接口），但该接口是否被 SQLite 驱动同样实现，需要验证

### 5.2 数据库策略分析

PC 桌面客户端的数据库方案有三种策略，按优先级排列：

#### 策略一：集成安装 PostgreSQL（首选）

**方案描述**：在 PC 客户端安装过程中，同时集成安装 PostgreSQL 数据库，使 runtime 仍使用 PostgreSQL，无需做数据库兼容适配。

**可行性评估**：

| 评估项 | 分析 | 结论 |
|--------|------|------|
| PostgreSQL 嵌入式安装 | PostgreSQL 官方提供 Windows 安装包（~50MB），支持静默安装（`--mode unattended`） | ★★★★☆ 可行 |
| 体积影响 | 安装包增加 ~50-80MB（PostgreSQL 安装包 + 初始化数据），总包 ~300-350MB | ★★★☆☆ 可接受 |
| 安装体验 | 静默安装对用户透明，配置向导中可提供"自定义数据目录"选项 | ★★★★☆ |
| 端口冲突 | 需检测 5432 端口是否被占用，支持自定义端口 | ★★★★☆ |
| 数据目录 | 默认安装到 `%APPDATA%/agentskills/pgsql/data/`，支持自定义 | ★★★★☆ |
| 卸载清理 | 卸载时需停止 PostgreSQL 服务并清理数据目录（可选保留数据） | ★★★☆☆ |
| 多实例 | 同一机器安装多个客户端实例时需隔离数据目录和端口 | ★★★☆☆ |
| 运维复杂度 | 需管理 PostgreSQL 服务的启停（与 runtime 生命周期绑定） | ★★★☆☆ |

**实施方案**：

```
安装流程：
  1. 用户双击安装包
  2. NSIS 安装器解压文件
  3. 静默安装 PostgreSQL（--mode unattended --prefix "%APPDATA%/agentskills/pgsql"）
  4. 初始化数据库（createdb uctoo + 执行 sql/uctooDB.sql）
  5. 配置 .env（数据库连接串指向本地 PostgreSQL）
  6. 安装完成

启动流程：
  1. 客户端启动
  2. 拉起 PostgreSQL 服务（pg_ctl start）
  3. 等待 PostgreSQL 就绪（端口探测）
  4. 拉起 runtime 进程
  5. 打开主界面

停止流程：
  1. 停止 runtime 进程
  2. 停止 PostgreSQL 服务（pg_ctl stop）
  3. 客户端退出
```

**优势**：
- **零代码改动**：runtime 无需修改，仍使用 pgsql-driver + PostgreSQL
- **数据完整兼容**：所有 PostgreSQL 特性（JSONB、UUID、全文搜索等）均可用
- **Schema 零迁移**：现有 DDL 直接执行，无需适配
- **生产级可靠性**：PostgreSQL 是生产级数据库，ACID 事务、WAL 日志、崩溃恢复均完备

**劣势**：
- **体积增加**：~50-80MB
- **安装复杂度增加**：需管理 PostgreSQL 服务的生命周期
- **内存占用增加**：PostgreSQL 服务进程 ~50-100MB

**结论**：★★★★★ **强烈推荐**。这是改动最小、风险最低、兼容性最好的方案。体积增加可接受，安装复杂度可通过 NSIS 脚本和 Main Process 自动化解决。

#### 策略二：使用 SQLite + 仓颉 SQLite 驱动

**方案描述**：PC 客户端使用 SQLite 替代 PostgreSQL，需将 runtime 的数据库驱动从 pgsql-driver 切换为 SQLite 驱动。

**仓颉生态 SQLite 库评估**：

| 库 | 地址 | 评估 |
|----|------|------|
| **sqlite4cj (ChaosJohn)** | https://gitcode.com/ChaosJohn/sqlite4cj | 仓颉 SQLite 绑定，需评估是否实现 `std.database.sql` 接口 |
| **sqlite_cj (gqb6666)** | https://gitcode.com/gqb6666/sqlite_cj | 仓颉 SQLite 封装，需评估接口兼容性 |
| **sqlite4cj (AlonNas)** | https://gitcode.com/AlonNas/sqlite4cj | 另一个仓颉 SQLite 绑定，可能是 fork 版本 |

**兼容性风险分析**：

| 风险项 | 严重程度 | 分析 |
|--------|---------|------|
| `std.database.sql` 接口兼容 | **高** | pgsql-driver 实现了 `std.database.sql` 接口，SQLite 驱动是否同样实现此接口是关键。若未实现，runtime 的 ORM 层（f_orm）需大量适配 |
| SQL 语法差异 | **高** | 现有 DDL 使用 PostgreSQL 特有语法：`gen_random_uuid()`、`json`/`jsonb` 类型、`text COLLATE "pg_catalog"."default"`、`timetz`/`timestamptz` 等。SQLite 不支持这些语法，需逐表逐字段适配 |
| Schema 规模 | **高** | 主 DDL 文件 8319 行，增量 DDL 文件数十个，迁移工作量巨大 |
| 数据类型映射 | **高** | PostgreSQL 的 `uuid`、`jsonb`、`timestamptz`、`int4`/`int8`、`varchar` 等类型需映射到 SQLite 的 `TEXT`/`INTEGER`/`BLOB`，部分类型无直接对应 |
| JSONB 查询 | **中** | runtime 大量使用 JSONB 类型和 JSON 查询操作符（`->`、`->>`、`@>` 等），SQLite 的 JSON1 扩展功能有限 |
| 全文搜索 | **中** | PostgreSQL 的 `tsvector`/`tsquery` 全文搜索在 SQLite 中需替换为 FTS5 |
| 事务隔离级别 | **低** | SQLite 仅支持 SERIALIZABLE 隔离级别，PostgreSQL 默认 READ COMMITTED，一般不影响业务逻辑 |
| 并发写入 | **中** | SQLite 单写者模型，高并发写入时性能受限（但 PC 单用户场景影响较小） |

**工作量估算**：

| 工作项 | 估算 |
|--------|------|
| 仓颉 SQLite 驱动集成与测试 | 1-2 周 |
| DDL 语法适配（8319 行主 DDL + 增量 DDL） | 3-5 周 |
| ORM 层适配（f_orm + pgsql-driver → sqlite-driver） | 2-3 周 |
| JSONB 查询替换 | 1-2 周 |
| 数据迁移工具（PostgreSQL → SQLite） | 1 周 |
| 测试与回归 | 2-3 周 |
| **总计** | **10-16 周** |

**结论**：★★☆☆☆ **不推荐首版采用**。兼容性风险高、工作量巨大（10-16 周），且仓颉生态的 SQLite 驱动成熟度未知。可作为 v2 长期演进方向，待仓颉生态出现兼容多数据库的 ORM 库后再评估。

#### 策略三：混合方案（PostgreSQL 默认 + SQLite 可选）

**方案描述**：默认集成安装 PostgreSQL（策略一），同时提供 SQLite 作为"轻量模式"选项（策略二），供不需要完整数据库功能的用户选择。

**评估**：
- 首版实现成本 = 策略一 + 策略二 = 过高
- 建议首版只实现策略一，v2 根据用户反馈评估是否需要 SQLite 轻量模式

### 5.3 数据库策略推荐

| 策略 | 首版推荐 | 理由 |
|------|---------|------|
| **策略一：集成安装 PostgreSQL** | ✅ **强烈推荐** | 零代码改动、零迁移风险、完整功能兼容，体积增加可接受 |
| 策略二：使用 SQLite | ❌ 不推荐 | 兼容性风险高、工作量 10-16 周、仓颉 SQLite 驱动成熟度未知 |
| 策略三：混合方案 | ❌ 首版不做 | 首版成本过高，v2 评估 |

### 5.4 PostgreSQL 集成安装技术细节

**PostgreSQL Windows 嵌入式安装方案**：

| 方案 | 描述 | 体积 | 优势 | 劣势 |
|------|------|------|------|------|
| **官方安装包静默安装** | 使用 EnterpriseDB 安装包 `--mode unattended` | ~50MB | 完整功能、官方支持 | 安装时间长（~1min）、注册 Windows 服务 |
| **二进制分发包** | 使用 EDB/binaries 分发包，自行初始化 | ~30MB | 轻量、无安装器依赖 | 需自行编写初始化脚本 |
| **Embedded PostgreSQL** | 类似 embedded-pg（Java 生态）的方案 | ~30MB | 对用户完全透明 | 仓颉/Node.js 生态无现成方案，需自行实现 |

**推荐方案：二进制分发包 + 自行初始化**

```
安装包内预置：
  resources/pgsql/
  ├── bin/              # PostgreSQL 二进制（pg_ctl, postgres, initdb, createdb, psql）
  ├── lib/              # 依赖库
  └── share/            # 配置模板

首次启动初始化流程（Main Process）：
  1. 检测数据目录 %APPDATA%/agentskills/pgsql/data/ 是否存在
  2. 若不存在：
     a. 执行 initdb -D "%APPDATA%/agentskills/pgsql/data/" --locale=C --encoding=UTF8
     b. 修改 postgresql.conf（端口、连接数、日志等）
     c. 修改 pg_hba.conf（仅允许本地连接）
     d. 执行 pg_ctl start 启动服务
     e. 执行 createdb uctoo 创建数据库
     f. 执行 psql -f uctooDB.sql 初始化 Schema
     g. 执行增量 SQL 脚本
     h. 执行 pg_ctl stop 停止服务（等待客户端正式启动时再拉起）
  3. 若已存在：跳过初始化

运行时管理（Main Process）：
  - 启动：pg_ctl start -D "%APPDATA%/agentskills/pgsql/data/" -l logfile
  - 停止：pg_ctl stop -D "%APPDATA%/agentskills/pgsql/data/" -m smart
  - 状态：pg_ctl status -D "%APPDATA%/agentskills/pgsql/data/"
  - 端口探测：轮询 TCP 5432（或自定义端口）就绪
```

**配置向导中的数据库配置步骤**：

```
Step 2: 数据库配置
  ┌──────────────────────────────────────────────────────┐
  │  数据库配置                                           │
  │                                                      │
  │  ○ 内置数据库（推荐）                                 │
  │    自动安装并配置 PostgreSQL，适合个人使用             │
  │    数据存储位置：[C:\Users\xxx\AppData\agentskills\]  │
  │                                                      │
  │  ○ 外部数据库（高级）                                 │
  │    连接到已有的 PostgreSQL 实例                        │
  │    主机：[localhost]  端口：[5432]                    │
  │    数据库名：[uctoo]  用户名：[postgres]  密码：[***] │
  │                                                      │
  │            [测试连接]    [下一步]                      │
  └──────────────────────────────────────────────────────┘
```

---

## 6. 推荐方案架构设计

### 6.1 整体架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                    agentskills-runtime PC 客户端                     │
│                    (Electron + Vue 3 + TypeScript)                   │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    Main Process (Node.js)                      │  │
│  │                                                               │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │  │
│  │  │  窗口管理     │  │  系统托盘     │  │  自动更新         │   │  │
│  │  │  WindowMgr   │  │  TrayMgr     │  │  AutoUpdater     │   │  │
│  │  └──────────────┘  └──────────────┘  └──────────────────┘   │  │
│  │                                                               │  │
│  │  ┌──────────────────────────────────────────────────────────┐│  │
│  │  │              Runtime 生命周期管理                          ││  │
│  │  │                                                          ││  │
│  │  │  ┌────────────┐  ┌────────────┐  ┌──────────────────┐  ││  │
│  │  │  │ 进程管理    │  │ 健康检查    │  │ 日志收集         │  ││  │
│  │  │  │ ProcessMgr │  │ HealthCheck│  │ LogCollector    │  ││  │
│  │  │  └────────────┘  └────────────┘  └──────────────────┘  ││  │
│  │  │  ┌────────────┐  ┌────────────┐  ┌──────────────────┐  ││  │
│  │  │  │ 端口管理    │  │ 版本管理    │  │ 崩溃恢复         │  ││  │
│  │  │  │ PortMgr    │  │ VersionMgr │  │ CrashRecovery   │  ││  │
│  │  │  └────────────┘  └────────────┘  └──────────────────┘  ││  │
│  │  └──────────────────────────────────────────────────────────┘│  │
│  │                                                               │  │
│  │  ┌──────────────────────────────────────────────────────────┐│  │
│  │  │              PostgreSQL 生命周期管理（新增）               ││  │
│  │  │  - 首次启动初始化（initdb + createdb + schema 导入）     ││  │
│  │  │  - 启停管理（pg_ctl start/stop）                        ││  │
│  │  │  - 端口探测与冲突处理                                    ││  │
│  │  │  - 数据目录管理                                          ││  │
│  │  └──────────────────────────────────────────────────────────┘│  │
│  │                                                               │  │
│  │  ┌──────────────────────────────────────────────────────────┐│  │
│  │  │              SDK 集成层                                    ││  │
│  │  │  @opencangjie/skills                                       ││  │
│  │  │  - install-runtime (下载/解压/安装二进制发行版)            ││  │
│  │  │  - start / stop / restart                                  ││  │
│  │  │  - config get/set (配置管理)                               ││  │
│  │  │  - skills install/search/execute                           ││  │
│  │  └──────────────────────────────────────────────────────────┘│  │
│  │                                                               │  │
│  │  ┌──────────────────────────────────────────────────────────┐│  │
│  │  │              配置向导服务                                   ││  │
│  │  │  - 首次启动检测                                            ││  │
│  │  │  - 数据库配置（内置 PostgreSQL 默认 / 外部 PostgreSQL 可选）││  │
│  │  │  - AI 模型 API Key 配置                                    ││  │
│  │  │  - 网络代理配置                                            ││  │
│  │  │  - 配置验证与持久化                                        ││  │
│  │  └──────────────────────────────────────────────────────────┘│  │
│  │                                                               │  │
│  │  ┌──────────────────────────────────────────────────────────┐│  │
│  │  │              IPC 通信层                                    ││  │
│  │  │  ipcMain.handle / ipcRenderer.invoke                       ││  │
│  │  │  - runtime:start / stop / status                           ││  │
│  │  │  - pgsql:init / start / stop / status                     ││  │
│  │  │  - config:get / set / validate                             ││  │
│  │  │  - skills:install / list / execute                         ││  │
│  │  │  - system:openExternal / showItemInFolder                  ││  │
│  │  └──────────────────────────────────────────────────────────┘│  │
│  └───────────────────────────────────────────────────────────────┘  │
│                              ↕ IPC                                  │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                  Renderer Process (Vue 3)                      │  │
│  │                                                               │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │  │
│  │  │  配置向导     │  │  主界面       │  │  系统托盘菜单     │   │  │
│  │  │  SetupWizard │  │  MainApp     │  │  TrayMenu        │   │  │
│  │  └──────────────┘  └──────────────┘  └──────────────────┘   │  │
│  │                                                               │  │
│  │  ┌──────────────────────────────────────────────────────────┐│  │
│  │  │  复用 web-admin/web 的 Vue 3 前端                          ││  │
│  │  │  - views/ (页面视图)                                      ││  │
│  │  │  - store/models/ (Pinia ORM 模型)                         ││  │
│  │  │  - components/ (公共组件)                                 ││  │
│  │  │  - router/ (路由)                                         ││  │
│  │  │  - locale/ (国际化)                                       ││  │
│  │  └──────────────────────────────────────────────────────────┘│  │
│  │                                                               │  │
│  │  ┌──────────────────────────────────────────────────────────┐│  │
│  │  │  Electron 适配层                                          ││  │
│  │  │  - @electron/remote 替代为 IPC 调用                       ││  │
│  │  │  - axios baseURL 改为 runtime 本地端口                    ││  │
│  │  │  - 环境变量注入 (VITE_AGENTSILLS_RUNTIME_URL)             ││  │
│  │  └──────────────────────────────────────────────────────────┘│  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    打包资源层                                   │  │
│  │                                                               │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │  │
│  │  │ Vue 前端产物  │  │ runtime 二进制│  │ PostgreSQL 二进制 │   │  │
│  │  │ dist/        │  │ (首次运行下载)│  │ (预置/首次初始化) │   │  │
│  │  └──────────────┘  └──────────────┘  └──────────────────┘   │  │
│  │  ┌──────────────────────────────────────────────────────────┐│  │
│  │  │ 默认配置/资源     .env.default     sql/*.sql             ││  │
│  │  └──────────────────────────────────────────────────────────┘│  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                               ↕
┌─────────────────────────────────────────────────────────────────────┐
│              PostgreSQL (子进程, 本地实例)                             │
│              - 端口 5432（或动态分配）                                │
│              - 数据目录 %APPDATA%/agentskills/pgsql/data/            │
└─────────────────────────────────────────────────────────────────────┘
                               ↕
┌─────────────────────────────────────────────────────────────────────┐
│              agentskills-runtime (子进程, 仓颉二进制)                 │
│              - RESTful API (端口 8080 或动态分配)                    │
│              - MCP Server                                           │
│              - WebSocket Chat                                       │
│              - 技能执行引擎                                         │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.2 核心模块设计

#### 6.2.1 Runtime 生命周期管理

```
状态机：
  未安装 ──install──→ 安装中 ──success──→ 已安装 ──start──→ 运行中
     ↑                  │                  │                │
     │                  │fail              │stop            │crash
     │                  ▼                  ▼                ▼
     └─────────────────┘              已停止 ←───restart───┘
```

**关键能力**：
- **自动安装**：首次启动检测到 runtime 未安装时，调用 SDK `install-runtime` 下载并解压
- **自动启动**：客户端启动时自动拉起 runtime 子进程，动态分配端口避免冲突
- **健康检查**：每 5 秒轮询 `/api/v1/uctoo/health`，异常时自动重启（最多 3 次）
- **优雅停止**：客户端退出时先向 runtime 发送停止信号，等待 5 秒后强制 kill
- **崩溃恢复**：runtime 崩溃时收集日志，通知用户，提供"一键重启"按钮
- **版本管理**：支持 runtime 版本升级、回滚，保留历史版本

#### 6.2.2 PostgreSQL 生命周期管理（新增）

```
状态机：
  未初始化 ──init──→ 初始化中 ──success──→ 已初始化 ──start──→ 运行中
     ↑                   │                   │                │
     │                   │fail               │stop            │crash
     │                   ▼                   ▼                ▼
     └───────────────────┘               已停止 ←───restart───┘
```

**关键能力**：
- **首次初始化**：检测数据目录不存在时，执行 `initdb` → 修改配置 → `createdb` → 导入 Schema
- **自动启停**：与客户端生命周期绑定，客户端启动时拉起 PostgreSQL，退出时停止
- **端口管理**：检测 5432 端口冲突，支持自动分配可用端口
- **数据目录**：默认 `%APPDATA%/agentskills/pgsql/data/`，支持自定义
- **安全配置**：`pg_hba.conf` 仅允许本地连接，`postgresql.conf` 限制连接数和内存
- **备份恢复**：提供 `pg_dump`/`pg_restore` 一键备份恢复功能

#### 6.2.3 配置向导

首次启动向导化配置，降低 `.env` 配置门槛：

```
向导步骤：
  Step 1: 欢迎页（介绍功能）
  Step 2: 数据库配置
          - 默认：内置 PostgreSQL（自动安装初始化，零配置，适合个人用户）
          - 高级：外部 PostgreSQL（需用户填写连接信息）
  Step 3: AI 模型配置
          - 选择模型提供商（OpenAI/Anthropic/智谱/通义/...）
          - 填写 API Key（密码框，支持测试连接）
  Step 4: 网络配置（可选）
          - 代理服务器配置（国内用户访问海外 API）
  Step 5: 完成并启动
```

**设计原则**：
- **零配置优先**：能默认的绝不问用户（如端口、日志级别、SSL）
- **渐进披露**：高级配置折叠隐藏，不干扰普通用户
- **即时验证**：每步配置即时校验（如数据库连接测试、API Key 有效性测试）
- **可重置**：支持恢复默认配置、重新进入向导

#### 6.2.4 前端复用策略

```
web-admin/web (现有)              pc-client/renderer (新)
├── src/                          ├── src/
│   ├── views/      ──────────→   │   ├── views/      (复用)
│   ├── store/      ──────────→   │   ├── store/      (复用)
│   ├── components/ ──────────→   │   ├── components/ (复用)
│   ├── router/     ──────────→   │   ├── router/     (复用+扩展)
│   ├── locale/     ──────────→   │   ├── locale/     (复用)
│   └── api/        ──────────→   │   └── api/        (适配)
└── package.json                  ├── electron/       (新增, Electron 适配层)
                                   │   ├── ipc.ts      (IPC 通信封装)
                                   │   ├── adapter.ts  (API 适配)
                                   │   └── preload.ts  (预加载脚本)
                                   └── package.json
```

**适配点**：
1. **API baseURL**：从 `VITE_BACKEND_URL`（远程）改为 `http://127.0.0.1:{动态端口}`（本地 runtime）
2. **文件操作**：浏览器 `fetch` 无法本地文件操作，改为通过 IPC 调用 Main Process 的 `fs` 模块
3. **新窗口**：`window.open` 改为 `BrowserWindow` 创建
4. **路由**：增加配置向导路由（`/setup`）、托盘菜单路由

#### 6.2.5 打包与分发

```
构建产物：
  agentskills-runtime-pc-setup-x.x.x.exe    (NSIS 安装包, ~300MB)
  agentskills-runtime-pc-x.x.x.exe          (免安装版, ~310MB)
  agentskills-runtime-pc-x.x.x.exe.blockmap (差量更新映射)

安装包内容：
  ├── agentskills-runtime-pc.exe            (Electron 主程序)
  ├── resources/
  │   ├── app.asar                          (Vue 前端 + Main Process 代码)
  │   ├── pgsql/                            (PostgreSQL 二进制分发包, ~30MB)
  │   └── runtime/                          (runtime 二进制, 首次运行下载或预置)
  └── defaults/
      ├── .env.default                      (默认配置模板)
      ├── sql/                              (数据库初始化脚本)
      └── skills/                           (预置技能)
```

**分发策略**：
- **主分发**：NSIS 安装包（支持静默安装、卸载、升级）
- **免安装版**：解压即用（绿色版，适合无管理员权限用户）
- **自动更新**：electron-updater + 静态文件服务器（GitHub Releases 或自建）
- **runtime 按需下载**：安装包不预置 runtime（减小初始体积），首次运行时下载；或提供"完整版/精简版"两种安装包

### 6.3 关键技术决策

| 决策项 | 选择 | 理由 |
|--------|------|------|
| 构建工具 | electron-vite | Vite 生态，HMR 快，与现有 Vite 配置一致 |
| 起始模板 | electron-vite vue-ts | 官方模板，TypeScript 原生支持，社区活跃 |
| 打包工具 | electron-builder | 支持 NSIS/DMG/AppImage，社区标准 |
| 自动更新 | electron-updater | 差量更新，支持 GitHub/私有服务器 |
| 状态持久化 | electron-store | 简单的 JSON 配置持久化 |
| 日志 | electron-log | 文件日志 + 控制台日志，自动轮转 |
| IPC 安全 | contextBridge + preload | `contextIsolation: true`，禁用 `nodeIntegration` |
| 数据库 | 集成安装 PostgreSQL | 零代码改动，完整功能兼容，详见第 5 章 |
| 进程管理 | child_process.spawn | Node.js 原生，支持流式日志 |
| 系统集成 | Electron Tray/Menu/Notification | 原生支持，无需额外依赖 |

---

## 7. 开发方案与里程碑

### 7.1 项目结构建议

```
apps/agentskills-runtime-pc/              # 新建 PC 客户端项目
├── electron/                             # Main Process
│   ├── main.ts                           # 主进程入口
│   ├── preload.ts                        # 预加载脚本
│   ├── modules/
│   │   ├── window.ts                     # 窗口管理
│   │   ├── tray.ts                       # 系统托盘
│   │   ├── runtime.ts                    # Runtime 生命周期
│   │   ├── pgsql.ts                      # PostgreSQL 生命周期（新增）
│   │   ├── config.ts                     # 配置向导服务
│   │   ├── updater.ts                    # 自动更新
│   │   └── ipc.ts                        # IPC 通信注册
│   └── utils/
│       ├── port.ts                       # 端口管理
│       ├── process.ts                    # 进程工具
│       └── logger.ts                     # 日志
├── src/                                  # Renderer Process (复用 web-admin/web)
│   ├── views/                            # 复用 + 新增配置向导视图
│   ├── store/                            # 复用
│   ├── components/                       # 复用
│   ├── router/                           # 复用 + 扩展
│   ├── electron/                         # Electron 适配层
│   │   ├── ipc.ts                        # IPC 调用封装
│   │   └── adapter.ts                    # API 适配
│   └── ...
├── resources/                            # 打包资源
│   ├── icon.ico
│   ├── tray-icon.png
│   ├── pgsql/                            # PostgreSQL 二进制分发包（新增）
│   │   └── bin/                          # pg_ctl, postgres, initdb, createdb, psql
│   ├── sql/                              # 数据库初始化脚本（新增）
│   │   ├── uctooDB.sql
│   │   └── incremental/
│   └── defaults/
│       └── .env.default
├── build/                                # 打包配置
│   └── installer.nsh                     # NSIS 自定义脚本
├── package.json
├── electron.vite.config.ts               # 构建配置
├── electron-builder.yml                  # 打包配置
└── tsconfig.json
```

### 7.2 里程碑规划

#### M1：基础骨架（2 周）

**目标**：基于 electron-vite vue-ts 模板跑通 Electron + Vue 3 最小可用骨架

**交付物**：
- Electron 主进程/渲染进程/预加载脚本
- 复用 web-admin/web 前端代码（通过软链或 monorepo workspace）
- 基本窗口、系统托盘
- 开发环境 HMR

**验收**：`pnpm dev` 启动 Electron 窗口，显示 Vue 前端首页

#### M2：Runtime 集成（2 周）

**目标**：客户端能管理 runtime 生命周期

**交付物**：
- Runtime 进程管理模块（启动/停止/重启/健康检查）
- SDK 集成（`@opencangjie/skills`）
- 首次运行自动下载安装 runtime
- 动态端口分配
- 日志收集与展示

**验收**：启动客户端 → 自动拉起 runtime → 前端能调用 runtime API → 退出客户端优雅停止 runtime

#### M3：PostgreSQL 集成（2 周，新增）

**目标**：客户端能自动安装和管理本地 PostgreSQL 实例

**交付物**：
- PostgreSQL 二进制分发包预置到安装包
- 首次启动自动初始化（initdb + createdb + schema 导入）
- PostgreSQL 生命周期管理（启停与客户端绑定）
- 端口冲突检测与自动分配
- 数据目录管理（默认路径 + 自定义）

**验收**：全新安装 → 客户端自动初始化 PostgreSQL → 导入 Schema → runtime 连接本地 PostgreSQL 成功

#### M4：配置向导（2 周）

**目标**：首次启动向导化配置，达到开箱即用

**交付物**：
- 配置向导 UI（5 步流程）
- 数据库配置（内置 PostgreSQL 默认 / 外部 PostgreSQL 可选）
- AI 模型 API Key 配置（多提供商支持）
- 网络代理配置
- 配置验证（即时测试连接）
- 配置持久化与重置

**验收**：全新用户双击安装 → 向导配置 → 进入主界面使用 AI 功能

#### M5：打包分发（1 周）

**目标**：可分发安装包

**交付物**：
- electron-builder 打包配置（NSIS）
- 安装包资源组织（含 PostgreSQL 二进制）
- 自动更新配置
- 代码签名（可选）

**验收**：生成可双击安装的 `.exe`，安装后桌面有图标，能正常启动

#### M6：体验打磨（2 周）

**目标**：达到 toC 产品体验标准

**交付物**：
- 单实例锁
- 开机自启
- 崩溃恢复与错误上报
- 深色模式
- 国际化（中/英）
- 性能优化（启动速度、内存占用）
- 用户反馈通道

**验收**：内部用户测试通过，NPS 评分达标

#### M7：跨平台扩展（2 周，可选）

**目标**：支持 macOS、Linux

**交付物**：
- macOS DMG 打包、代码签名、公证
- Linux AppImage/deb 打包
- 平台特定适配（路径、托盘、通知）

**验收**：三平台安装包均可用

### 7.3 总工期估算

| 阶段 | 工期 | 累计 |
|------|------|------|
| M1 基础骨架 | 2 周 | 2 周 |
| M2 Runtime 集成 | 2 周 | 4 周 |
| M3 PostgreSQL 集成 | 2 周 | 6 周 |
| M4 配置向导 | 2 周 | 8 周 |
| M5 打包分发 | 1 周 | 9 周 |
| M6 体验打磨 | 2 周 | 11 周 |
| M7 跨平台（可选） | 2 周 | 13 周 |

**首版（Windows）预计 11 周**（含 PostgreSQL 集成），含跨平台 13 周。

---

## 8. 风险与对策

| 风险 | 等级 | 影响 | 对策 |
|------|------|------|------|
| runtime 二进制下载慢/失败 | 高 | 首次体验差 | 提供镜像源、断点续传、预置完整版安装包、离线包 |
| PostgreSQL 初始化失败 | 高 | 数据库不可用 | 完善错误处理、提供手动初始化入口、日志诊断 |
| Electron 体积大（~300MB 含 PostgreSQL） | 中 | 下载耗时 | 差量更新、分片下载、提供精简版（runtime 按需下载） |
| 端口冲突（PostgreSQL 5432 / runtime 8080） | 中 | 服务启动失败 | 动态端口分配、端口探测、冲突提示 |
| WebView 兼容性（若用 Tauri） | 中 | UI 异常 | 首版选 Electron 规避 |
| macOS 签名/公证 | 中 | 分发受阻 | 提前申请 Apple Developer 账号 |
| runtime 崩溃影响客户端 | 中 | 体验中断 | 进程隔离、崩溃恢复、日志上报 |
| PostgreSQL 服务异常 | 中 | 数据库不可用 | 健康检查、自动重启、降级提示 |
| 配置向导过于复杂 | 中 | 用户流失 | 零配置优先、渐进披露、默认值合理 |
| 自动更新失败 | 低 | 升级受阻 | 回退机制、手动下载兜底 |
| 安全性（Main Process 权限） | 中 | 恶意利用 | `contextIsolation`、`sandbox`、CSP、最小权限 |

---

## 9. 与现有体系的集成策略

### 9.1 代码复用策略

| 复用对象 | 来源 | 复用方式 | 改动量 |
|---------|------|---------|--------|
| Vue 前端代码 | `web-admin/web/src/` | monorepo workspace 或 git submodule | 小（适配 API baseURL） |
| Pinia ORM 模型 | `web-admin/web/src/store/models/` | 同上 | 无 |
| OpenTiny Vue 组件 | npm 包 | 直接依赖 | 无 |
| `@opencangjie/skills` SDK | npm 包 | 直接依赖 | 无 |
| NestJS 安装逻辑 | `web-admin/nestJs/` | 迁移到 Main Process | 中（重写为 TS 模块） |
| runtime 二进制 | `agentskills-runtime/release/` | 首次运行下载 | 无 |
| PostgreSQL 二进制 | EDB 官方分发包 | 预置到安装包 | 无 |
| 数据库 Schema | `agentskills-runtime/sql/` | 首次初始化导入 | 无 |

### 9.2 与 web-admin 的关系

PC 客户端与 web-admin **并行存在**，面向不同用户：

```
                    ┌─────────────────────┐
                    │   共享前端代码层      │
                    │   (Vue 3 + Pinia ORM)│
                    └──────────┬──────────┘
                               │
              ┌────────────────┴────────────────┐
              │                                 │
    ┌─────────▼─────────┐             ┌─────────▼─────────┐
    │   PC 桌面客户端     │             │   web-admin       │
    │   (Electron)       │             │   (Web 应用)      │
    │                   │             │                   │
    │   面向：toC 用户   │             │   面向：开发者    │
    │   交付：安装包     │             │   交付：源码+脚本  │
    │   配置：向导化     │             │   配置：手动.env   │
    │   数据库：内置 PG  │             │   数据库：外部 PG  │
    └───────────────────┘             └───────────────────┘
              │                                 │
              └────────────────┬────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │  agentskills-runtime │
                    │  (仓颉二进制)        │
                    └─────────────────────┘
```

**不替代、不破坏**：web-admin 继续作为开发者路径维护，PC 客户端作为 toC 用户新增路径。

### 9.3 项目位置建议

```
uctoo-admin/apps/
├── agentskills-runtime/          # runtime 内核（仓颉）
├── agentskills-runtime-pc/       # ★ 新增：PC 桌面客户端（Electron）
├── web-admin/                    # Web 管理后台（开发者用，monorepo: web + nestJs）
├── uctoo-app-client-pc/          # 现有 PC Web 应用（可逐步迁移或保留）
└── ...
```

---

## 10. 后续工作建议

本报告为技术选型与开发方案的建议性文档，后续应按规范驱动开发（SDD）流程推进：

| 阶段 | 产物 | 负责 Agent | 状态 |
|------|------|-----------|------|
| 需求规格 | `spec.md` | spec-requirement-agent | 待启动 |
| 技术设计 | `design.md` | spec-design-agent | 待启动 |
| 任务清单 | `tasks.md` | spec-task-agent | 待启动 |
| 编码实现 | 源代码 | 开发者 / cangjie-coder | 待启动 |

**建议下一步**：
1. 基于本报告，启动 `spec-requirement-agent` 生成 `spec.md`（需求规格，聚焦"做什么"）
2. 随后由 `spec-design-agent` 生成 `design.md`（技术设计，聚焦"怎么做"）
3. 最后由 `spec-task-agent` 分解 `tasks.md`（编码任务清单）

---

## 11. 结论

**推荐采用 Electron + Vue 3 + TypeScript 方案**，并**集成安装 PostgreSQL**作为数据库方案，理由如下：

1. **最大化复用**：Vue 3 前端代码、Pinia ORM 模型、`@opencangjie/skills` SDK 均可直接复用，符合"复用和完善优化已有基础设施"的项目偏好
2. **数据库零改动**：集成安装 PostgreSQL，runtime 无需修改任何数据库相关代码，完整兼容所有 PostgreSQL 特性
3. **团队技能匹配**：纯 TypeScript 技术栈，无新语言学习成本
4. **开发效率最高**：成熟工具链（electron-vite、electron-builder、electron-updater），基于 electron-vite vue-ts 模板快速起步
5. **toC 体验完整**：系统托盘、自动更新、配置向导、崩溃恢复，达到开箱即用
6. **体积可接受**：~300MB 总包（含 PostgreSQL），与同类产品（Slack ~300MB、Notion ~200MB）相当，可通过差量更新优化

**备选方案**：
- **Tauri + Vue 3**：作为 v2 轻量化演进方向保留，待首版验证市场反馈后评估
- **SQLite 替代**：作为 v2 长期演进方向，待仓颉生态出现兼容多数据库的 ORM 库后再评估
- **VSCode 魔改**：仅在产品定位转向"AI 代码编辑器 + 运行时管理"复合形态时重新评估

本方案将 agentskills-runtime 的使用门槛从"需预装 Node.js + 命令行操作 + 手动配置 + 外部数据库"降低到"双击安装 + 向导配置"，真正实现对 toC 个人用户的开箱即用。

---

**报告结束**

> 如需对本报告内容进行修改或补充，请反馈具体意见。确认无误后，可启动 `spec-requirement-agent` 生成正式的需求规格文档 `spec.md`。
