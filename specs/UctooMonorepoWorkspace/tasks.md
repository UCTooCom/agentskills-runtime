# 任务清单

## 文档信息
- **项目名称**: uctoo v4 本地开发 monorepo 工程
- **关联**: `spec.md` / `design.md`
- **版本**: 1.0
- **创建日期**: 2026-10-10
- **作者**: SDD Agent

> 本清单是"从旧 v3 环境迁移到新 monorepo"的执行步骤，供评审通过后逐项落地。每项标注 file path / command / 验收，便于人工核对。

---

## 阶段一：脚手架（根配置，从 v4 开源库同构）

- [ ] **T1 初始化根目录**
  - 目录：`D:\UCT\projects\uctoo`（已存在空目录）
  - 验收：`ls D:\UCT\projects\uctoo` 可见根配置文件

- [ ] **T2 落 pnpm-workspace.yaml**
  - file: `D:\UCT\projects\uctoo\pnpm-workspace.yaml`
  - 内容：见 design.md §2.1（`apps/*`、`packages/*`、`internal/*`、`scripts/*`）
  - 验收：`pnpm install` 能识别成员

- [ ] **T3 落 turbo.json**
  - file: `D:\UCT\projects\uctoo\turbo.json`
  - 内容：见 design.md §2.2（含 `cj:build`/`cj:dev` 调 cjpm）
  - 验收：turbo 任务可被 `pnpm build`/`pnpm dev` 触发

- [ ] **T4 落根 package.json**
  - file: `D:\UCT\projects\uctoo\package.json`
  - 关键：`packageManager: pnpm@9.7.0`、`engines.node>=20`、`preinstall: only-allow pnpm`
  - 验收：`pnpm -v` 与声明一致

- [ ] **T5 落环境约束文件**
  - files: `.npmrc`、`.node-version`（20）
  - 验收：新人所装 Node 版本被约束

- [ ] **T6 同步 packages/ 与 internal/**
  - 来源：`D:\UCT\products\uctoo` 开源库（v4 权威形态）
  - 目标：`D:\UCT\projects\uctoo\packages\`、`internal\`
  - 验收：lint/ts/vite 配置与开源库一致

---

## 阶段二：子工程迁入（挑选 v4，排除 v3）

- [ ] **T7 迁入 agentskills-runtime（仓颉）**
  - 源：`uctoo-admin/apps/agentskills-runtime`
  - 目标：`D:\UCT\projects\uctoo\apps\agentskills-runtime`
  - 动作：整体复制 cjpm 工程；`.workbuddy` 按需
  - 验收：独立 cmd `cjpm build` 可编译（AI 不编译，遵循铁律）

- [ ] **T8 迁入 web-admin（web 提层、去 NestJS）**
  - 源：`uctoo-admin/apps/web-admin`
  - 目标：`D:\UCT\projects\uctoo\apps\web-admin`
  - 动作：复制 `web/` 提层到根；废弃 `nestJs/` 不纳入
  - 验收：由 `specs/web-admin-migration` 落地并验证

- [ ] **T9 迁入 PC 客户端**
  - 源：`uctoo-admin/apps/agentskills-runtime-pc`
  - 目标：`D:\UCT\projects\uctoo\apps\pc-client`（目录改名）
  - 验收：electron 工程可 `pnpm dev:pc` 启动
  - 关联：`specs/PcClientInstallerIntegration`

- [ ] **T10 迁入 miniapp（uni-app，旧版参考）**
  - 源：`uctoo-admin/apps/miniapp`（仅参考）
  - 目标：`D:\UCT\projects\uctoo\apps\miniapp`
  - 验收：uni-app 技术栈保留，旧版仅作参考

- [ ] **T11 建 harmonyos 占位**
  - 目标：`D:\UCT\projects\uctoo\apps\harmonyos`
  - 动作：仅建目录 + README（技术栈后续研究）
  - 验收：目录存在，README 说明规划

- [ ] **T12 排除项确认**
  - 不纳入：旧 `uctoo-admin` 的第三方 zip、实验目录（A2A/ACPs-community/HarmonyOS-Examples/CangjieMagic 等）、v3 专用配置、历史构建产物
  - 验收：新目录无上述内容

---

## 阶段三：onboarding 与验证

- [ ] **T13 写 README.md（新人 5 步上手）**
  - file: `D:\UCT\projects\uctoo\README.md`
  - 内容：装 PC 客户端 → 进开发目录 → `pnpm install` → `check-env` → 分工程启动
  - 验收：新人按文档可操作

- [ ] **T14 写环境检查脚本**
  - file: `D:\UCT\projects\uctoo\scripts\check-env.ps1`
  - 校验：Node≥20、pnpm≥9、cjc 1.1.3、PostgreSQL 可达
  - 验收：`pwsh scripts/check-env.ps1` 输出 PASS

- [ ] **T15 全量验证**
  - 命令：`cd D:\UCT\projects\uctoo && pnpm install`
  - 命令（人工）：`cjpm build`（agentskills-runtime，独立 cmd）
  - 命令：`pnpm dev:web`、`pnpm dev:pc`
  - 验收：前端/客户端可启动并调通 runtime

- [ ] **T16 走查 onboarding 可复现性**
  - 动作：从零模拟新人流程一次
  - 验收：30 分钟内跑通，无阻断

---

## 依赖与阻塞

| 任务 | 依赖 | 阻塞说明 |
|------|------|----------|
| T8 | web-admin-migration spec | 需先有 web 提层设计 |
| T9 | PcClientInstallerIntegration spec | 需先有 PC 打包设计 |
| T7 | cjc 1.1.3 环境就绪 | 编译由用户执行 |
| T6/T2/T3/T4 | `products\uctoo` 开源库可访问 | 同步脚手架来源 |
