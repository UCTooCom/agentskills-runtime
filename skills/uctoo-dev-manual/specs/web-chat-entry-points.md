# Web 聊天入口与二次开发注意事项

> 适用：web-admin 前端（`apps/web-admin/web/`）聊天相关功能改动前的「定位地图」。
> 关联工程：`apps/agentskills-runtime/.codeartsdoer/specs/dynamic-model-channel`（REQ-DMC-021 用户端通道切换器，对应 design.md §9.1/§9.2）。
> 背景：曾出现「全局助手抽屉看不到通道选择器」的 bug（T037 漏接 App.vue 全局浮动 `TinyRemoter`），根因是**改错了聊天入口**——只接了 `/chat` 路由页，没接用户真正在用的全局抽屉。本文档就是为了避免下次再改错位置。

---

## 1. 聊天入口地图（改之前先认准文件）

web 端有 **两个聊天入口**，二者共用**同一个只读目录 API**（`GET /api/v1/uctoo/llm_channel/catalog`）和**同一个 localStorage 记忆键**（`uctoo_llm_channel_last`），但接线位置不同：

| 层 | 文件（相对 `apps/web-admin/web/`） | 角色 | 关键事实 |
|---|---|---|---|
| **入口 A（最常用）** | `src/App.vue` | 全局浮动 `TinyRemoter`（抽屉，`title="UCTOO 智能助手"`），挂在根组件，任何页面都能唤起 | 用 `TinyRemoter`（`@opentiny/next-remoter`）。**必须同时传 `:llm-config` 和 `:llm-configs` 两个 prop** + `v-model:selected-model-id`，通道按钮才出现 |
| **入口 B** | `src/views/chat/index.vue` | `/chat` 路由页（「AI 助手」整页） | 用 `ChatRemoter` 组件，传 `:channel-catalog="channelCatalog"`；同样调 `getChannelCatalog()` |
| 共享 SDK 层 | `src/lib/webmcp-sdk/packages/next-remoter/src/components/ChatRemoter.vue` | 封装 `TinyRemoter`，把 `channel-catalog` 透传给内部 | 一般**不要改**，只改调用方（App.vue / views/chat） |
| 共享 SDK 层 | `src/lib/webmcp-sdk/packages/next-remoter/src/components/TinyRobotChat.vue` | 真正渲染输入框 + 通道按钮 `<ModelSwitch>` | **第 68 行**：`<ModelSwitch v-if="llmConfigsRef">` —— 选择器**只要有 `llmConfigs` prop 就恒显**（V8 起不再用 `length>0` 门控；目录为空时显示「暂无可用通道」空态）。SDK 内部实现，非必要不碰 |
| 数据层（store） | `src/store/models/uctoo/llm_channel.ts` | Pinia ORM store，封装所有通道 API | `getChannelCatalog()` → `GET /api/v1/uctoo/llm_channel/catalog`（用户面只读目录）；其余 `add/edit/toggle/probe/...` 是管理 API |
| 后端聊天链路 | runtime `WebMCPController` → `WebMCPProtocol`（模型解析） | 用户选中的通道随每条聊天请求显式传参 `model:"<channel>:<modelId>"` | **切换实际生效在后端 `webmcp/mcp`，不在前端**；前端只负责把选择传出去 |
| 后端只读目录 | runtime `LlmChannelController` → `GET /llm_channel/catalog` | 返回 **scopes 含 `"global"`/`"user"` 的全部通道**（V8 起**不再过滤 `status`**），**字段已裁剪**（无 base_url / secret_ref / health），但**带 `status`**（供前端状态灯：enabled=绿、其余=红） | 普通用户可读；与管理 API RBAC 分离 |

---

## 2. 二次开发注意事项（七条铁律）

1. **双入口必须同步改。** 任何涉及「通道选择器显示/行为/记忆」的改动，要同时落在 `App.vue`（全局抽屉）和 `views/chat/index.vue`（/chat 页）。只改一个，两个入口表现会分裂（T037 教训）。

2. **通道选择器靠 `llm-configs`（复数）驱动，不是 `llm-config`（单数）。** `TinyRobotChat.vue:68` 的 `v-if` 只要有 `llmConfigsRef`（即 prop 已传入）就渲染，**不再要求数组非空**（V8 起恒显，空列表也显示）。只传 `:llm-config` 而不传 `:llm-configs` 时按钮**静默消失、无报错**——这是最隐蔽的坑。接线处必须：
   - `App.vue`：`:llm-config="llmConfig"` **且** `:llm-configs="llmConfigs"`
   - `views/chat/index.vue`：`:channel-catalog="channelCatalog"`（ChatRemoter 内部转成 `llmConfigs`）

3. **model id 严格用 `"<code>:<modelId>"`。** `llmConfigs` 的 `id` / `model` 字段必须拼成 `${c.code}:${c.default_model}`，与后端 T036 严格语义一致（不补前缀、不猜通道）。拼错 → 后端 `parseModel` 直接拒，聊天失败但不报「配置错」。

4. **前端只消费只读 `catalog` 目录 API，绝不用 `llm_channel` 管理 API 喂选择器。** 管理 API 返回含 `base_url` / `secret_ref` / `health` 等敏感/管理字段，且普通用户无权限；喂给选择器既越权又可能泄露。目录字段已裁剪，直接用 `getChannelCatalog()` 即可。

