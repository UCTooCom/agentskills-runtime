# 需求规格文档

## 文档信息
- **项目名称**: uctoo v4 本地开发 monorepo 工程（UctooMonorepoWorkspace）
- **版本**: 1.0
- **创建日期**: 2026-10-10
- **作者**: SDD Agent
- **状态**: 草案（待评审）

---

## 0. 摘要（给评审者的结论先行）

本次前置工程要解决一件事：**把目前散落在旧 v3 开发环境 `uctoo-admin` 里的 v4 产品体系，重新整合到一套干净、统一的本地 monorepo 中，并让"新人从装 PC 客户端到装开发包"的全流程可被复现。**

两个必须拍板的点，本文已给出研究结论：

1. **用哪个目录建 monorepo** → 推荐 `D:\UCT\projects\uctoo`（已在 2026-10-10 新建的空目录，语义是"工程/工作区"，作为开发主目录）。`D:\UCT\products\uctoo` 是 v4 开源库本体（与 `gitee.com/uctoo/uctoo` 一致），不应作为日常开发改造主目录。
2. **选哪个 monorepo 管理工具** → 推荐 **pnpm Workspace + Turborepo**。理由是该组合与 `products\uctoo`（v4 开源库）**技术栈 100% 同构**，且 Turborepo 是语言无关的 task runner，能统一编排仓颉（cjpm）、前端（vite）、PC 客户端（electron-builder）、小程序（uniapp）、鸿蒙（仓颉）多套构建系统。

---

## 1. 概述

### 1.1 项目背景

- 当前本地开发环境是 `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin`，本质是 **uctoo v3** 的 monorepo。它虽已包含部分 v4 子工程，但整体脚手架、依赖、agent 配置仍是 v3 形态，且 `apps/` 下混入了大量第三方 zip、实验性目录（如 `apple-vision-pro-clone.zip`、`HarmonyOS-Examples-*`、`A2A`、`ACPs-community` 等），已不适应 uctoo v4 的开发需要，只是"一直没去更新"。
- uctoo v4 的开源产品体系（详见 §4）目前分散在 `uctoo-admin/apps/*` 下，各自为政。其中 `web-admin` 仍保留将被淘汰的 NestJS 后端、`agentskills-runtime-pc` 是独立 electron 工程、仓颉工程 `agentskills-runtime` 用 cjpm 而非 pnpm。
- `D:\UCT\products\uctoo` 已经是与 `gitee.com/uctoo/uctoo` 一致的 v4 开源库（vben-admin-pro 5.0.1 + pnpm 9.7 + turbo 2.0，已含 `@uctoo/backend`、`@uctoo/app-client-pc`、`apps/web-admin`），它本身就是一套成熟 monorepo，可作为新本地环境的**脚手架参照与目标同构对象**。

### 1.2 项目目标

1. 选型并落地一套本地 monorepo 管理工具，统一承载 v4 全部产品。
2. 将旧 `uctoo-admin` 中属于 v4 的开发环境（脚手架、工具链、agent 配置）迁移到 `D:\UCT\projects\uctoo`。
3. 旧目录中的 v3 残留、参考资料、第三方实验目录**不纳入**新目录。
4. 在 `D:\UCT\projects\uctoo` 中模拟并固化"新人开发者从安装 PC 客户端 → 安装开发包 → 启动各子工程"的完整流程。

### 1.3 项目范围

**包含内容**：
- 目录选型研究与拍板（§2）。
- monorepo 管理工具选型研究与拍板（§3）。
- 新 monorepo 根目录脚手架（pnpm-workspace.yaml / turbo.json / package.json / .npmrc 等），与 v4 开源库同构。
- 5 个 v4 产品子工程在 workspace 中的目录归属与引用方式（§4）。
- 从旧 `uctoo-admin` 迁移开发环境的分步策略与清单（见 `design.md` / `tasks.md`）。
- 新人开发者本地环境搭建（onboarding）全流程设计与脚本（见 `design.md` §5）。

