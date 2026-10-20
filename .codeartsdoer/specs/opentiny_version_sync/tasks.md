# OpenTiny 技术栈官方版本同步合并 — 编码任务清单

> 本文档基于 `spec.md`（需求规格）与 `design.md`（技术设计，含 57 个合并项、21 步执行计划、4 级测试策略）生成，将技术设计转化为可独立执行、可验收的编码任务。
>
> **合并目标目录**：`apps/web-admin/web/src/lib/webmcp-sdk/`
> **官方源码目录**：`D:\UCT\products\gitcode\opentiny\` 下各仓库
> **执行环境**：`apps/web-admin/web`（vue-tsc / vite build / vitest）

---

> **⚠ 版本勘误（2026-09-24 复核，详见 `spec.md` §0）**：本清单中涉及「tiny-robot 0.5.2-alpha.15」的任务（T401~T403 等）前提不成立——该版本不存在，仅为 agent-skills 资产目录名；tiny-robot 官方最新 tag 为 `v0.5.1`，且官方 webmcp-sdk catalog 反而钉在更旧的 `0.3.1-alpha.6`。tiny-robot 建议**保持 0.5.1 不动**，相关升级任务降级为"待定"。另：官方 `package.json` 依赖全用 `catalog:` 协议，合并时须翻译为本地显式版本（严禁整文件替换，否则 web-admin 安装失败）；webmcp-cli 官方实际版本为 `0.0.9`。请以 `spec.md` §0 与 §5.6 为权威依据重新确认任务范围。

## 任务总览

| 维度 | 数值 |
|------|------|
| 主任务数 | 21（对应 design.md 21 步执行计划） |
| 任务组数 | 5（对应 spec.md 5 个功能模块） |
| 合并项总数 | 57（next-sdk 16 + webmcp-cli 24 + cli-skill 12 + tiny-robot 5） |
| 优先级分布 | P0×6 / P1×8 / P2×3 / 门禁×4 |
| 并行可能性 | 批次 2（webmcp-cli bridge）与 批次 3（cli-skill 重组）无相互依赖，可并行 |
| 关键冲突点 | 3 处（bin.ts 合并、tsup.config.ts 合并、tiny-robot API 兼容性） |

### 任务编号规则

- `T1xx`：批次 1 — next-sdk 核心更新合并（P0）
- `T2xx`：批次 2 — webmcp-cli bridge 架构合并（P1）
- `T3xx`：批次 3 — webmcp-cli-skill 目录重组（P1）
- `T4xx`：批次 4 — tiny-robot 版本升级（P2）
- `T5xx`：批次 5 — 兼容性验证与回归测试（门禁）

### 执行顺序总览

```
批次 1（P0，串行）→ 批次 2 ∥ 批次 3（P1，可并行）→ 批次 4（P2，串行）→ 批次 5（门禁，串行）
```

---

## 1. next-sdk 核心更新合并（P0）

**写作指导说明**：本组对应 spec.md §5.1 与 design.md §2.4.1（合并项 1-1~1-16），为 P0 必须合并项，涉及 a11y contenteditable 重构、initialize-builtin-WebMCP 大改、page-agent-tool 更新及配套测试与 Spec 同步。本组任务串行执行，是批次 2/3/4 的前置依赖。

> **✅ 批次 1 执行结果（2026-09-25）**：T101~T106 全部完成，采用「三方 diff（本地 vs v0.4.9 基线 vs v0.4.11 目标）+ 逐文件手工合入」，未发生任何整文件覆盖。
>
> | 任务 | 状态 | 落地文件 | 校验 |
> |---|---|---|---|
> | T101 | ✅ | `a11y/config.ts`、`a11y/utils.ts`、`a11y/vnode.ts` | 与 v0.4.11 逐字节一致 |
> | T102 | ✅ | `initialize-builtin-WebMCP.ts`（+149 行） | 258 行全等 |
> | T103 | ✅ | `page-agent-tool.ts`、`schema.ts` | 逐字节一致 |
> | T104 | ✅ | `a11y/build.test.ts`(+80)、`a11y/config.test.ts`(+42)、`initialize-builtin-WebMCP.test.ts`(+197)、`page-agent-tool.test.ts`(+104) | 逐字节一致 |
> | T105 | ✅ | `specs/REQ-20260904-contenteditable-a11y-ref/`（新增 3 文件）、`skills/page-agent/SKILL.md`、`specs/README.md` | 逐字节一致 |
> | T106 | ✅ | `next-sdk/package.json` version → `0.4.11` | 已完成 |
>
> **全量校验**：`packages/next-sdk` 在 v0.4.11 tag 下共 **137 个文件**，比对结果 `missing=0 / differ=2`，两处差异均为**预期保留**：
> 1. `agent/AgentModelProvider.ts`（1898 行，980 行差异）— **本地定制文件，禁止覆盖**。内含 v24「流式思维链标签增量拆分器」与 v25「`ReadableStreamDefaultController` 安全包装」（关闭后 enqueue 静默丢弃，避免下游 cancel 引发连锁 TypeError 吞掉已产出内容）。该文件对 v0.4.9 与 v0.4.11 差异行数相同（980），证实为本地增量而非版本落后。
> 2. `package.json`（44 行差异）— 全部为 `catalog:` → 本地显式版本翻译。已核对官方 `pnpm-workspace.yaml` catalog 值，与本地显式版本**完全一致**（`@ai-sdk/deepseek 1.0.30`、`ai ^6.0.0`、`@opentiny/next ^0.3.2`、`ajv ^8.17.1`、`zod ^3.25.76`、`qrcode ^1.5.4`、`@page-agent/page-controller ^1.10.0` 等），无版本落后。
>
> **后续**：批次 1 未做 vue-tsc / vitest 门禁（属批次 5 T501~T504 统一执行）。

### T101 合并 a11y contenteditable 重构

- **优先级**：P0
- **依赖任务**：无
- **对应合并项**：1-1、1-2、1-3
- **任务描述**：从官方 `packages/next-sdk/page-tools/a11y/` 替换本地三个文件至 v0.4.11 版本，使无障碍树对 contenteditable 元素的处理语义与官方一致。
- **输入**：
  - 官方：`D:\UCT\products\gitcode\opentiny\webmcp-sdk\packages\next-sdk\page-tools\a11y\config.ts`（+26 行）
  - 官方：`...\a11y\utils.ts`（+4 行）
  - 官方：`...\a11y\vnode.ts`（+11 行）
- **输出**：
  - 本地：`apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/page-tools/a11y/config.ts`
  - 本地：`...\a11y\utils.ts`
  - 本地：`...\a11y\vnode.ts`
- **验收标准**：
  - 三个文件内容与官方 v0.4.11 一致
  - 本地 `a11y/build.ts`、`search.ts` 引用 config/utils/vnode 无类型错误
- **风险点**：低 — 本地为 v0.4.9 基线，直接替换无冲突；需确认本地浏览器 DOM 环境与官方测试用例一致
- **回滚点**：`git checkout HEAD -- packages/next-sdk/page-tools/a11y/{config,utils,vnode}.ts` 恢复至 v0.4.9

### T102 合并 initialize-builtin-WebMCP 大改

- **优先级**：P0
- **依赖任务**：无（可与 T101 并行）
- **对应合并项**：1-4
- **任务描述**：替换 `initialize-builtin-WebMCP.ts` 至官方 v0.4.11 版本（+149 行），同步 polyfill 注入、桥接、forcePolyfill 默认行为变更。
- **输入**：官方 `packages/next-sdk/page-tools/initialize-builtin-WebMCP.ts`（+149 行）
- **输出**：本地 `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/page-tools/initialize-builtin-WebMCP.ts`
- **验收标准**：
  - 文件内容与官方 v0.4.11 一致
  - 调用 `initializeBuiltinWebMCP()` 在本地 jsdom 环境无报错
- **风险点**：中 — 149 行大改涉及 polyfill 注入策略调整，影响所有 WebMCP 初始化路径；需审查 polyfill 注入逻辑是否依赖本地浏览器特有 API
- **回滚点**：`git checkout HEAD -- packages/next-sdk/page-tools/initialize-builtin-WebMCP.ts`

### T103 合并 page-agent-tool 更新

- **优先级**：P0
- **依赖任务**：无（可与 T101、T102 并行）
- **对应合并项**：1-5、1-6
- **任务描述**：替换 `page-agent-tool.ts`（+18 行）与 `schema.ts`（+2 行）至官方 v0.4.11 版本，同步工具协议与返回结构变更。
- **输入**：
  - 官方 `packages/next-sdk/page-tools/page-agent-tool.ts`（+18 行）
  - 官方 `packages/next-sdk/page-tools/schema.ts`（+2 行）
- **输出**：
  - 本地 `...\page-tools\page-agent-tool.ts`
  - 本地 `...\page-tools\schema.ts`
- **验收标准**：
  - 两文件内容与官方 v0.4.11 一致
  - 上层 web-admin 调用 page-agent-tool 时 schema 校验通过
- **风险点**：低 — 18 行小改；需审查 schema 2 行变更对工具校验的影响
- **回滚点**：`git checkout HEAD -- packages/next-sdk/page-tools/{page-agent-tool,schema}.ts`

### T104 同步 next-sdk 新增测试文件

- **优先级**：P0
- **依赖任务**：T101、T102、T103（测试依赖被测源码已合并）
- **对应合并项**：1-8、1-9、1-10、1-11
- **任务描述**：合并官方新增的 4 个测试文件至本地 `test/page-tools/` 目录，其中 `page-agent-tool.test.ts` 本地可能已存在需对比合并。
- **输入**：
  - 官方 `packages/next-sdk/test/page-tools/a11y/build.test.ts`（80 行，新增）
  - 官方 `...\a11y\config.test.ts`（42 行，新增）
  - 官方 `...\initialize-builtin-WebMCP.test.ts`（197 行，新增）
  - 官方 `...\page-agent-tool.test.ts`（+104 行，可能合并冲突）
- **输出**：本地 `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-sdk/test/page-tools/` 下对应文件
- **验收标准**：
  - 4 个测试文件均存在
  - 执行 `pnpm -F @opentiny/next-sdk test` 全部通过（含 contenteditable 用例）
  - `page-agent-tool.test.ts` 若本地已有同名文件，合并后无重复用例
- **风险点**：中 — `page-agent-tool.test.ts` 可能存在合并冲突；新增 a11y 测试可能因本地 jsdom 版本差异失败
- **回滚点**：删除新增测试文件，`git checkout HEAD -- test/page-tools/page-agent-tool.test.ts`

### T105 同步 next-sdk Spec 与 SKILL.md

- **优先级**：P0
- **依赖任务**：无（文档同步，可与 T101~T104 并行）
- **对应合并项**：1-7、1-12、1-13、1-14、1-15
- **任务描述**：合并官方 Spec 三件套 `REQ-20260904-contenteditable-a11y-ref/`（requirements.md + design.md + tasks.md）至本地 specs/ 目录，同步 `skills/page-agent/SKILL.md`（+5 行）与 `specs/README.md`（+25 行，合并 Spec 索引）。
- **输入**：
  - 官方 `packages/next-sdk/specs/REQ-20260904-contenteditable-a11y-ref/{requirements,design,tasks}.md`
  - 官方 `packages/next-sdk/skills/page-agent/SKILL.md`（+5 行）
  - 官方 `packages/next-sdk/specs/README.md`（+25 行）
- **输出**：本地对应路径
- **验收标准**：
  - `specs/REQ-20260904-contenteditable-a11y-ref/` 三件套均存在
  - `SKILL.md` 内容与官方一致
  - `specs/README.md` 含 REQ-20260904 索引且无重复
- **风险点**：低 — 文档同步；`specs/README.md` 本地已有需合并索引避免重复
- **回滚点**：删除新增 Spec 目录，`git checkout HEAD -- skills/page-agent/SKILL.md specs/README.md`

### T106 更新 next-sdk package.json 版本号

- **优先级**：P0
- **依赖任务**：T101、T102、T103、T104、T105（全部 next-sdk 合并完成后）
- **对应合并项**：1-16
- **任务描述**：将 `packages/next-sdk/package.json` 的 `version` 字段从 `0.4.9` 更新至 `0.4.11`，与官方 tag 对齐。
- **输入**：本地 `packages/next-sdk/package.json`
- **输出**：本地 `packages/next-sdk/package.json`（version: 0.4.11）
- **验收标准**：
  - `version` 字段为 `0.4.11`
  - 执行 `pnpm install` 无依赖解析错误
- **风险点**：低 — 仅版本号变更
- **回滚点**：`git checkout HEAD -- packages/next-sdk/package.json`

---

## 2. webmcp-cli bridge 架构合并（P1）

**写作指导说明**：本组对应 spec.md §5.2 与 design.md §2.4.2（合并项 2-1~2-24），为 P1 建议合并项，引入 wxt 桥接架构（bridge/adapters/mcp/commands）与 bin.ts 大改。本组依赖批次 1 完成（webmcp-cli 通过 `file:../next-sdk` 依赖 next-sdk）。本组与批次 3 无相互依赖，可并行执行。

> **✅ 批次 2 执行结果（2026-09-25）**：T201~T205 全部完成。
>
> **重要事实修正**：`webmcp-cli 0.0.9` **不在** `v0.4.11` tag 内——该 tag 下 webmcp-cli 仍是 `0.0.8`（与 v0.4.9 完全相同，`git diff v0.4.9 v0.4.11 -- packages/webmcp-cli` 为空）。0.0.9 来自 v0.4.11 之后的单个未打 tag 提交 **`47a2b03 feat(webmcp-cli): 合并 WXT 扩展桥接模式与双向通信能力 (#554)`**（+4651 行 / 29 文件）。因此本批次的比对基线是 **官方 HEAD**，不是 v0.4.11。
>
> **合并方式**：本地 webmcp-cli 与 v0.4.9/v0.4.11 基线除 `package.json` 外**零差异**（无本地定制），故 23 个新增文件按官方内容落盘（纯新增，不构成覆盖），4 个修改类文件（`bin.ts` +220、`tsup.config.ts` +28、`parse-run-args.test.ts` +6、`package.json` +8）逐处手工合入，另按官方删除 2 个陈旧 fixture。
>
> | 任务 | 状态 | 落地内容 | 校验 |
> |---|---|---|---|
> | T201 | ✅ | `src/bridge/` 7 文件（bash-executor 242 / bridge-client 943 / daemon 424 / directory-picker 239 / protocol 58 / types 59 / workspace-manager 74） | 逐字节一致 |
> | T202 | ✅ | `src/adapters/` 3 文件（cdp-adapter 184 / interface 48 / wxt-adapter 107） | 逐字节一致 |
> | T203 | ✅ | `src/mcp/{server 347,tools 66}`、`src/commands/{agent 93,skills 112}` | 逐字节一致 |
> | T204 | ✅ | `src/bin.ts`（+220，WXT 模式预检 + mcp 子命令 + 模式路由 + `handleWxtMode` + `printWxtHelp`）、`tsup.config.ts`（拆分双 entry，bin.ts 关 dts 避免 tsc worker OOM）、`package.json` version → `0.0.9` | 逐字节一致 |
> | T205 | ✅ | `docs/third-party-agent-integration.md`(313)、`specs/REQ-20260921-wxt-bridge-merge/`(3 文件)、`test/` 5 个新增测试 | 逐字节一致 |
>
> **全量校验**：`packages/webmcp-cli` 在官方 HEAD 下共 **66 个文件**，比对结果 `missing=0 / differ=1`，唯一差异为 `package.json` 依赖翻译（预期保留）：
> - `catalog:` → 本地显式版本：`@mcp-b/webmcp-polyfill ^5.1.0`、`@modelcontextprotocol/sdk ~1.25.2`、`@page-agent/page-controller ^1.10.0`
> - `workspace:^` → `file:../next-sdk`
> - `zod`：官方写死 `^3.23.0`，本地对齐 lib 统一口径 **`^3.25.76`**（与 next-sdk 一致，避免重复安装两个 zod）
>
> **顺带修复**：`test/parse-run-args.test.ts` 的 fixture 由 `article.md` 改名为 `article-parse.md`（与 `expand-file-refs.test.ts` 的运行时写入 fixture 解耦，消除用例间竞争），并删除官方已移除的 `test/fixtures/article.md` 与 `test/fixtures/nested/args.json`。
>
> **风险提示**：`web-admin/package.json` **不依赖** webmcp-cli（只引用 `next-remoter` 与 `next-sdk` 两个 `file:`），故本批次对 web-admin 构建无影响。

### T201 合并 bridge 模块新增文件

- **优先级**：P1
- **依赖任务**：T106（批次 1 完成）
- **对应合并项**：2-1、2-2、2-3、2-4、2-5、2-6、2-7
- **任务描述**：从官方复制 `src/bridge/` 目录 7 个文件至本地，引入 daemon 守护进程、bridge-client 通信客户端、bash-executor 命令执行器等 wxt 桥接能力。
- **输入**：官方 `packages/webmcp-cli/src/bridge/{bash-executor,bridge-client,daemon,directory-picker,protocol,types,workspace-manager}.ts`
- **输出**：本地 `apps/web-admin/web/src/lib/webmcp-sdk/packages/webmcp-cli/src/bridge/` 下 7 个文件
- **验收标准**：
  - 7 个文件均存在且内容与官方一致
  - `bash-executor.ts`（242 行）经安全审查：无未转义的用户输入拼接 shell 命令
  - `daemon.ts`（424 行）IPC 通信仅限本地回环
- **风险点**：中 — `bash-executor.ts` 存在 shell 命令执行，需安全审查防止注入风险；`daemon.ts` 需确认 IPC 不暴露远程调用面
- **回滚点**：`rm -rf packages/webmcp-cli/src/bridge/`

### T202 合并 adapters 适配器抽象层

- **优先级**：P1
- **依赖任务**：T201（adapters 依赖 bridge 模块）
- **对应合并项**：2-8、2-9、2-10
- **任务描述**：从官方复制 `src/adapters/` 目录 3 个文件，建立 cdp/wxt 统一适配器抽象（`interface.ts` 定义 AdapterInterface，`cdp-adapter.ts` 对接 Puppeteer，`wxt-adapter.ts` 对接 bridge-client）。
- **输入**：官方 `packages/webmcp-cli/src/adapters/{cdp-adapter,interface,wxt-adapter}.ts`
- **输出**：本地 `...\packages\webmcp-cli\src\adapters\` 下 3 个文件
- **验收标准**：
  - 3 个文件均存在
  - `interface.ts` 定义统一 AdapterInterface 接口
  - `cdp-adapter.ts` 与 `wxt-adapter.ts` 均实现 AdapterInterface
  - TypeScript 编译通过（`tsc --noEmit`）
- **风险点**：低 — 全新增文件；`wxt-adapter.ts` 依赖 `bridge-client.ts`，需 T201 先完成
- **回滚点**：`rm -rf packages/webmcp-cli/src/adapters/`

### T203 合并 mcp 服务端与 commands 子命令

- **优先级**：P1
- **依赖任务**：T202（commands 依赖 adapters）
- **对应合并项**：2-11、2-12、2-13、2-14
- **任务描述**：从官方复制 `src/mcp/` 目录（server.ts + tools.ts）引入 MCP 服务端能力，复制 `src/commands/agent.ts` 与 `src/commands/skills.ts` 扩展 CLI 子命令。
- **输入**：
  - 官方 `packages/webmcp-cli/src/mcp/{server,tools}.ts`
  - 官方 `packages/webmcp-cli/src/commands/{agent,skills}.ts`
- **输出**：本地对应路径
- **验收标准**：
  - 4 个文件均存在
  - `server.ts`（347 行）与 `tools.ts`（66 行）编译通过
  - `agent.ts`（93 行）与 `skills.ts`（112 行）编译通过
- **风险点**：低 — 全新增文件；`agent.ts` 依赖 adapters，`skills.ts` 依赖 skills-sync 脚本
- **回滚点**：删除 `src/mcp/`、`src/commands/agent.ts`、`src/commands/skills.ts`

### T204 合并 bin.ts 大改（关键冲突点）

- **优先级**：P1
- **依赖任务**：T201、T202、T203（bin.ts 路由依赖 bridge/adapters/commands）
- **对应合并项**：2-15
- **任务描述**：合并 `src/bin.ts` 的 +220 行变更，对接 bridge 架构入口，新增 agent/skills/bridge 子命令路由，**保留本地已有 run/tabs/state/clipboard 命令路由**（cdp 兼容路径）。
- **输入**：
  - 官方 `packages/webmcp-cli/src/bin.ts`（v0.4.11，+220 行）
  - 本地 `packages/webmcp-cli/src/bin.ts`（v0.0.8，仅 cdp 命令）
- **输出**：本地 `...\packages\webmcp-cli\src\bin.ts`（合并后含旧命令 + 新命令路由）
- **验收标准**：
  - 执行 `webmcp-cli --help` 显示 run/tabs/state/clipboard（旧）+ agent/skills（新）命令
  - 旧命令行为与合并前一致（cdp 兼容路径未破坏）
  - 新命令 agent/skills 可识别并执行
- **风险点**：高 — **关键冲突点**：本地 bin.ts 为 v0.0.8，需手动合并 commander 命令注册，保留旧命令路由同时新增 agent/skills/bridge 命令；遗漏旧命令路由将破坏现有 cdp 场景
- **回滚点**：`git checkout HEAD -- packages/webmcp-cli/src/bin.ts`（恢复至 v0.0.8，仅旧命令）

### T205 合并 tsup 构建配置、测试与 Spec

- **优先级**：P1
- **依赖任务**：T201、T202、T203、T204（构建配置依赖全部新增模块）
- **对应合并项**：2-16、2-17、2-18、2-19、2-20、2-21、2-22、2-23、2-24
- **任务描述**：合并 `tsup.config.ts`（+28 行，新增 bridge 模块打包入口），复制 5 个新增测试文件，合并 `parse-run-args.test.ts`（+6 行，可能冲突），复制 Spec `REQ-20260921-wxt-bridge-merge/` 三件套，更新 `package.json` version 对齐官方。
- **输入**：
  - 官方 `packages/webmcp-cli/tsup.config.ts`（+28 行）
  - 官方 `packages/webmcp-cli/test/{bash-executor,bridge-client,daemon,directory-picker,workspace-manager}.test.ts`
  - 官方 `packages/webmcp-cli/test/parse-run-args.test.ts`（+6 行，可能冲突）
  - 官方 `packages/webmcp-cli/specs/REQ-20260921-wxt-bridge-merge/` 三件套
  - 官方 `packages/webmcp-cli/package.json`（version 字段）
- **输出**：本地对应路径
- **验收标准**：
  - `tsup.config.ts` 含 bridge 模块打包入口，执行 `pnpm build` 成功且 bridge 产物正确生成
  - 5 个新增测试文件均存在且通过
  - `parse-run-args.test.ts` 合并后无重复用例且通过
  - `specs/REQ-20260921-wxt-bridge-merge/` 三件套均存在
  - `package.json` version 对齐官方最新版本号
- **风险点**：中 — `tsup.config.ts` 本地已有需合并；`parse-run-args.test.ts` 可能合并冲突；需从官方确认 webmcp-cli 目标版本号
- **回滚点**：`git checkout HEAD -- packages/webmcp-cli/{tsup.config.ts,package.json,test/parse-run-args.test.ts}`，删除新增测试与 Spec 目录

---

## 3. webmcp-cli-skill 目录重组（P1）

**写作指导说明**：本组对应 spec.md §5.3 与 design.md §2.4.3（合并项 3-1~3-12），为 P1 建议合并项，将 `domains/` + 根目录 `SKILL.md` 旧结构重组为 `cdp/domains/` + `cdp/SKILL.md` + `wxt/SKILL.md` 新结构。本组与批次 2 无相互依赖，可并行执行。

> **✅ 批次 3 执行结果（2026-09-25）**：T301~T302 全部完成。
>
> **基线事实**：本地 `webmcp-cli-skill` 与官方 `v0.4.11` **10 个文件 0 差异**（无本地定制）；重组同样来自提交 `47a2b03`。
>
> | 任务 | 状态 | 落地内容 | 校验 |
> |---|---|---|---|
> | T301 | ✅ | `domains/` → `cdp/domains/`（7 个领域文档整体搬迁，**内容 0 改动**）；新增 `cdp/SKILL.md`(211 行) 与 `wxt/SKILL.md`(188 行)；删除旧根目录 `SKILL.md`(375 行) | 10 文件 0 差异 |
> | T302 | ✅ | 根级 `skills.manifest.json` 的 `localSkills` 新增 `webmcp-cli-cdp` / `webmcp-cli-wxt` 两条 | 0 差异 |
>
> **附带修复（同属 47a2b03）**：`scripts/skills-sync.mjs` 的 `removeDest()` 由「`lstatSync` + `rmSync`」改为「先 `unlinkSync`，失败再 `rmSync`」。原因是 Windows 上对**指向目录的 symlink** 调用 `rmSync(recursive:true)` 可能失败，先 unlink 可正确摘除符号链接本身。本地已同步该修复，现与官方 HEAD 0 差异。

### T301 迁移 cdp 目录结构与新增 wxt 文件

- **优先级**：P1
- **依赖任务**：无（与批次 2 可并行）
- **对应合并项**：3-1、3-2、3-3、3-4、3-5、3-6、3-7、3-8、3-9、3-10
- **任务描述**：创建 `cdp/` 目录，将 `domains/` 下 7 个 md 文件迁移至 `cdp/domains/`，将根目录 `SKILL.md` 迁移至 `cdp/SKILL.md`（对比本地 375 行与官方 211 行差异，保留本地自定义内容或对齐官方），新增 `wxt/SKILL.md`（188 行）与 `docs/third-party-agent-integration.md`（313 行）。
- **输入**：
  - 本地 `packages/webmcp-cli-skill/domains/*.md`（7 个文件）
  - 本地 `packages/webmcp-cli-skill/SKILL.md`（375 行）
  - 官方 `packages/webmcp-cli-skill/cdp/SKILL.md`（211 行）
  - 官方 `packages/webmcp-cli-skill/wxt/SKILL.md`（188 行，新增）
  - 官方 `packages/webmcp-cli/docs/third-party-agent-integration.md`（313 行，新增）
- **输出**：
  - 本地 `...\packages\webmcp-cli-skill\cdp\domains\*.md`（7 个文件）
  - 本地 `...\packages\webmcp-cli-skill\cdp\SKILL.md`
  - 本地 `...\packages\webmcp-cli-skill\wxt\SKILL.md`
  - 本地 `...\packages\webmcp-cli\docs\third-party-agent-integration.md`
  - 删除本地 `domains/` 目录与根目录 `SKILL.md`
- **验收标准**：
  - `cdp/domains/` 包含 7 个原 domain 文件，根目录 `domains/` 不再存在
  - `cdp/SKILL.md` 存在，根目录 `SKILL.md` 已移除
  - `wxt/SKILL.md`（188 行）存在且内容与官方一致
  - `docs/third-party-agent-integration.md`（313 行）存在
  - 全局搜索无旧路径 `domains/xxx.md` 或 `SKILL.md`（根目录）引用残留
- **风险点**：中 — `cdp/SKILL.md` 本地 375 行 vs 官方 211 行，需对比差异确认本地是否有自定义内容需保留；目录重组后需全局搜索旧路径引用并更新
- **回滚点**：将 `cdp/domains/` 迁回 `domains/`，将 `cdp/SKILL.md` 迁回 `SKILL.md`，删除 `wxt/` 与 `docs/third-party-agent-integration.md`

### T302 更新 skills.manifest.json 与 skills-sync 脚本

- **优先级**：P1
- **依赖任务**：T301（配置更新依赖新目录结构）
- **对应合并项**：3-11、3-12
- **任务描述**：合并 `skills.manifest.json`（+8 行，新增 cdp/wxt 技能发现配置）与 `scripts/skills-sync.mjs`（+5 行，适配新目录结构），确保技能同步脚本能发现 cdp 与 wxt 技能。
- **输入**：
  - 官方 `packages/webmcp-cli-skill/skills.manifest.json`（+8 行）
  - 官方 `packages/webmcp-cli-skill/scripts/skills-sync.mjs`（+5 行）
- **输出**：
  - 本地 `...\packages\webmcp-cli-skill\skills.manifest.json`
  - 本地 `...\packages\webmcp-cli-skill\scripts\skills-sync.mjs`
- **验收标准**：
  - 执行 `pnpm skills:sync` 成功
  - `skills.manifest.json` 含 cdp 与 wxt 技能条目
  - 技能同步脚本正确发现 `cdp/domains/` 与 `wxt/` 下技能
- **风险点**：中 — 若遗漏 `skills-sync.mjs` 的 5 行变更，脚本无法识别新目录结构；需确认本地是否有其他引用 `skills.manifest.json` 的代码
- **回滚点**：`git checkout HEAD -- packages/webmcp-cli-skill/{skills.manifest.json,scripts/skills-sync.mjs}`

---

## 4. tiny-robot 版本升级（P2）

**写作指导说明**：本组对应 spec.md §5.4 与 design.md §2.4.4（合并项 4-1~4-5），为 P2 谨慎合并项，涉及 tiny-robot 0.5.1 → 0.5.2-alpha.15 升级及本地适配代码修改。**必须先完成 API 兼容性评估，确认无致命断裂点后方可升级版本号**。本组依赖批次 1 完成（next-remoter 通过 `file:../next-sdk` 依赖 next-sdk）。

> **✅ 批次 4 执行结果（2026-09-25）**：按决策 **D1（tiny-robot 保持 0.5.1）** 执行，T402 完成，T401 与 T403 **不适用（N/A）**。
>
> **基线事实**：`next-remoter` 在官方 `v0.4.9 → v0.4.11` 之间**只有 package.json 版本号一行变更**（`git diff --stat` 输出仅 `packages/next-remoter/package.json | 2 +-`），`v0.4.11 → HEAD` 无任何变更。因此本批次不存在需要合并的官方源码改动。
>
> | 任务 | 状态 | 说明 |
> |---|---|---|
> | T401 | ⛔ N/A | tiny-robot 不升级，无需做 0.5.1 → 0.5.2-alpha.15 兼容性评估（该版本本就不存在） |
> | T402 | ✅ | `next-remoter/package.json` version → `0.4.11`；`@opentiny/tiny-robot`、`tiny-robot-kit`、`tiny-robot-svgs` **三处均保持 `0.5.1`** |
> | T403 | ⛔ N/A | 无目标版本可适配 |
>
> **本地定制文件盘点（均未改动，禁止覆盖）**：`packages/next-remoter` 共 70 个文件，与官方 v0.4.11 存在 **7 处差异**，全部为本地功能修复：
>
> | 文件 | 差异行 | 定制性质 |
> |---|---|---|
> | `src/composable/useTinyRobotChat.ts` | 445 | 本地会话编排主改造 |
> | `src/components/TinyRobotChat.vue` | 269 | 含 `linkifyTextNodes` 气泡文本修复（`m[1]`→`m[0]`） |
> | `src/composable/CustomAgentModelProvider.ts` | 53 | 本地模型提供器适配 |
> | `src/composable/useMessageRoles.ts` | 20 | 角色映射本地扩展 |
> | `src/composable/usePlugin.ts` | 7 | **v19 根治**：MCP 传输由 `streamableHttp` 改 `sse`（`StreamableHTTPClientTransport` 握手后发空 body notification → 后端 400 "Empty request body"；`SSEClientTransport` 走 GET+EventSource 不发空 body POST） |
> | `src/composable/usePluginSession.ts` | 1 | 引入 `vant` 的 `showLoadingToast` / `showToast` |
> | `package.json` | 64 | `catalog:` → 本地显式版本翻译；`workspace:*` → `file:../next-sdk`；**tiny-robot 三件套锁定 0.5.1**（官方 catalog 为更旧的 0.3.1-alpha.6）；**不含**官方声明的 `@opentiny/genui-sdk` / `@opentiny/genui-sdk-vue`（待 genui 方案 A 落地后按 D5 补入） |

### T401 执行 tiny-robot API 兼容性评估

- **优先级**：P2
- **依赖任务**：T106（批次 1 完成，next-remoter 依赖 next-sdk）
- **对应合并项**：无（评估任务，非文件合并）
- **任务描述**：对比本地 `node_modules/@opentiny/tiny-robot-kit`（v0.5.1）与官方 v0.5.2-alpha.15 的 `.d.ts` 类型声明文件，审计本地 next-remoter 中所有对 `@opentiny/tiny-robot-kit` 的 import 与 API 调用，标注断裂点位置、旧签名、新签名、适配方案，产出兼容性评估报告。
- **输入**：
  - 本地 `packages/next-remoter/node_modules/@opentiny/tiny-robot-kit/`（v0.5.1 类型声明）
  - 官方 `D:\UCT\products\gitcode\opentiny\tiny-robot\packages\kit\`（v0.5.2-alpha.15 源码与类型声明）
  - 本地 `packages/next-remoter/src/composable/{useTinyRobotChat,usePlugin,useSkill}.ts`（调用点）
- **输出**：兼容性评估报告（Markdown 文档，含断裂点清单、适配方案、致命断裂判定）
- **验收标准**：
  - 报告覆盖 `toolPlugin.ts`（+959 行）、`skillPlugin.ts`（+403 行）、`engine.ts`（+478 行）、`useConversation.ts`（+102 行）、`useMessage.ts`（+67 行）的 API 变更
  - 每个断裂点标注：调用位置、旧签名、新签名、适配方案
  - 明确结论：无致命断裂（可升级）或存在致命断裂（暂缓升级）
- **风险点**：高 — 0.5.2-alpha.15 为预发布版本，API 可能不稳定；`toolPlugin`/`skillPlugin`/`engine` 大改（合计 +1840 行）对本地适配代码影响大
- **回滚点**：无（评估任务不修改代码）

### T402 升级 tiny-robot 依赖版本号

- **优先级**：P2
- **依赖任务**：T401（兼容性评估结论为"无致命断裂"后方可执行）
- **对应合并项**：4-1、4-5
- **任务描述**：**tiny-robot 依赖保持 0.5.1 不变**（0.5.2-alpha.15 非真实版本，见 spec.md §0.2；官方 catalog 反而钉 0.3.1-alpha.6 更旧）。仅将 `version` 字段从 `0.4.9` 更新至 `0.4.11`，并在 0.5.1 下验证 useTinyRobotChat.ts 等适配代码的 API 兼容性。
- **输入**：本地 `packages/next-remoter/package.json`
- **输出**：本地 `packages/next-remoter/package.json`（三个依赖版本保持 0.5.1，version = 0.4.11）
- **验收标准**：
  - 三个 tiny-robot 依赖版本仍为 `0.5.1`（不引入 0.5.2-alpha.15 等不存在的版本）
  - `version` 字段为 `0.4.11`
  - 执行 `pnpm install` 依赖解析成功
- **风险点**：高 — alpha 版本可能存在未稳定 API；必须锁定确切版本避免漂移
- **回滚点**：`git checkout HEAD -- packages/next-remoter/package.json` 后 `pnpm install`

### T403 适配 next-remoter 代码至 tiny-robot 0.5.2-alpha.15

- **优先级**：P2
- **依赖任务**：T401、T402（根据评估报告适配，依赖版本号已升级）
- **对应合并项**：4-2、4-3、4-4
- **任务描述**：根据 T401 兼容性评估报告的断裂点清单与适配方案，修改 `useTinyRobotChat.ts`、`usePlugin.ts`、`useSkill.ts` 三个适配 composable，使其调用签名与 tiny-robot 0.5.2-alpha.15 一致。
- **输入**：
  - T401 兼容性评估报告（断裂点清单与适配方案）
  - 本地 `packages/next-remoter/src/composable/{useTinyRobotChat,usePlugin,useSkill}.ts`
- **输出**：本地三个 composable 文件（适配后）
- **验收标准**：
  - 执行 `vue-tsc --noEmit` 在 `packages/next-remoter` 零类型错误
  - 三个文件中所有对 `@opentiny/tiny-robot-kit` 的 API 调用签名与 v0.5.2-alpha.15 一致
  - 评估报告中的全部断裂点均已适配
- **风险点**：高 — 若存在致命断裂无法适配，需回滚 T402 并标记暂缓；适配过程中可能引入新的类型错误
- **回滚点**：`git checkout HEAD -- packages/next-remoter/src/composable/{useTinyRobotChat,usePlugin,useSkill}.ts`

---

## 5. 兼容性验证与回归测试（门禁）

**写作指导说明**：本组对应 spec.md §5.5 与 design.md §2.7（4 级测试策略），为合并完成后的门禁验证，依赖批次 1~4 全部完成。按 vue-tsc → vite build → vitest → 冒烟验证顺序串行执行，**禁止在类型检查或构建未通过的情况下声明合并完成**。

> **⏳ 批次 5 状态（2026-09-25）**：T501~T504 **待执行**。本批次依赖 `pnpm install` / 构建命令，按分工由用户执行；AI 侧已完成**不依赖安装**的静态核验：
>
> | 核验项 | 结果 |
> |---|---|
> | 4 个 `package.json` JSON 合法性 + 版本号 | ✅ next-sdk 0.4.11 / webmcp-cli 0.0.9 / next-remoter 0.4.11 / cli-skill 1.0.0 |
> | webmcp-cli `src/` 内部相对 import 解析（含 TS 的 `.js`→`.ts` 约定） | ✅ **43 处全部解析成功，0 未解析** |
> | `isBuiltinWebMCPPolyfill` 定义/引用闭环 | ✅ 定义于 `initialize-builtin-WebMCP.ts:32`，被 `page-agent-tool.ts:1/291` 引用 |
> | `isEditingHost` 定义/引用闭环 | ✅ 定义于 `a11y/config.ts:297`，被 `utils.ts:9/198`、`vnode.ts:11/105/193/195` 引用 |
> | 已重命名函数残留引用扫描 | ✅ `revealPolyfillOnDocument` 无残留；`neutralizeNativeDocumentModelContext` 仍为有效定义+调用 |
> | web-admin 影响面 | ✅ `web-admin/package.json` 仅依赖 `next-remoter`、`next-sdk` 两个 `file:`，`src/` 内**无** webmcp-cli 引用 → 批次 2/3 对 web-admin 构建无影响 |
>
> **待用户执行的命令**（在 `apps/web-admin/web` 下）：
> ```bash
> pnpm install                      # 拉入 webmcp-cli 新增的 ws / zod / @modelcontextprotocol/sdk
> npx vue-tsc --noEmit              # T501
> pnpm build                        # T502
> pnpm -F @opentiny/next-sdk test   # T503（需 lib 内安装 vitest）
> ```
> **注意**：lib 目录 `src/lib/webmcp-sdk/node_modules/.bin` 下目前**只有 prettier 与 mcp-inspector，没有 vitest**，T503 需先在 lib 内 `pnpm install`。另 lib 的 node_modules 里 tiny-robot 是陈旧的 `0.3.1-alpha.6`（官方 catalog 值），与 web-admin 实际使用的 `0.5.1` 不一致——**以 web-admin 的 0.5.1 为准**，lib 内的旧副本不影响构建。

### T501 执行 vue-tsc 类型检查

- **优先级**：门禁（必须通过）
- **依赖任务**：T106、T205、T302、T403（全部合并批次完成）
- **任务描述**：在 `apps/web-admin/web` 执行 `vue-tsc --noEmit` 全局类型检查，确保合并后零类型错误。
- **输入**：合并后的本地 webmcp-sdk 全部源码
- **输出**：类型检查报告（退出码 + 错误清单）
- **验收标准**：
  - 退出码 0，无类型错误
  - 重点检查：`next-remoter` 的 `useTinyRobotChat.ts`、`usePlugin.ts`、`useSkill.ts` 对 `tiny-robot-kit` API 的调用类型
  - 重点检查：`webmcp-cli` 的 `adapters`、`bridge`、`mcp` 新增模块类型
- **风险点**：中 — 若 tiny-robot 升级引入类型断裂，需回到 T403 补充适配；若 next-sdk 内部类型变更导致错误，确认官方测试是否覆盖
- **回滚点**：根据错误来源回滚对应批次（T106/T205/T302/T403）

### T502 执行 vite build 生产构建

- **优先级**：门禁（必须通过）
- **依赖任务**：T501（类型检查通过后）
- **任务描述**：在 `apps/web-admin/web` 执行 `vite build` 生产构建，确保合并后构建成功且产物生成。
- **输入**：合并后的本地 webmcp-sdk 全部源码
- **输出**：构建产物 + 构建报告
- **验收标准**：
  - 构建成功，产物生成
  - next-sdk 构建产物体积增量不超过 20%（相对 v0.4.9 基线，DFX 约束）
  - webmcp-cli bridge 相关产物正确生成（tsup 打包）
- **风险点**：中 — 依赖版本冲突（特别是 tiny-robot 0.5.2-alpha.15 的依赖解析）；构建配置变更（tsup.config.ts 的 bridge 模块打包）
- **回滚点**：根据错误来源回滚对应批次

### T503 执行 vitest 包级测试

- **优先级**：门禁（必须通过）
- **依赖任务**：T501（类型检查通过后，可与 T502 并行）
- **任务描述**：在 `packages/next-sdk` 执行 `pnpm test`（vitest），确保全部用例通过（含官方新增的 a11y、initialize-builtin-WebMCP、page-agent-tool 测试）。
- **输入**：合并后的 `packages/next-sdk/test/` 全部测试文件
- **输出**：测试报告（通过/失败用例清单）
- **验收标准**：
  - 全部用例通过
  - 必须通过的测试：
    - `test/page-tools/a11y/build.test.ts`（a11y 重构验证）
    - `test/page-tools/a11y/config.test.ts`（a11y 配置验证）
    - `test/page-tools/initialize-builtin-WebMCP.test.ts`（WebMCP 初始化验证）
    - `test/page-tools/page-agent-tool.test.ts`（工具协议验证）
- **风险点**：中 — 官方新增测试可能因本地 jsdom 环境与官方测试环境差异失败；本地已有测试失败表示回归
- **回滚点**：区分新增测试失败（排查环境差异）与回归失败（回滚对应批次）

### T504 执行核心路径冒烟验证

- **优先级**：门禁（建议通过）
- **依赖任务**：T502、T503（构建与包级测试通过后）
- **任务描述**：在本地浏览器环境对 4 条核心路径执行端到端冒烟验证：page-agent-tool DOM 操作、a11y 树构建、WebMCP 初始化、AI 对话消息流。
- **输入**：合并后的本地 webmcp-sdk + 本地浏览器环境
- **输出**：冒烟验证报告（每条路径的行为对比结果）
- **验收标准**：
  - **page-agent-tool DOM 操作**：执行 click、fill、search 等工具调用，工具协议与返回结构与合并前一致或符合官方 v0.4.11 预期
  - **a11y 树构建**：对含 contenteditable 元素的页面执行 `buildA11yTree`，树结构与官方 v0.4.11 行为一致
  - **WebMCP 初始化**：调用 `initializeBuiltinWebMCP()`，polyfill 注入成功，初始化行为与官方 v0.4.11 一致
  - **AI 对话消息流**：通过 `next-remoter` 的 `TinyRobotChat.vue` 发起对话，消息流处理、工具调用、技能插件行为正常
- **风险点**：中 — 端到端验证依赖本地浏览器环境；AI 对话消息流验证依赖 tiny-robot 0.5.2-alpha.15 运行时稳定性
- **回滚点**：定位回归点后回滚对应批次

---

## 任务依赖关系与执行顺序

### 依赖关系图

```
批次 1（P0，串行）：
  T101 ─┬─→ T104 ──→ T106
  T102 ─┤
  T103 ─┘
  T105 ──────────────→ T106

批次 2（P1，依赖批次 1，串行）：
  T106 ──→ T201 ──→ T202 ──→ T203 ──→ T204 ──→ T205

批次 3（P1，与批次 2 并行）：
  T301 ──→ T302

批次 4（P2，依赖批次 1，串行）：
  T106 ──→ T401 ──→ T402 ──→ T403

批次 5（门禁，依赖全部，串行）：
  T106, T205, T302, T403 ──→ T501 ──→ T502 ──→ T504
                              T501 ──→ T503 ──→ T504
```

### 执行顺序表

| 顺序 | 任务 ID | 任务标题 | 优先级 | 前置依赖 | 可并行 |
|------|---------|---------|--------|---------|--------|
| 1 | T101 | 合并 a11y contenteditable 重构 | P0 | 无 | 与 T102、T103、T105 并行 |
| 2 | T102 | 合并 initialize-builtin-WebMCP 大改 | P0 | 无 | 与 T101、T103、T105 并行 |
| 3 | T103 | 合并 page-agent-tool 更新 | P0 | 无 | 与 T101、T102、T105 并行 |
| 4 | T104 | 同步 next-sdk 新增测试文件 | P0 | T101、T102、T103 | — |
| 5 | T105 | 同步 next-sdk Spec 与 SKILL.md | P0 | 无 | 与 T101~T104 并行 |
| 6 | T106 | 更新 next-sdk package.json 版本号 | P0 | T101~T105 | — |
| 7 | T201 | 合并 bridge 模块新增文件 | P1 | T106 | 与批次 3 并行 |
| 8 | T202 | 合并 adapters 适配器抽象层 | P1 | T201 | — |
| 9 | T203 | 合并 mcp 服务端与 commands 子命令 | P1 | T202 | — |
| 10 | T204 | 合并 bin.ts 大改（关键冲突点） | P1 | T201、T202、T203 | — |
| 11 | T205 | 合并 tsup 构建配置、测试与 Spec | P1 | T201~T204 | — |
| 12 | T301 | 迁移 cdp 目录结构与新增 wxt 文件 | P1 | 无 | 与批次 2 并行 |
| 13 | T302 | 更新 skills.manifest.json 与 skills-sync 脚本 | P1 | T301 | — |
| 14 | T401 | 执行 tiny-robot API 兼容性评估 | P2 | T106 | — |
| 15 | T402 | 升级 tiny-robot 依赖版本号 | P2 | T401 | — |
| 16 | T403 | 适配 next-remoter 代码至 tiny-robot 0.5.2-alpha.15 | P2 | T401、T402 | — |
| 17 | T501 | 执行 vue-tsc 类型检查 | 门禁 | T106、T205、T302、T403 | — |
| 18 | T502 | 执行 vite build 生产构建 | 门禁 | T501 | — |
| 19 | T503 | 执行 vitest 包级测试 | 门禁 | T501 | 与 T502 并行 |
| 20 | T504 | 执行核心路径冒烟验证 | 门禁 | T502、T503 | — |

### 并行执行建议

1. **批次 1 内部并行**：T101、T102、T103、T105 无相互依赖，可并行合并；T104 依赖 T101~T103 完成后执行；T106 依赖全部完成后执行
2. **批次 2 与批次 3 并行**：webmcp-cli bridge（T201~T205）与 cli-skill 重组（T301~T302）无相互依赖，可分配给两名工程师并行执行
3. **批次 5 内部并行**：T502（vite build）与 T503（vitest）均仅依赖 T501，可并行执行

---

## 风险点汇总

| 风险等级 | 任务 ID | 风险项 | 影响范围 | 缓解措施 |
|---------|---------|--------|---------|---------|
| 高 | T204 | bin.ts 合并冲突（+220 行） | webmcp-cli 全部命令路由 | 手动合并 commander 命令注册，保留旧命令路由，新增 agent/skills/bridge 命令 |
| 高 | T401 | tiny-robot 0.5.2-alpha.15 API 不稳定 | next-remoter 全部 AI 对话功能 | 必须先评估再升级，锁定确切版本号，准备回滚方案 |
| 高 | T402 | toolPlugin/skillPlugin/engine 大改（+1840 行） | useTinyRobotChat/usePlugin/useSkill 适配代码 | 逐 API 对比签名差异，标注断裂点 |
| 高 | T403 | 适配代码可能引入新类型错误 | next-remoter 编译 | 根据 T401 评估报告逐个适配，vue-tsc 验证 |
| 中 | T102 | initialize-builtin-WebMCP 149 行大改 | 所有 WebMCP 初始化路径 | 同步官方测试，jsdom 环境验证，准备回滚 |
| 中 | T104 | a11y 新增测试可能因 jsdom 差异失败 | a11y 重构验证 | 排查本地 jsdom 版本与官方测试环境差异 |
| 中 | T201 | bridge bash-executor 安全风险 | CLI 安全性 | 审查 shell 命令拼接，确认无注入风险，IPC 仅限本地回环 |
| 中 | T205 | tsup.config.ts 与 parse-run-args.test.ts 合并冲突 | webmcp-cli 构建 | 对比本地与官方差异，手动合并 |
| 中 | T301 | cdp/SKILL.md 内容差异（本地 375 行 vs 官方 211 行） | 技能指引文档 | 对比差异，确认本地是否有自定义内容需保留 |
| 中 | T302 | skills-sync 脚本不兼容新目录结构 | 技能发现 | 合并 scripts/skills-sync.mjs 的 5 行变更 |
| 低 | T101 | a11y contenteditable 重构 | page-agent-tool 无障碍树 | 同步官方测试，jsdom 验证 |
| 低 | T103 | page-agent-tool 18 行小改 | 工具协议 | 同步官方测试，schema 校验 |

---

## 回滚方案

### 逐批次回滚策略

每个合并批次完成后创建一个 git commit，回滚时 `git revert <commit>` 或 `git reset` 到对应提交。

| 批次 | 回滚命令 | 回滚范围 | 回滚后状态 |
|------|---------|---------|-----------|
| 批次 1（T101~T106） | `git revert <batch1-commit>` | next-sdk 全部变更 | 回退至 v0.4.9 基线 |
| 批次 2（T201~T205） | `git revert <batch2-commit>` | webmcp-cli 全部变更 | 回退至 v0.0.8 基线 |
| 批次 3（T301~T302） | `git revert <batch3-commit>` | cli-skill 全部变更 | 回退至旧目录结构 |
| 批次 4（T401~T403） | `git revert <batch4-commit>` | tiny-robot 版本 + 适配代码 | 回退至 0.5.1 依赖 |

### 全量回滚

若多个批次均失败，执行全量回滚：

```bash
# 回滚到合并前的基线提交
git reset --hard <pre-merge-commit>
pnpm install
pnpm build
```

### 单任务回滚

每个任务均提供独立回滚点（见各任务的"回滚点"字段），支持单任务回滚而不影响其他任务。

---

## 持续集成建议

1. **批次级验证**：每完成一个批次即执行一次 `vue-tsc`，及早发现问题，而非等到全部合并完成后再统一验证
2. **关键冲突点重点审查**：T204（bin.ts 合并）、T401（API 兼容性评估）、T403（适配代码）为关键冲突点，需技术负责人审查后方可继续
3. **安全审查门禁**：T201（bash-executor）需安全审查通过后方可合并
4. **alpha 版本监控**：T402 升级至 0.5.2-alpha.15 后，关注官方正式版发布，正式版发布后及时升级

---

## 验收检查清单

- [ ] 批次 1 完成：next-sdk version = 0.4.11，a11y/initialize/page-agent 测试全通过
- [ ] 批次 2 完成：webmcp-cli bridge 架构可运行，`--help` 含新命令，旧命令行为不变
- [ ] 批次 3 完成：cli-skill 目录结构为 cdp/wxt 分离，`skills:sync` 正确发现技能
- [ ] 批次 4 完成：tiny-robot 依赖 = 0.5.2-alpha.15（锁定），适配代码 vue-tsc 通过
- [ ] T501 通过：vue-tsc 零错误
- [ ] T502 通过：vite build 成功，产物体积增量 ≤ 20%
- [ ] T503 通过：vitest 全用例通过
- [ ] T504 通过：4 条核心路径冒烟验证行为一致
- [ ] 安全审查：bash-executor 无注入风险，daemon IPC 仅限本地回环
- [ ] Spec 同步：REQ-20260904 与 REQ-20260921 三件套均存在

---

# 第 5 轮：npm 环境启动验证与 Vite 依赖扫描修复（2026-09-24）

## 变更背景

开发实际使用 **npm**（非前期文档假设的 pnpm）。用户执行 `npm install`（见 `npm.md`）后在 `apps/web-admin/web` 执行 `npm start`，输出见 `webstart.md`：

- `npm install`：仅 EBADENGINE 告警，`up to date in 29s`，562 packages，**安装层面无错误**
- `npm start`：Vite 6.4.3 正常 `ready in 33902 ms`，随后打印 18 条 `could not be resolved`，末行报
  `The file does not exist at ".../node_modules/.vite/deps/chunk-DZ5VRGCL.js"`（预构建产物不完整）

## 根因

**根因 A（主因）：Vite 依赖扫描把 vendor 进来的整个 monorepo 当成了应用入口。**

`apps/web-admin/web/src/lib/webmcp-sdk` 是把 OpenTiny 的整个 webmcp-sdk monorepo 拷进来的，其中 `packages/next-wxt/entrypoints/{options,sidepanel}/index.html` 是浏览器扩展的入口页。Vite 默认 `optimizeDeps.entries` 等价于对项目根做 `**/*.html` glob（只忽略 `node_modules`），因此这两个扩展入口页被当作扫描起点，其扩展专属依赖被判定为缺失：

| 报错依赖 | 引入文件 |
| --- | --- |
| `@wxt-dev/storage` | `next-wxt/entrypoints/options/utils/skills-storage.ts` |
| `jszip` | `next-wxt/entrypoints/options/SkillsTab.vue` |
| `puppeteer-core/lib/esm/puppeteer/puppeteer-core-browser.js` | `next-wxt/entrypoints/sidepanel/utils/snapshotManager.ts` |

**根因 B：`@opentiny/genui-sdk-vue` alias 指向仓外目录，导致 Node 解析起点漂移。**

`config/vite.config.base.ts` 把 `@opentiny/genui-sdk-vue` 别名指到 `D:/UCT/products/gitcode/opentiny/genui-sdk/packages/frameworks/vue/src/index.ts`。sidepanel 入口扫描到它之后，其自身 import 会以**仓外目录**为起点做 Node 解析——所以即便 `@opentiny/tiny-robot`、`prettier`、`uuid` 在 `apps/web-admin/web/node_modules` 里确实存在（已逐条核实），也照样报 unresolved。

**根因 C（放大器）：`optimizeDeps.excludeScan` 是无效配置。**

原配置试图用 `optimizeDeps.excludeScan` 排除 next-wxt，但该字段在 Vite 6.4.3 的 `node_modules/vite/dist/node/index.d.ts` 中 **grep 计数为 0**，即从未生效。

**根因 D：**上述扫描失败导致 optimize 元数据不完整，浏览器侧已优化的 chunk 与磁盘不一致，遂抛出 `chunk-DZ5VRGCL.js` 缺失。

## 本轮变更清单

| 文件 | 变更 | 行号 |
| --- | --- | --- |
| `apps/web-admin/web/config/vite.config.base.ts` | 移除无效 `excludeScan`（3 个绝对路径项），改为 `entries: [resolve(__dirname, '../index.html')]`，并附背景注释 | 105-118 |

执行样例修正：`config/vite.config.prod.ts` 已有 `optimizeDeps` 但不含 `excludeScan`，无需改动；`config/vite.config.dev.ts` 经 `mergeConfig` 继承 base，无需改动。

同时清理了损坏的预构建缓存 `apps/web-admin/web/node_modules/.vite`。

## 待用户侧验证（npm）

```bash
cd apps/web-admin/web
rmdir /s /q node_modules\.vite
npm start
```

预期：18 条 unresolved 全部消失，不再出现 `chunk-*.js` 缺失。

## 第 5 轮结论：genui-sdk **尚未**正确集成

用户问「genui-sdk 已经正确集成了？」——**没有**。证据链：

1. `apps/web-admin/web/package.json` 中 `grep -n "genui"` **无命中**，即没有声明 `@opentiny/genui-sdk-*` 依赖
2. `apps/web-admin/web/node_modules/@opentiny/genui*` **不存在**，包从未安装
3. 应用侧唯一对 lib 的深链是 `src/views/chat/index.vue:75` → `packages/next-remoter/src/components/ChatRemoter.vue`，该文件只 import `TinyRemoter`，**不涉及 genui**
4. 全仓范围内 `import '@opentiny/genui-sdk-vue'` 只有 **1 处**：`packages/next-wxt/entrypoints/sidepanel/App.vue:9`（且只取 `RENDERER_SETTINGS_KEY`）——那是浏览器扩展的工程，本 web 应用根本不构建它
5. `next-remoter/src/components/TinyRobotChat.vue:500` 仍是注释「注：genui-sdk-vue 依赖已移除」，组件内**没有**任何 `GenuiRenderer` 的 import 或 `contentRendererMatches` 配置

**判定**：当前 web 应用无法渲染生成式 UI。`vite.config.base.ts` 里那条 genui alias 是历史遗留的"半截账"——它服务的唯一消费方（sidepanel）不被本应用构建，而本应用真实使用的聊天组件又没接上。alias 注释声称源码是 "patched genui-sdk-vue"，但实测 `D:/UCT/products/gitcode/opentiny/genui-sdk/packages/frameworks/vue/src/chat/GenuiChat.vue` 仍在 `import { AIClient, GeneratingStatus, STATUS } from '@opentiny/tiny-robot-kit'`，即**并未真正 patch**，注释与事实不符。

## 剩余任务

| 项 | 状态 | 说明 |
| --- | --- | --- |
| T501 类型门禁（`npm run vue-tsc` 或等价） | 待执行 | 批次 1~4 的静态合并已完成，未经类型门禁 |
| T503 单测（next-sdk a11y / initialize 等） | 待执行 | lib 侧测试跑 self-contained，需在其各自目录 `npm test` |
| Vite 启动修复的用户侧复验 | 待用户执行 | 见上方命令 |
| genui 集成（按第 4 轮拍板的"方案 A 可行性验证"结论） | 待拍板 | 需先决定是 vendor renderer-only 切片进 lib，还是直接退役该 alias |
| 批 5 / 收尾文档同步 | 进行中 | 本文档即第 5 轮记录 |

---

# 第 6 轮：HTML 产物（Artifact）在聊天中的渲染落地（2026-09-25）

## 需求

把 `apps/agentskills-runtime/output/report/2025高考数学第19题-题干与解题报告.html`
这类 Agent / 长程任务产出的完整 HTML 报告，显示在 web 项目的 agent 聊天对话中。
原始诉求包含「将 genui-sdk 正确集成到本地 lib 中」。

## 关键实测结论：genui-sdk **不适合也不能够**渲染完整 HTML

| 项 | 实测证据 |
| --- | --- |
| GenuiRenderer 输入契约 | `packages/frameworks/vue/src/renderer/renderer.types.ts` → `IRendererProps.content: string \| {[prop:string]:any}`，`GenuiRenderer.vue:106` 走 `repairJson(newVal)`，解析不出对象即 `isError=true` 落错误态。契约是 **schema JSON**（`{componentName:'Page'\|'Text'...}`），不是 HTML |
| 渲染产物 | 受控组件白名单（materials），无法还原任意 HTML/CSS |
| 接入代价 | `GenuiRenderer.vue:4` 硬依赖 `@opentiny/tiny-schema-renderer`；npm 实测 `1.0.0-beta.6` **unpackedSize 2.41 MB**，依赖 `@babel/core@7.18.13` + `@opentiny/tiny-engine-builtin-component@^2.6.0`（低代码引擎内置组件栈） |
| 旁证 | `next-remoter/src/components/TinyRobotChat.vue:500` 既有注释「genui-sdk-vue 依赖已移除…会引入整个 OpenTiny 低代码引擎栈」——**当初摘掉 genui 正是为躲这套依赖** |

另：`@opentiny/genui-sdk-core@0.0.1` 未发布到 npm（需 vendor，227 KB / 57 文件）。

**决策**：完整 HTML 文档走 **iframe 沙箱**渲染（Claude artifacts / ChatGPT canvas 同款做法），
不引入 genui。这样零新增依赖、零构建风险、100% 还原原文档样式。
genui 仅在未来需要「AI 实时生成交互式 schema 卡片」时再单独评估，不阻塞本报告渲染需求。

## 落地清单

| 文件 | 变更 |
| --- | --- |
| `next-remoter/src/components/HtmlArtifact.vue` | **新增**。iframe 沙箱渲染器：高度自适应（注入 probe 脚本 + postMessage，校验 `event.source` 与实例 id）、工具条（展开/下载/复制/新窗口/全屏）、`sandbox="allow-scripts allow-popups"`（**不给** `allow-same-origin`，iframe 处 opaque origin，脚本无法触碰父页 DOM/Cookie） |
| `next-remoter/src/composable/handleSchema.ts` | 扩展 `extractTextAndJson`：`ExtractedBlock` 增 `html-artifact`；识别 ` ```html `（限完整文档，`<!DOCTYPE html>`/`<html` 开头）、` ```artifact ` / ` ```htmlArtifact `（JSON `{title,url}` 或 `{title,html}`）；无法识别一律降级为 markdown 代码块，保证内容不丢 |
| `next-remoter/src/components/TinyRobotChat.vue` | 注册 `contentRendererMatches` 首条：`find` 命中 `content.type === 'html-artifact' \|\| 'html_artifact'`（兼容后端下划线写法），renderer 调 `HtmlArtifact`；无 html 亦无 url 时降级提示文本 |

接入点说明：`handleSchema.ts` 的输出经 `CustomAgentModelProvider.ts:531` 直接作为 `uiContent` 项，
其 `type` 正是 `contentRendererMatches` 的匹配键——这是 next-remoter 预留的标准扩展点，未改库内部逻辑。

## 验证结果

1. 解析器用例 **19/19 通过**，含对既有 ` ```schemaJson ` **回归**（前缀/中间/后缀三块、json 文本原样保留），以及 ` ```htmlArtifact ` 不被 ` ```html ` 误配、未闭合围栏、降级不丢内容。
2. 真实报告（34,976 字节 / 310 行）实测：解析为 `[markdown, html-artifact, markdown]`，HTML 完整保留（trim 语义，与 schemaJson 分支一致），`<title>`/`footer` 均在；测高脚本注入到 `</body>` 前，注入后 35,363 字节，srcdoc 长度 28,969（远低于浏览器限制），`</script>` 仅 1 处无提前终止风险。
3. 预览 demo `output/report/_artifact-preview-demo.html`（44 KB）为 `HtmlArtifact.vue` 的纯 HTML 等价实现，可直接双击查看渲染效果。

> 注：next-remoter 包无测试基建（scripts 仅 dev/build），以上用例用 `node --experimental-strip-types` 直接跑真实源码完成。

## 端到端剩余一环

前端渲染能力已就绪，仍差「报告内容如何到达前端」。两条可选通路，**均无需改前端**：

1. **Agent 直接输出**：runtime 侧让 Agent 在最终回答里把报告以 ` ```html ` 围栏完整输出 → 前端 `extractTextAndJson` 自动识别为 artifact（零协议改动，推荐先走这条）；
2. **结构化推送**：后端经 SSE 推内容项 `{ type:'html_artifact', title, url }` 或 `{ type:'html_artifact', title, html }` → `contentRendererMatches` 同样命中（已兼容 `html_artifact` 与 `html-artifact` 两种写法）。

若报告体积大（本例 35 KB，尚可），建议优先走 `url` 形式避免消息体膨胀。记录 |
---

# 第 7 轮：LRT 产出报告自动进对话（runtime 侧接线，2026-09-24）

## 需求

接第 6 轮「端到端剩余一环」：把通路 2（结构化推送）在 runtime 侧接上，
让长程任务产出的 HTML 报告**自动**以 artifact 卡片出现在聊天对话里。

## 改动清单

| 文件 | 变更 |
| --- | --- |
| `runtime/src/app/services/bridge/lrt_event_bridge.cj` | ①`LrtEventType` 增 `ArtifactReady`，`wireName()` → `artifact_ready`；②新增 `pushArtifactReady(taskId, sessionId, agentId, title, html, artifactPath, traceId)`；③`dispatch` 增 SSE 单行幂等加固 |
| `runtime/src/plugin/lrt_event_relay.cj` | `host.event` 增 `case "artifact_ready"` 分支（供插件侧主动 emit 同一语义） |
| `runtime/src/app/services/lrt/lrt_host_executor.cj` | ①import 增 `LrtEventBridge`；②`runRound` 在 `patchPayload` 后调 `pushHtmlArtifactsToChat`；③新增 `MAX_HTML_ARTIFACT_BYTES`(1 MB)、`pushedHtmlArtifacts` 去重表、`pushHtmlArtifactsToChat` / `isHtmlArtifact` / `basename` |
| `next-remoter/src/components/TinyRobotChat.vue` | `handleLrtEvent` 增 `artifact_ready` 分支，push assistant 消息 `{ type:'html_artifact', title, html }` |

## 关键实测与依据

| 项 | 结论 |
| --- | --- |
| 包级依赖 | `.workbuddy/pkggraph.py` 实测 `lrt` 已直接依赖 `magic.app.services.bridge`，新增 import **不成环**（此前 `cyclic dependency: NONE`） |
| `session_id` / `trace_id` | 存于 `agent_tasks.payload`（`LongTaskApiService.buildInitialPayload`），非表列；纯 cron 任务无会话 → 早退 |
| 解码写法 | 与 `ScriptExecutor.decodeOutput` 完全一致的 try **表达式**（已验证可编译）：`try { String.fromUtf8(bytes) } catch (_) { unsafe { String.fromUtf8Unchecked(bytes) } }` |
| `String.replace` | std 文档只有 `replace`（无 replaceFirst/replaceAll）→ **全量替换**；`SyncController.cj:34` 的转义链亦依赖此语义 |
| `String.split` | 分隔符未命中时返回长度 1 的数组 → `basename` 安全；`contains` 已核实签名 |
| SSE 行协议 | `SSEConnectionManager` 帧为 `id/event/data` 三段 + `\n\n`；前端 `parseSSEBlock` **只收 `data:` 前缀行**且逐行 trim → data 必须单行 |

## 端到端传输验证（19/19 通过）

用真实报告（28,582 字节 / 309 行）跑完整链路「事件 JSON → SSE 帧 → parseSSEBlock → JSON.parse」：

- **A 正常路径**：序列化已转义 → 帧解析 1 条、HTML 字节数与内容**完全一致**、标题正确。
- **B 加固路径**：人为把 `\n` 还原为裸换行 → **未加固时确实解析失败**（反证加固必要）→ 加固后 JSON.parse 通过且内容一致。
- **C 幂等性**：已转义串再跑加固 **完全不变**、HTML 不被二次转义。
- **D 前端分支**：产出 1 条 assistant 消息、`content.type='html_artifact'`、html 原样透传；`html` 为空时不推空卡片。

> 前端读取器按 `\n\n` 累积 buffer，1 MB 级帧跨多个网络分块也能正确重组（前提是帧内无裸换行）。

## 待用户执行

1. **编译 runtime**（仓颉侧无法在本环境编译）：`cd apps/agentskills-runtime && cjpm build`，
   重点看 `lrt_host_executor.cj` 与 `lrt_event_bridge.cj` 两个文件。
2. 编译通过后跑一个会产出 `.html` 报告的长程任务，确认聊天区出现 artifact 卡片。
3. 第 5 轮的 Vite 修复仍需复验：`cd apps/web-admin/web && rmdir /s /q node_modules\.vite && npm start`。

## 已知取舍

- 单条产物上限 1 MB：更大的报告只留路径、不进对话（日志会记 `HTML 产物超过推送上限`）。
- 去重表在进程内存，runtime 重启后同一报告会再推一次（展示面，未做持久化）。