5. **用户可见哪些通道由后端决定。** 选择器渲染 `catalog` 返回的**全部**用户可见项（`scopes` 含 `"global"`/`"user"`，V8 起**含所有 `status`**）。每条带 `status`：前端用绿点（enabled）/红点（degraded·disabled）标识可用性，**红点只是提示、仍可点选**（点了后端按该通道解析，不可用则聊天报错）。前端不要自己再过滤或硬编码通道列表；想调整可见性 → 改后端 `scopes`，想调红绿 → 改后端 `status`（或修探针），不是前端。

6. **别动 `TinyRobotChat.vue` / `TinyRemoter` 内部（它们在 `lib/webmcp-sdk` 里，属 vendored SDK）。** 通道接线逻辑应写在 `App.vue` 和 `views/chat/index.vue`。只有确实需要改 SDK 组件交互（如下拉样式、多模态开关）才碰 SDK 文件，且改动会影响全工程所有用 TinyRemoter 的地方。

7. **改完必须重新 `npm run build` + 跑静态检查。** 任一 `.vue` 改动后，在 `apps/web-admin/web` 执行 `npm run build`；发布前过 `scripts/check-vue-refs.cjs`（拦截 `@opentiny/vue` 缺失组件、模板 `:icon` 未绑 script 变量等）。**仅凭「dist 里有相关字符串」不能证明接线正确**——T037 的 dist 已含选择器代码，但运行时因为没传 `:llm-configs` 就是不渲染。

---

## 3. 快速定位：我想改 X，该动哪个文件？

| 想改的东西 | 改这里 | 别改这里 |
|---|---|---|
| 全局助手抽屉（右下角浮动按钮）里的通道按钮 | `src/App.vue`（加/查 `fetchChannels` / `llmConfigs` / `:llm-configs`） | `views/chat`（那是另一个入口） |
| `/chat` 路由页的通道按钮 | `src/views/chat/index.vue` | `App.vue`（全局抽屉） |
| 通道下拉的渲染 / 交互 / 多模态开关 | `src/lib/webmcp-sdk/.../TinyRobotChat.vue`（SDK，谨慎） | 业务层 |
| 通道数据来源 / 字段 / 接口地址 | `src/store/models/uctoo/llm_channel.ts` + 后端 `LlmChannelController` | 前端接线 |
| 「切换通道后实际用哪个模型」 | 后端 `webmcp/mcp` → `WebMCPProtocol`（runtime，非前端） | 前端只负责传 `model:"<code>:<modelId>"` |
| 两个入口记住「上次选的通道」 | 两边都要保证 `localStorage` 键为 `uctoo_llm_channel_last`（已统一） | 不要一边改键名，否则记忆分裂 |

---

## 4. 一句话自检清单（动聊天代码前）

- [ ] 我改的是「全局抽屉」还是「/chat 页」还是「两者」？两者都涉及就必须都改。
- [ ] 通道按钮消失？先查接线的组件有没有传 `:llm-configs`（不是只有 `:llm-config`）。
- [ ] `model` 字段是不是 `<code>:<modelId>` 格式？
- [ ] 数据源是不是 `getChannelCatalog()`（只读目录），不是管理 API？
- [ ] 改完跑 `npm run build` + `check-vue-refs.cjs` 了吗？

---

## 5. 故障排查：通道按钮不显示 / 列表不对（V8 之后）

V8 起行为已变：切换器**恒显**——只要 `llmConfigs` prop 有传入（两入口都传），按钮就在；目录为空时显示「暂无可用通道」空态，**不再静默消失**。所以「完全看不到控件」基本只剩两类原因：

1. **接线漏了 `:llm-configs`**：`App.vue` 只传了 `:llm-config`、没传 `:llm-configs`，或 `views/chat` 没传 `:channel-catalog`。这种连按钮壳都不会出现。先核 `App.vue` 与 `views/chat/index.vue` 是否都接了（见 §1/§2）。
2. **目录 API 直接报错（404/500/网络/鉴权）**：`getChannelCatalog()` 被 `try/catch` 静默降级为 `[]`，于是「有按钮、但下拉是空的」。打开浏览器控制台看有没有 `Failed to fetch channel catalog` 报错；再直接 `curl` 后端 `GET /api/v1/uctoo/llm_channel/catalog` 确认返回体。

而「列表里该有的通道没出现 / 红绿点不对」则看数据：
- **只显示部分通道**：`catalog` 现在返回 `scopes` 含 `"global"`/`"user"` 的全部通道（含 degraded/disabled）。若某通道没出现，先看它的 `scopes` 是不是不在这两个值里（如被设成 admin-only）。
- **红绿点不对**：点 = `status === 'enabled'`（绿），其余（degraded / disabled / 空）红。红 = 该通道当前因探针失败 / 手动停用不可用；想变绿 → 修该通道真实配置或探针（不是前端改）。

> 注：V8 之前的老文档/记忆可能写「按钮不显示 = 目录为空（`status` 非 enabled）」——那套因果已过时。现在目录不过滤 `status`、按钮恒显；只有上面两类接线/接口问题会让它异常。另：`VITE_BACKEND_URL` 在本项目本地开发经 OS hosts 映射到 127.0.0.1，是刻意模拟生产，**不是打真生产**，排障时默认按本地处理。