**不包含内容**：
- 各子工程的业务功能开发（后端 API、前端页面、客户端打包逻辑等），由各自 spec 负责：
  - `web-admin` 重构（淘汰 NestJS、web 提层）→ 见已有 `specs/web-admin-migration`。
  - PC 客户端打包 → 见已有 `specs/PcClientInstallerIntegration`。
  - `agentskills-runtime` 后端/Agent 能力 → 见 `specs/RuntimeNativeInstaller` 等。
- 鸿蒙客户端的正式开发（仅规划目录归属，技术栈后续研究）。

### 1.4 术语定义

| 术语 | 定义 |
|------|------|
| monorepo | 单一仓库管理多个包/子工程的代码组织方式 |
| workspace | pnpm 的"工作区"概念，一个根仓库下挂多个可互相引用的包 |
| pnpm Workspace | pnpm 原生的多包管理方案，靠 `pnpm-workspace.yaml` 声明成员目录 |
| Turborepo | 语言无关的构建/任务编排工具（task runner），按依赖图并行执行 build/dev/test 等任务 |
| cjpm | 仓颉语言的包管理与构建工具（对标 cargo/maven），独立于 pnpm |
| 开源库本体 | `D:\UCT\products\uctoo`，与 `gitee.com/uctoo/uctoo` 保持一致的 v4 仓库 |
| 开发主目录 | 本文选定的 `D:\UCT\projects\uctoo`，承载日常开发改造的本地 monorepo |
| onboarding | 新人从零到能跑通开发环境的引导流程 |

---

## 2. 目录选型分析（核心交付一）

### 2.1 候选对比

| 候选目录 | 现状 | 语义 | 作为开发主目录的适配度 |
|----------|------|------|------------------------|
| **A. `D:\UCT\projects\uctoo`** | 2026-10-10 新建的**空目录** | 项目/工作区（本地工程台） | ⭐⭐⭐⭐⭐ 推荐 |
| **B. `D:\UCT\products\uctoo`** | 已存在，是 v4 开源库（gitee 镜像），本身是 pnpm+turbo monorepo | 产品/发行（开源库 checkout） | ⭐⭐ 不推荐 |

### 2.2 结论与理由

**结论：选 A（`D:\UCT\projects\uctoo`）作为新 monorepo 根目录。**

理由：
1. **语义正确**：`products\uctoo` 是 v4 开源库的本地副本（`git remote` 指向 gitee），属于"产品/发行"语义；在其工作树上做日常开发改造会污染开源库、与上游同步冲突。而 `projects\uctoo` 今天是空目录、语义就是"工程/工作区"，迁移动作目标明确，与用户原始意图（"迁移到 D:\UCT\projects\uctoo"）一致。
2. **零污染、可重来**：A 是空目录，新建 monorepo 不受历史负担；旧 `uctoo-admin` 的 v3 残留可整体不碰、仅"挑选"需要的 v4 部分迁入。
3. **与开源库同构而非绑定**：A 的脚手架从 `products\uctoo` 借鉴（同样的 pnpm+turbo、同样的目录约定），保证"新人 clone 开源库 → 本地 A 开发"流程天然一致，但不共享 git remote，互不干扰。
4. **B 仍可作为"上游/参照"**：`products\uctoo` 保留为 v4 开源库的权威参考，新 monorepo 的脚手架模板、lint 配置、CI 配置均可从它同步，而非反过来。

> 备注：B 目录本身已是完备 monorepo（含 `apps/web-admin`、`@uctoo/backend`、`@uctoo/app-client-pc`），但它是"发行版"定位。如果未来希望开发主目录直接就是开源库，再考虑把 A 的内容反向同步到 B；本工程不这么做。

---

## 3. 工具选型分析（核心交付二）

### 3.1 候选对比

