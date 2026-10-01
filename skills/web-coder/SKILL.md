---
name: web-coder
description: 前端代码编写技能（纯技能形态，不派生子 agent）。当用户需要编写、修改、重构或优化 Web 前端代码（Vue 3 + Vite + TypeScript + TinyVue）时使用。遵循确定性优先：先在目标工程查到确定依据（既有实现 + 官方文档技能）再写代码，禁止凭跨栈/跨版本经验臆造 API。
version: 1.0.0
author: UCToo
# 纯技能形态：本技能**不建 agents/ 目录、不派生编码子 agent**。
# 依据（SDD tasks.md v3）："换脑子的才派生，换说明书的用技能"——
# 编码不需要换脑子，需要的是确定的 API 依据与工程内既有范式。
dependencies:
  - tiny-vue-skill          # OpenTiny TinyVue 组件库权威 API（本工程前端主用组件库）
  - frontend-dev            # 过渡期路由：web-coder 未挂载时的降级技能
---

# Web Coder 技能（纯技能形态）

## 概述

面向 **Vue 3 + Vite + TypeScript + TinyVue** 的前端编码技能。由**主 agent 加载后按 SOP 自行执行**，
不派生任何编码子 agent（SDD 六步 code 步的 web 语言分支即走这里）。

**触发场景**：新建/修改/重构 Vue 组件、页面、store、路由、Vite 配置、前端与后端接口对接。

## 与 cangjie-coder 同构的四步工作流

```
1. 查依据   → 官方文档技能（tiny-vue-skill）+ 工程内既有 import 先例 / 同类实现
2. 检索     → 在目标工程里检索可复制的既有正确代码（组件范式、请求封装、权限指令）
3. 编辑适配 → 复制 → 最小适配，禁止从零凭空生成
4. 自检     → 类型/依赖/约定自查（不执行构建，构建由人工在独立终端完成）
```

## 铁律（违反即视为返工）

1. **先查依据再写代码**：组件 API、插槽、事件名必须来自 `tiny-vue-skill` 或工程内既有用法，
   **禁止**凭 React/Angular/Element Plus 经验臆造 TinyVue 的 props 名。
2. **复制粘贴 + 二次编辑**：定位工程内既有正确实现 → 复制 → 最小适配。新建文件也必须
   先找一个同类型文件照结构写（目录结构、命名、导出方式照抄）。
3. **缺口必须显式标注**：查不到确定依据时，在回传里写明"缺什么依据、需要人工确认什么"，
   **禁止静默猜写**后当作已完成。
4. **不执行构建**：`npm run build` / `dev` 由人工在独立终端跑；AI 只产出代码与修复建议。
5. **改动只落在目标工程目录内**，不碰其他 app。

## 本工程既有约定（写码前必读，避免自造冲突）

- 包管理器用 **npm**（不是 pnpm）；`apps/web-admin/web` 为前端根。
- Vite 配置基线在 `vite.config.base.ts`：**必须显式声明 `optimizeDeps.entries`**（只指 `index.html`）。
  Vite 6 已无 `optimizeDeps.excludeScan`，不要写。
- 前端直连后端带 `Authorization: Bearer <token>`；接口前缀 `/api/v1/uctoo/...`。
- **SSE 是行协议**：推送多行内容前必须转义换行（裸换行会切断帧）。
- 表单/表格优先复用既有 `components/` 下的模式（add-* / edit-form / *-table 三件套）。

## 回传契约（code 步要求）

```json
{
  "changed_files": ["apps/web-admin/web/src/views/..."],
  "verify_passed": true,
  "language": "web",
  "skill_used": "web-coder",
  "gaps": ["未确认 TinyVue x.x 是否支持某 prop，需人工核对"]
}
```

`verify_passed=false` 时必须附失败项清单；走了过渡期路由（`frontend-dev`）必须在
`skill_used` 里写明，禁止静默 fallback。
