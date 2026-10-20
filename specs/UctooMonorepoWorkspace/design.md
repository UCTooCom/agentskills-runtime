# 设计文档

## 文档信息
- **项目名称**: uctoo v4 本地开发 monorepo 工程
- **关联规格**: `spec.md`（REQ-MONO-001 ~ 005）
- **版本**: 1.0
- **创建日期**: 2026-10-10
- **作者**: SDD Agent
- **状态**: 草案

---

## 1. 目标目录结构

新 monorepo 根 `D:\UCT\projects\uctoo` 的规划结构如下（与 `products\uctoo` 开源库同构，但**只收 v4 产品**，不含 v3 残留）：

```
D:\UCT\projects\uctoo\                      # monorepo 根（开发主目录）
├── pnpm-workspace.yaml                     # 声明 workspace 成员
├── turbo.json                             # 任务编排（build/dev/test/lint）
├── package.json                           # 根包（packageManager: pnpm@9.7.0）
├── .npmrc
├── .node-version                          # 20
├── .nvmrc（可选）
├── README.md                             # 开发环境搭建 + onboarding 入口
├── apps\
│   ├── agentskills-runtime\              # 仓颉 AI 驱动开发框架（cjpm 工程）
│   │   ├── cjpm.toml
│   │   ├── src\
│   │   └── specs\                        # 其自有规格（含本目录的父级）
│   ├── web-admin\                        # web 管理端（Vue3 + OpenTiny）
│   │   ├── web\        → 提层到 apps/web-admin/ 根（去 NestJS）
│   │   └── （废弃）nestJs\ 不再纳入
│   ├── pc-client\                        # PC 客户端（electron，原 agentskills-runtime-pc）
│   │   ├── electron\
│   │   ├── build\
│   │   └── electron-builder.json
│   ├── miniapp\                          # 微信小程序（uni-app，旧版参考后重构）
│   │   └── ...
│   └── harmonyos\                        # 鸿蒙客户端（仓颉原生，占位规划）
│       └── README.md                     # 技术栈待后续研究
├── packages\                             # 可复用 TS 包（从开源库同构）
│   ├── @core\
│   ├── utils\
│   ├── webmcp-sdk\
│   └── tiny-robot\
├── internal\                             # 内部配置（lint/ts/vite/tailwind）
│   ├── lint-configs\
│   ├── tsconfig\
│   ├── vite-config\
│   └── node-utils\
└── scripts\                              # 跨子工程脚本（环境检查、出包等）
    └── check-env.ps1                     # 新人环境前置检查
```

> 说明：`packages/`、`internal/` 的**内容**优先从 `products\uctoo` 开源库**同步**（而非从旧 v3 的 uctoo-admin 复制），因为开源库才是 v4 的权威形态。只有 `apps/*` 的 v4 子工程来自旧环境迁移。

---

## 2. 根配置模板

### 2.1 `pnpm-workspace.yaml`

```yaml
packages:
  - "internal/*"
  - "internal/lint-configs/*"
  - "packages/*"
  - "packages/@core/*"
  - "packages/effects/*"
  - "packages/business/*"
  - "apps/*"
  - "scripts/*"
```

> 仓颉工程 `apps/agentskills-runtime` 没有 `package.json`，pnpm 会跳过它、不影响 workspace；它的构建由 turbo 直接调 `cjpm`。

### 2.2 `turbo.json`（关键任务，含仓颉）

```json
{
  "$schema": "https://turbo.build/schema.json",
  "globalEnv": ["NODE_ENV"],
  "tasks": {
    "build": { "dependsOn": ["^build"], "outputs": ["dist/**"] },
    "dev": { "cache": false, "persistent": true },
    "test": { "dependsOn": ["^build"] },
    "lint": {},
    "typecheck": { "outputs": [] },
    "cj:build": {
      "cache": false,
      "outputs": ["dist/**", "target/**"],
      "command": "cjpm build"
    },
    "cj:dev": { "cache": false, "persistent": true, "command": "cjpm run" }
  }
}
```

### 2.3 `package.json`（根，关键字段）

```json
{
  "name": "uctoo-dev-workspace",
  "private": true,
  "type": "module",
  "packageManager": "pnpm@9.7.0",
  "engines": { "node": ">=20", "pnpm": ">=9" },
  "scripts": {
    "bootstrap": "pnpm install",
    "dev": "turbo run dev",
    "build": "turbo run build",
    "build:runtime": "turbo run cj:build --filter=agentskills-runtime",
    "dev:web": "turbo run dev --filter=web-admin",
    "dev:pc": "turbo run dev --filter=pc-client",
    "check:env": "pwsh scripts/check-env.ps1"
  },
  "devDependencies": {
    "turbo": "^2.0.12",
    "typescript": "^5.5.4"
  },
  "preinstall": "npx only-allow pnpm"
}
```