| 方案 | 语言/依赖管理 | 任务编排 | 与 v4 开源库同构 | 仓颉(cjpm)友好度 | 结论 |
|------|--------------|----------|------------------|------------------|------|
| **pnpm Workspace + Turborepo** | pnpm 管 Node 依赖，cjpm 独立目录 | Turborepo 语言无关 | ✅ 完全一致 | ✅ turbo 直接 `run build` 调 `cjpm build` | **推荐** |
| Nx | Nx 自带（可包 pnpm） | Nx 强但重 | ❌ 开源库未用 | ⚠️ 需自定义 executor | 过重、不一致 |
| Rush (Microsoft) | 自有 rush.json | rush 命令 | ❌ | ⚠️ | 学习成本高 |
| Bazel | BUILD 文件 | Bazel | ❌ | ⚠️ | 过重 |
| Lerna + pnpm | pnpm | lerna（已弱化） | ⚠️ | ✅ | 维护停滞，不如 turbo |

### 3.2 结论与理由

**结论：选 pnpm Workspace + Turborepo。**

理由：
1. **同构优先（最重要）**：`products\uctoo`（v4 开源库）已经验证 pnpm 9.7 + turbo 2.0 的组合，新本地环境直接复用同一套工具链，新人无需学第二套。
2. **语言无关，能统一多构建系统**：本工程有 5 类构建系统——仓颉 `cjpm`、前端 `vite`、PC 客户端 `electron-builder`、小程序 `uniapp(vite)`、鸿蒙 `cjpm/DevEco`。Turborepo 只负责任务调度（跑命令），不绑定语言，正好用 `turbo run build` 统一编排它们；pnpm 只管 Node 侧依赖，仓颉工程作为独立 workspace 成员存在（详见 §4）。
3. **轻量、快、生态成熟**：增量缓存（turbo cache）、任务依赖图、`--filter` 精确选包，都是开箱即用。
4. **与现有 spec 体系连贯**：`web-admin-migration`、`PcClientInstallerIntegration` 等子工程默认就在这个 workspace 约定下工作。

> 仓颉工程（cjpm）说明：pnpm 无法管理 `.cj` 依赖（cjpm 自行管理 `cjpm.toml`）。处理方式——把 `agentskills-runtime` 作为 workspace 内的普通目录（不要求它有 `package.json`），在 `turbo.json` 里为该包声明 `build`/`dev` 任务，由 turbo 调用 `cjpm build`（编译由人工在独立 cmd 执行，AI 不跑 cjpm，遵循既有铁律）。

---

## 4. v4 产品体系与 workspace 映射

uctoo v4 开源产品体系（用户确认）共 5 类，全部统一纳入新 monorepo：

| # | 产品 | 当前位置（旧 v3 环境） | 新 workspace 归属 | 技术栈 | 构建系统 | 备注 |
|---|------|------------------------|------------------|--------|----------|------|
| 1 | agentskills-runtime | `uctoo-admin/apps/agentskills-runtime` | `apps/agentskills-runtime` | 仓颉 (Cangjie) | cjpm | AI 驱动开发框架，后端 + Agent 基础设施 |
| 2 | web-admin | `uctoo-admin/apps/web-admin` | `apps/web-admin` | Vue3 + TS + OpenTiny | vite | **淘汰 NestJS**，将 `web/` 提一层到根（见 web-admin-migration） |
| 3 | PC 客户端 | `uctoo-admin/apps/agentskills-runtime-pc` | `apps/pc-client` | Electron | electron-builder | 打包 runtime + web，提供一键安装版 |
| 4 | 微信小程序 | `uctoo-admin/apps/miniapp`（旧版，仅参考） | `apps/miniapp` | uni-app | vite | 技术栈不变，旧目录仅作参考 |
| 5 | APP 客户端 | （暂无，未来） | `apps/harmonyos` | 仓颉原生 HarmonyOS | cjpm / DevEco | 未来规划，一个仓颉工程覆盖多端，后续研究 |

