# 动态大模型通道（Dynamic Model Channel）

> 子目录：`apps/agentskills-runtime/.codeartsdoer/specs/dynamic-model-channel/`
> 议题：把「支持哪些大模型通道」从**编译期硬编码**改为**运行时可配置数据**，切换 / 新增通道不重启 runtime，并可在管理后台可视化操作；通道协议适配器以 **L3 进程隔离轨技能插件**形态交付。
> 日期：2026-10-02
> 关联：`.codeartsdoer/specs/system-config`、`plugin-system`、`laya-system1-integration`、`docs/ref/AIDrivenArchitecture.md`

## 文档索引

| 文档 | 内容 |
|---|---|
| `problem-analysis.md` | 问题分析：现状证据（硬编码点 / 重启成因）、痛点分级、与框架设计哲学的冲突、约束 |
| `research.md` | 业界方案调研与差异化定位：LiteLLM / OpenRouter / OpenWebUI / Claude Code / deepseek-harness 等 |
| `spec.md` | 需求规格 REQ-DMC-001~021（功能 / 非功能 / 安全 / 兼容性 / 用户端聊天框通道切换器） |
| `design.md` | 架构设计：注册表、双模适配器、热生效链路、L3 插件轨、数据模型、API（含用户面 catalog）、前端（含聊天框切换器 §9.1）、迁移 |
| `chatComponent.png` | 用户端聊天框通道切换器的产品参考截图（REQ-DMC-021；组合通道三档归 laya-system1-integration） |
| `tasks.md` | 分期实施任务清单（Phase 0–3）与验收口径 |

## 一句话结论

把「通道清单」从 `model_manager.cj` 的编译期常量表（`DEFAULT_PROVIDER_MAP`，20 个 provider）搬进**数据库注册表 + 运行时热加载**，宿主只保留两类通用适配器（OpenAI 兼容直通 / L3 插件进程代理），新增或切换通道靠**数据**完成、不重启进程、后台可视化点选即可；私有协议通道以 L3 技能插件形态热插拔，凭证由宿主 `host.secret` 集中托管、插件不接触密钥本体——这既是 `AIDrivenArchitecture.md`「不硬编码业务功能」的落地，也是把「模型路由」做成框架一等能力（后续接 Laya System-1 自动选路）的地基。

## Web 前端入口提示（REQ-DMC-021 落地必读）

用户端通道切换器涉及 **两个 web 聊天入口**：`src/App.vue` 全局浮动 `TinyRemoter`（抽屉，最常用）与 `src/views/chat/index.vue` 的 `/chat` 路由页，二者共用只读目录 `GET /api/v1/uctoo/llm_channel/catalog` 与 localStorage 键 `uctoo_llm_channel_last`。通道按钮由 `llm-configs`（复数）prop 驱动，`TinyRobotChat.vue:68` 的 `v-if` 决定渲染。**改聊天代码前务必先定位正确文件**，完整文件地图与七条铁律见 `design.md` §9.2 与二次开发手册 `skills/uctoo-dev-manual/specs/web-chat-entry-points.md`（T037 曾因只接 `/chat` 漏接全局抽屉而看不到选择器）。