---

## 3. 迁移分步策略

### 阶段一：脚手架（从开源库同构，不碰旧 v3）
1. 在 `D:\UCT\projects\uctoo` 落根配置（`pnpm-workspace.yaml` / `turbo.json` / `package.json` / `.npmrc` / `.node-version`）。
2. 从 `products\uctoo` 同步 `packages/`、`internal/` 的 v4 形态配置（lint/ts/vite/tailwind）。
3. 写 `README.md`（开发环境搭建 + onboarding 入口）与 `scripts/check-env.ps1`。

### 阶段二：子工程迁入（挑选 v4 部分，排除 v3 残留）
按 §4 映射表逐个迁入：
- `apps/agentskills-runtime`：从 `uctoo-admin/apps/agentskills-runtime` 整体复制（仓颉工程，含 `.workbuddy` 按需）。
- `apps/web-admin`：复制 `web/` 并提层到根（去 `nestJs/`），细节由 web-admin-migration spec 落地。
- `apps/pc-client`：从 `agentskills-runtime-pc` 复制 electron 工程，目录改名。
- `apps/miniapp`：旧版参考后，按 uni-app 技术栈重构或复制。
- `apps/harmonyos`：仅建占位目录 + README。

### 阶段三：验证与固化
- 跑 `pnpm install`，确认 Node 侧 workspace 正常。
- 人工在独立 cmd 跑 `cjpm build`（agentskills-runtime），AI 不编译。
- 跑 `pnpm dev:web` / `pnpm dev:pc` 确认前端/客户端可启动。
- 走一遍 onboarding 文档，确认新人流程可复现。

> 明确排除项（**不纳入**新目录）：旧 `uctoo-admin` 下的第三方 zip（`apple-vision-pro-clone.zip`）、实验目录（`A2A`、`ACPs-community`、`HarmonyOS-Examples-*`、`CangjieMagic` 等）、v3 专用配置、`uvtooadmin` 历史构建产物。这些留在旧目录，仅供检索参考。

---

## 4. 新人 onboarding 全流程设计

目标：模拟"新人开发者从安装 PC 客户端到安装开发包"的完整链路，固化成文档 + 脚本。

### 步骤一：安装 PC 客户端
- 由 `apps/pc-client`（electron）出包，生成一键安装包（含 Node 运行时、必要的 PC 端入口）。
- 新人双击安装，完成基础运行环境就绪。
- 安装包逻辑由 `specs/PcClientInstallerIntegration` 约束。

### 步骤二：获取开发包
```bash
# 进入开发主目录（已存在空目录）
cd D:\UCT\projects\uctoo
# 若尚未初始化，按阶段一落根配置；日常开发则直接：
pnpm install
```

### 步骤三：环境前置检查
```powershell
# scripts/check-env.ps1 校验：
# - Node >= 20
# - pnpm >= 9
# - cjc (Cangjie) 1.1.3 在 PATH
# - PostgreSQL 可达（runtime 需要）
pwsh scripts/check-env.ps1
```

### 步骤四：分工程启动
```bash
# 后端（仓颉，人工编译后由 turbo 调度）
pnpm build:runtime
# 前端管理端
pnpm dev:web
# PC 客户端（开发模式）
pnpm dev:pc
```

### 步骤五：验证
- 浏览器打开 web-admin 地址，确认能登录、调通 runtime API。
- PC 客户端能加载 web-admin 与 runtime。

> 全流程写成 `README.md` 的 "新人 5 步上手" 章节，并配 `check-env.ps1` 自动校验，做到"按文档即可复现"。

---

## 5. 关键设计决策记录

| 决策点 | 选择 | 原因 |
|--------|------|------|
| 开发主目录 | `D:\UCT\projects\uctoo` | 空目录、语义正确、不污染开源库 |
| 开源库定位 | `D:\UCT\products\uctoo` 作上游参照 | 已是 gitee 镜像，单向借鉴 |
| 包管理 + 编排 | pnpm Workspace + Turborepo | 与 v4 开源库同构、语言无关、仓颉友好 |
| 仓颉工程接入 | cjpm 独立目录 + turbo 调度 | pnpm 管不了 cjpm 依赖 |
| packages/internal 来源 | 从开源库同步 | 开源库才是 v4 权威形态 |
| 旧 v3 内容 | 整体排除 | 仅挑 v4 子工程迁入 |