> 注：`products\uctoo` 开源库里另含 `@uctoo/backend`（NestJS）与 `@uctoo/app-client-pc`。按 v4 演进方向，后端能力由 `agentskills-runtime`（仓颉）承载、NestJS 逐步退役；PC 客户端由 `apps/pc-client`（electron）承载。新 monorepo 以运行时系（仓颉）为后端核心，`web-admin` 的 web 为前端核心，二者通过 WebMCP/API 协作。

---

## 5. 系统需求

### 5.1 功能需求

#### REQ-MONO-001: 选定并初始化 monorepo 根目录
**需求描述**: 系统应在 `D:\UCT\projects\uctoo` 初始化一套 pnpm Workspace + Turborepo 的 monorepo 根。

**验收标准**:
- [ ] 根目录含 `pnpm-workspace.yaml`，声明 `apps/*`、`packages/*`、`internal/*` 等成员
- [ ] 根目录含 `turbo.json`，定义 `build`/`dev`/`test`/`lint`/`typecheck` 任务
- [ ] 根目录含 `package.json`（`packageManager: pnpm@9.7.0`、禁止 npm 的 `preinstall` 守卫）
- [ ] 根目录含 `.npmrc`、`.node-version`、`README.md`（开发环境搭建说明）
- [ ] 脚手架与 `products\uctoo` 开源库保持同构

**优先级**: P0

#### REQ-MONO-002: 纳入 5 个 v4 子工程
**需求描述**: 系统应将 §4 的 5 个产品作为 workspace 成员纳入，并明确各自目录归属与构建方式。

**验收标准**:
- [ ] `apps/agentskills-runtime` 以 cjpm 工程形式存在，`turbo.json` 为其声明 cjpm 任务
- [ ] `apps/web-admin` 完成 web 提层（去除 NestJS），由 web-admin-migration spec 落地
- [ ] `apps/pc-client` 承载 electron 打包，由 PcClientInstallerIntegration spec 落地
- [ ] `apps/miniapp` 从旧目录迁入（仅参考旧版，技术栈不变）
- [ ] `apps/harmonyos` 仅建占位目录与 README，规划未来

**优先级**: P0

#### REQ-MONO-003: 从旧环境迁移开发脚手架
**需求描述**: 系统应将旧 `uctoo-admin` 中属于 v4 的开发环境（根配置、agent 配置、脚本）迁移到新目录，排除 v3 残留与参考资料。

**验收标准**:
- [ ] 迁移根级工具链配置（与开源库同构）
- [ ] 迁移 `.workbuddy` agent 配置（按需，非全盘）
- [ ] 旧目录的第三方 zip、实验子目录、v3 专用配置**不**进入新目录
- [ ] 提供迁移清单（见 `tasks.md`），可逐项核对

**优先级**: P1

#### REQ-MONO-004: 固化新人 onboarding 全流程
**需求描述**: 系统应在新 monorepo 中固化"新人从安装 PC 客户端到安装开发包"的可复现流程。

**验收标准**:
- [ ] 文档化"步骤一：安装 PC 客户端（agentskills-runtime-pc 出包的一键安装包）"
- [ ] 文档化"步骤二：clone/进入 `D:\UCT\projects\uctoo`，执行 `pnpm install`"
- [ ] 文档化"步骤三：按子工程初始化（runtime 编译、web 启动、pc-client 打包）"
- [ ] 提供可一键校验环境的前置检查脚本（node/pnpm/cangjie SDK 版本）
- [ ] 流程覆盖 §4 全部 5 个子工程的启动入口

**优先级**: P0

#### REQ-MONO-005: 多构建系统统一调度
**需求描述**: 系统应通过 Turborepo 统一调度不同子工程的 build/dev 任务。

**验收标准**:
- [ ] `pnpm dev` 可并行启动 web-admin 前端与（人工编译后的）runtime
- [ ] `pnpm build` 按依赖图依次构建（含 cjpm 工程）
- [ ] `--filter` 可按子工程名精确选包

**优先级**: P1

### 5.2 非功能需求

- **一致性**：新 monorepo 工具链与 `products\uctoo` 开源库保持一致（pnpm 9.7 / turbo 2.0 / Node 20+）。
- **可复现**：新人按文档操作可在 30 分钟内从零跑通开发环境。
- **清洁度**：新目录不得包含任何 v3 专用、第三方实验、参考资料类内容。
- **可扩展**：新增子工程（如 harmonyos）只需在 `pnpm-workspace.yaml` 追加目录并补 `turbo.json` 任务，无需改工具链。

### 5.3 约束性需求

#### 技术约束
- 包管理器：pnpm ≥ 9
- Node：≥ 20
- 任务编排：Turborepo ≥ 2
- 仓颉 SDK：cjc 1.1.3（与 agentskills-runtime 当前版本匹配）
- 前端：Vue 3 + TypeScript + Vite + OpenTiny Vue
- PC 客户端：Electron + electron-builder

#### 环境约束
- 开发主机：Windows（当前用户环境）
- 仓颉编译：**由用户在独立 cmd 执行 `cjpm build`**，AI 不参与编译（遵循既有铁律，避免沙箱段错误）
- 数据库：PostgreSQL（agentskills-runtime 后端）

---

## 6. 接口与数据需求

### 6.1 workspace 引用策略
- Node 侧包间通过 pnpm `workspace:*` 协议互相引用（如 `web-admin` 引用 `packages/*`）。
- 仓颉工程（cjpm）不进入 pnpm 依赖图，作为独立目录由 turbo 调度 `cjpm` 命令。
- 各子工程保持独立 git 历史（迁入时以目录复制/重定位方式，不强行合并 git）。

### 6.2 与开源库的关系
- `products\uctoo` 是脚手架与配置的"上游参照"，新 monorepo 单向借鉴，不反向提交。
- 版本号、目录约定、lint/ts 配置以开源库为准同步。

---

## 7. 验收标准

### 7.1 功能验收
- `D:\UCT\projects\uctoo` 成功初始化为 pnpm+turbo monorepo
- §4 的 5 个子工程全部在 workspace 中有明确归属
- 新人按 onboarding 文档可跑通"装 PC 客户端 → 装开发包 → 启动子工程"
- 旧 v3 残留/参考资料未进入新目录

### 7.2 质量验收
- 工具链与 `products\uctoo` 开源库同构（版本一致）
- `pnpm install` / `pnpm build --filter` 正常
- onboarding 流程文档清晰、可复现

---

## 8. 附录

### 8.1 参考文档
- `products\uctoo/package.json`（v4 开源库，pnpm 9.7 + turbo 2.0）
- `products\uctoo/pnpm-workspace.yaml`、`turbo.json`
- `products\uctoo/README.zh-CN.md`（v4 框架说明与 AI 驱动开发原则）
- 既有 spec：`specs/web-admin-migration`（web 提层）、`specs/PcClientInstallerIntegration`（PC 客户端）、`specs/RuntimeNativeInstaller`

### 8.2 相关项目
- **旧 v3 环境**: `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin`（迁移源，含 v3 残留）
- **v4 开源库本体**: `D:\UCT\products\uctoo`（与 `gitee.com/uctoo/uctoo` 一致）
- **新开发主目录（本文目标）**: `D:\UCT\projects\uctoo`（待初始化）
- **agentskills-runtime**: `uctoo-admin/apps/agentskills-runtime`（仓颉后端/Agent 框架）
- **web-admin**: `uctoo-admin/apps/web-admin`（前端，待提层去 NestJS）
- **PC 客户端**: `uctoo-admin/apps/agentskills-runtime-pc`（electron）
- **小程序**: `uctoo-admin/apps/miniapp`（旧版参考）

### 8.3 变更历史
| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0  | 2026-10-10 | SDD Agent | 初始版本，给出目录选型与工具选型结论 |
