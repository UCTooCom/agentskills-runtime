# 编码任务清单：聊天发送/停止按钮

> 本文档基于 `spec.md`（需求规格）与 `design.md`（技术设计）生成，将技术方案分解为可独立执行、可验收的编码任务。
>
> - **方案概要**：新增 `SendStopButton.vue` 自定义复合按钮 + 修改 `TinyRobotChat.vue`（3 处修改），复用现有 `abortRequest` / `handleSendMessageCustom` / `senderLoading` 链路，不修改第三方库源码。
> - **影响范围**：`apps/web-admin/web/src/lib/webmcp-sdk/packages/next-remoter/src/components/` 目录下 1 个新增文件 + 1 个修改文件 + 1 个新增测试文件。
> - **执行原则**：垂直切割（按业务功能分组）、原子性（一任务一事件）、有序性（被依赖者在前）、可验收（每任务有明确完成标准）。

---

## 任务总览

| 任务 ID | 任务标题 | 优先级 | 依赖任务 | 所属分组 |
|---------|---------|--------|---------|---------|
| T001 | 搭建 SendStopButton 组件骨架与类型契约 | P0 | - | G1 SendStopButton 组件开发 |
| T002 | 实现按钮图标切换与禁用态渲染 | P0 | T001 | G1 SendStopButton 组件开发 |
| T003 | 实现点击事件分发（submit/cancel） | P0 | T001, T002 | G1 SendStopButton 组件开发 |
| T004 | 编写组件样式复用库内置类名 | P0 | T001 | G1 SendStopButton 组件开发 |
| T005 | 在 TinyRobotChat 导入并注册 SendStopButton | P0 | T001 | G2 TinyRobotChat 集成修改 |
| T006 | 在 #footer-right 插槽接入 SendStopButton | P0 | T005 | G2 TinyRobotChat 集成修改 |
| T007 | 隐藏 tr-sender 内置 SubmitButton 避免重复 | P0 | T005 | G2 TinyRobotChat 集成修改 |
| T008 | vue-tsc 类型检查通过 | P0 | T004, T007 | G3 兼容性验证与回归测试 |
| T009 | vite build 构建验证通过 | P0 | T007 | G3 兼容性验证与回归测试 |
| T010 | 编写 vitest 单元测试覆盖 7 个场景 | P1 | T007 | G3 兼容性验证与回归测试 |
| T011 | 执行手动验证清单 7 项 | P1 | T009 | G3 兼容性验证与回归测试 |
| T012 | 验证回滚方案有效性 | P1 | T007 | G4 回滚与风险验证 |

**任务依赖图**：

```
T001 ─┬─> T002 ─┬─> T003
      │          │
      └─> T004   │
                  │
T001 ─> T005 ─┬─> T006
              │
              └─> T007 ─┬─> T008 (依赖 T004+T007)
                        │
                        ├─> T009
                        │
                        ├─> T010
                        │
                        ├─> T011 (依赖 T009)
                        │
                        └─> T012
```

**执行顺序建议**：T001 → T002 → T004 → T003 → T005 → T006 → T007 → T008 → T009 → T010 → T011 → T012

---

## G1. SendStopButton 组件开发

> **业务目标**：实现一个始终可见的发送/停止复合按钮，根据 Agent 运行状态在同一位置切换图标与行为，解决 tr-sender 内置按钮在输入框为空时 DOM 不存在的问题。
>
> **新增文件**：`apps/web-admin/web/src/lib/webmcp-sdk/packages/next-remoter/src/components/SendStopButton.vue`

### T001 搭建 SendStopButton 组件骨架与类型契约

- **优先级**：P0
- **依赖任务**：无
- **任务描述**：
  - 创建 `SendStopButton.vue` 文件，使用 `<script setup lang="ts">` 语法
  - 定义 `SendStopButtonProps` 接口，包含 `loading: boolean`、`disabled: boolean`、`stopText?: string`、`size?: 'normal' | 'small'` 四个属性
  - 定义 `SendStopButtonEmits` 接口，包含 `submit` 与 `cancel` 两个事件（均无参数）
  - 通过 `defineProps<SendStopButtonProps>()` 与 `defineEmits<SendStopButtonEmits>()` 应用类型契约
  - 添加默认值：`loading` 默认 `false`、`disabled` 默认 `false`、`size` 默认 `'normal'`
  - 组件不包含任何业务逻辑，仅做 UI 展示与事件分发
- **输入**：design.md §2.2.2 接口签名定义
- **输出**：`SendStopButton.vue` 文件骨架（含 props/emits 类型定义，模板与样式暂为占位）
- **验收标准**：
  - 文件存在于 `next-remoter/src/components/SendStopButton.vue`
  - props/emits 类型定义无 `any`，与 design.md §2.2.2 完全一致
  - `npx vue-tsc --noEmit` 对该文件无类型错误（独立可编译）
- **风险点**：
  - `defineProps` 泛型写法需配合 `withDefaults` 设置默认值，注意 Vue 3.3+ 的类型推断要求
  - `size` prop 的字面量联合类型需确保与 tr-sender 的 size 类型一致，避免类型不兼容
- **回滚点**：删除 `SendStopButton.vue` 文件即可，无副作用

### T002 实现按钮图标切换与禁用态渲染

- **优先级**：P0
- **依赖任务**：T001
- **任务描述**：
  - 从 `@opentiny/tiny-robot-svgs` 导入 `IconSend` 与 `IconStop` 图标组件
  - 在 `<template>` 中渲染根元素 `<div class="tr-sender-submit-button">`，类名与 tr-sender 内置按钮保持一致以复用库内置 CSS
  - 根据 `loading` 状态条件渲染图标：`loading=false` → 渲染 `<IconSend />`；`loading=true` → 渲染 `<IconStop />`（可选附加 `stopText` 文案）
  - 根据 `disabled` 与 `loading` 计算禁用态：`loading=true` 时强制可点击（停止按钮始终可用）；`loading=false && disabled=true` 时添加 `is-disabled` 类名
  - `loading=true` 时添加 `is-loading` 类名，与库内置加载态样式一致
  - 通过 `size` prop 控制 `--tr-action-button-size` CSS 变量，与 tr-sender 的 size prop 保持一致
- **输入**：T001 产出的组件骨架；design.md §2.4.1 设计要点 1-2、§2.5.1 样式策略
- **输出**：`SendStopButton.vue` 的 `<template>` 与图标渲染逻辑完成
- **验收标准**：
  - `loading=false` 时 DOM 中存在 `IconSend`，不存在 `IconStop`
  - `loading=true` 时 DOM 中存在 `IconStop`，不存在 `IconSend`
  - `loading=false && disabled=true` 时根元素包含 `is-disabled` 类
  - `loading=true` 时根元素包含 `is-loading` 类，且不包含 `is-disabled` 类（停止按钮始终可点击）
  - 图标导入路径 `@opentiny/tiny-robot-svgs` 与 `TinyRobotChat.vue:119` 现有导入一致
- **风险点**：
  - `IconSend` / `IconStop` 需确认 `@opentiny/tiny-robot-svgs` 已导出这两个图标（参考 design.md §1.1.1 已验证 tr-sender 内置使用相同图标）
  - 条件渲染使用 `v-if` 而非 `v-show`，避免两个图标同时存在于 DOM
- **回滚点**：清空 `<template>` 内容回退到 T001 骨架状态

### T003 实现点击事件分发（submit/cancel）

- **优先级**：P0
- **依赖任务**：T001, T002
- **任务描述**：
  - 在根元素上绑定 `@click` 事件处理函数 `handleClick`
  - `handleClick` 逻辑：
    - 若 `loading=true` → 调用 `emit('cancel')`（停止按钮点击）
    - 若 `loading=false && disabled=true` → 直接 return，不触发任何事件（禁用态点击无响应）
    - 若 `loading=false && disabled=false` → 调用 `emit('submit')`（发送按钮点击）
  - 停止按钮的快速连续点击幂等性由父组件 `abortRequest` 的 `.catch(() => {})` 兜底保证，组件层不额外防抖
- **输入**：T001, T002 产出；design.md §2.1.3 状态切换流程、§2.2.2 后置条件
- **输出**：`SendStopButton.vue` 的点击事件分发逻辑完成
- **验收标准**：
  - `loading=false && disabled=false` 时点击 → 触发 `submit` 事件一次
  - `loading=true` 时点击 → 触发 `cancel` 事件一次
  - `loading=false && disabled=true` 时点击 → 不触发任何事件
  - 满足 spec.md §5.1.1 规则 3（空内容禁止发送）与 §5.2.3 异常场景 3（快速连续点击幂等）
- **风险点**：
  - 禁用态点击需确保事件不冒泡到父级，可在 `handleClick` 开头 `if (disabled && !loading) return` 提前返回
  - 不要在组件内部调用 `event.stopPropagation()`，以免影响 tr-sender 容器的事件委托
- **回滚点**：移除 `@click` 绑定与 `handleClick` 函数

### T004 编写组件样式复用库内置类名

- **优先级**：P0
- **依赖任务**：T001
- **任务描述**：
  - 在 `SendStopButton.vue` 的 `<style scoped lang="less">` 中编写样式
  - 根元素类名 `tr-sender-submit-button` 复用 tiny-robot 库内置按钮样式（尺寸、颜色、hover 效果）
  - 禁用态 `is-disabled` 样式：降低透明度（`opacity: 0.5`）+ `cursor: not-allowed` + `pointer-events: none`（确保点击事件不触发）
  - 加载态 `is-loading` 样式：与库内置停止按钮视觉反馈一致
  - 明暗主题适配：由于复用库内置类名，主题切换由 tiny-robot 库的 CSS 变量自动处理，组件内不硬编码颜色
  - 尺寸适配：通过 `size` prop 动态设置 `--tr-action-button-size` CSS 变量
- **输入**：T001 产出；design.md §2.5.1 样式策略、§2.5.2 与现有 UI 一致性
- **输出**：`SendStopButton.vue` 的 `<style>` 块完成
- **验收标准**：
  - 组件在明暗主题下样式正确（复用库内置 CSS 变量）
  - 禁用态鼠标悬停显示 `not-allowed` 光标，点击无响应
  - 按钮尺寸与 tr-sender 内置按钮一致（通过 `--tr-action-button-size` 变量控制）
  - 不引入硬编码颜色值，所有颜色通过 CSS 变量或库内置类名继承
- **风险点**：
  - `pointer-events: none` 会阻止点击事件触发，需与 T003 的禁用态判断配合（CSS 层与 JS 层双重保障）
  - scoped 样式下类名 `tr-sender-submit-button` 需确认是否需要 `:deep()` 穿透（本组件根元素自身使用该类名，无需穿透）
- **回滚点**：清空 `<style>` 块

---

## G2. TinyRobotChat 集成修改

> **业务目标**：将 SendStopButton 组件接入 TinyRobotChat.vue 的 tr-sender `#footer-right` 插槽，替换库内置 SubmitButton 的可见性策略，同时保持回车键发送与现有交互行为不变。
>
> **修改文件**：`apps/web-admin/web/src/lib/webmcp-sdk/packages/next-remoter/src/components/TinyRobotChat.vue`

### T005 在 TinyRobotChat 导入并注册 SendStopButton

- **优先级**：P0
- **依赖任务**：T001
- **任务描述**：
  - 在 `TinyRobotChat.vue` 的 `<script setup>` import 区域（约第 144-149 行自定义组件导入处）新增导入语句：
    ```typescript
    import SendStopButton from './SendStopButton.vue'
    ```
  - 导入位置紧跟现有自定义组件导入（`QrCodeScan`、`ModelSwitch`、`PluginToggleButton` 等）之后，保持导入顺序一致
- **输入**：T001 产出的 `SendStopButton.vue`；`TinyRobotChat.vue:144-149` 现有导入区域
- **输出**：`TinyRobotChat.vue` 新增 1 行 import 语句
- **验收标准**：
  - import 语句位于自定义组件导入区域，相对路径 `./SendStopButton.vue` 正确
  - `npx vue-tsc --noEmit` 无 "Cannot find module" 错误
  - 不影响现有 `VoiceButton`、`ModelSwitch` 等组件的导入
- **风险点**：
  - 相对路径 `./SendStopButton.vue` 需与 `TinyRobotChat.vue` 同目录（已确认两者均在 `next-remoter/src/components/`）
  - Vue SFC 默认导出无需 `{ }` 解构，使用默认导入
- **回滚点**：删除新增的 import 语句

### T006 在 #footer-right 插槽接入 SendStopButton

- **优先级**：P0
- **依赖任务**：T005
- **任务描述**：
  - 将 `TinyRobotChat.vue` 第 77-79 行的 `#footer-right` 插槽：
    ```vue
    <template #footer-right>
      <VoiceButton v-if="allowSpeech" />
    </template>
    ```
    修改为：
    ```vue
    <template #footer-right>
      <VoiceButton v-if="allowSpeech" />
      <SendStopButton
        :loading="senderLoading"
        :disabled="!inputMessage.trim()"
        @submit="() => senderRef?.submit()"
        @cancel="abortRequest"
      />
    </template>
    ```
  - `:loading` 绑定 `senderLoading`（第 807 行 `computed(() => messageState.status === 'processing')`）
  - `:disabled` 绑定 `!inputMessage.trim()`，输入框为空或纯空白时禁用发送按钮
  - `@submit` 调用 `senderRef?.submit()`，复用 tr-sender 内部的文本提取逻辑（含 mention/template 扩展处理），tr-sender 的 `submit()` 方法内部会触发 `@submit` 事件，进而调用已绑定的 `handleSendMessageCustom`
  - `@cancel` 直接调用 `abortRequest`，复用现有的前端+后端双重中止链路
- **输入**：T005 产出的导入；`TinyRobotChat.vue:55-57`（senderRef/inputMessage/senderLoading 定义）、`:77-79`（插槽）、`:807`（senderLoading computed）、`useTinyRobotChat.ts:357-362`（abortRequest）
- **输出**：`TinyRobotChat.vue` 第 77-79 行插槽内容扩展为 8 行
- **验收标准**：
  - `SendStopButton` 在 `#footer-right` 插槽中渲染，位于 `VoiceButton` 之后
  - `:loading` 正确绑定 `senderLoading`，Agent 处理中时为 `true`
  - `:disabled` 在输入框为空时为 `true`，有内容时为 `false`
  - `@submit` 触发 `senderRef.submit()`，消息正常发送且输入框清空
  - `@cancel` 触发 `abortRequest`，Agent 立即停止
  - 满足 spec.md §5.1.1 规则 2（发送按钮触发）、§5.2.1 规则 2（停止按钮触发）
- **风险点**：
  - `senderRef?.submit()` 使用可选链，需确认 `senderRef` 已在第 868 行定义为 `Ref<ComponentInstance<typeof TrSender>>`，且 tr-sender 的 `submit()` 方法通过 `defineExpose` 暴露（design.md §1.2.1 已验证）
  - `inputMessage.trim()` 需确认 `inputMessage` 为 `Ref<string>`（第 416、474、770 行已确认）
  - `@submit` 使用箭头函数 `() => senderRef?.submit()` 而非直接 `senderRef?.submit`，避免事件参数被透传到 submit 方法
- **回滚点**：还原插槽为仅包含 `<VoiceButton v-if="allowSpeech" />`

### T007 隐藏 tr-sender 内置 SubmitButton 避免重复

- **优先级**：P0
- **依赖任务**：T005
- **任务描述**：
  - 在 `TinyRobotChat.vue` 的 `<style scoped lang="less">` 中新增样式规则：
    ```less
    // 隐藏 tr-sender 内置的发送/停止按钮，避免与自定义 SendStopButton 重复
    :deep(.tr-sender-submit-button) {
      display: none !important;
    }
    ```
  - 使用 `:deep()` 穿透 scoped 样式，`!important` 确保覆盖库内置样式
  - 仅隐藏 `tr-sender-submit-button`，不影响 `tr-default-action-buttons` 容器中的其他按钮（如 ClearButton）
- **输入**：T005 产出；design.md §2.4.2 修改点 3、§2.5.2 与现有 UI 一致性
- **输出**：`TinyRobotChat.vue` 的 `<style>` 块新增 1 条样式规则
- **验收标准**：
  - 输入框有内容时，tr-sender 内置的 `tr-sender-submit-button` DOM 节点 `display` 为 `none`
  - Agent 处理中时，不出现两个停止按钮（仅 SendStopButton 显示）
  - ClearButton 等其他库内置按钮正常显示，不受影响
  - 满足 spec.md §5.1.1 规则 5（禁止重复提交）与 §5.2.1 规则 1（停止按钮唯一性）
- **风险点**：
  - `:deep(.tr-sender-submit-button)` 会隐藏 tr-sender 内部所有该类名元素，需确认库内仅有 SubmitButton 使用该类名（design.md §1.2.2 已验证）
  - `!important` 优先级较高，若库升级后类名变更需同步更新此样式
  - 本组件 SendStopButton 也使用 `tr-sender-submit-button` 类名（T002/T004），需确认 `:deep()` 不会误隐藏自定义按钮——**关键**：`:deep()` 仅穿透到子组件 DOM，而 SendStopButton 是在 `#footer-right` 插槽中渲染的同级子组件，其根元素的 `tr-sender-submit-button` 类名会被 `:deep()` 匹配。**解决方案**：SendStopButton 根元素额外添加自定义类名 `send-stop-button-custom`，并将 `:deep()` 选择器精确化为 `:deep(.tr-default-action-buttons .tr-sender-submit-button)` 仅匹配库内置容器内的按钮
- **回滚点**：删除新增的样式规则

---

## G3. 兼容性验证与回归测试

> **业务目标**：通过类型检查、构建验证、单元测试与手动验证，确保 SendStopButton 组件功能正确、不破坏现有交互、两种聊天模式均适配。

### T008 vue-tsc 类型检查通过

- **优先级**：P0
- **依赖任务**：T004, T007
- **任务描述**：
  - 在 `apps/web-admin/web` 目录执行 `npx vue-tsc --noEmit` 命令
  - 确认 `SendStopButton.vue` 的 props/emits 类型定义正确，无 `any` 类型
  - 确认 `TinyRobotChat.vue` 中 `SendStopButton` 的使用符合类型约束
  - 确认 `senderRef?.submit()` 调用类型安全（`senderRef` 为 `Ref<ComponentInstance<typeof TrSender>>`，`submit` 是 TrSender 暴露的方法）
- **输入**：T001-T007 全部产出
- **输出**：vue-tsc 检查通过，无类型错误
- **验收标准**：
  - `npx vue-tsc --noEmit` 退出码为 0
  - 无 "Property 'submit' does not exist on type" 错误
  - 无 "Cannot find module './SendStopButton.vue'" 错误
  - 无 props 类型不匹配警告
- **风险点**：
  - vue-tsc 对 Vue SFC 的类型检查可能因第三方库类型定义不完整而报错，需区分本次修改引入的错误与存量错误
  - 若 `@opentiny/tiny-robot` 未导出 `ComponentInstance<typeof TrSender>` 的 `submit` 方法类型，可能需要类型断言
- **回滚点**：若类型错误无法解决，回退 T006 改用 `handleSendMessageCustom(inputMessage.value)` 直接调用（绕过 senderRef.submit()）

### T009 vite build 构建验证通过

- **优先级**：P0
- **依赖任务**：T007
- **任务描述**：
  - 在 `apps/web-admin/web` 目录执行 `npm run build` 命令（`cross-env NODE_OPTIONS=--max-old-space-size=16384 vite build --config ./config/vite.config.prod.ts`）
  - 确认 `SendStopButton.vue` 组件被正确编译打包
  - 确认 `IconSend` / `IconStop` 图标导入路径正确解析
  - 确认 `:deep(.tr-sender-submit-button)` 样式正确编译
  - 确认无构建错误、无未解析的导入
- **输入**：T001-T007 全部产出
- **输出**：vite build 构建成功，产物中包含 SendStopButton 组件
- **验收标准**：
  - `npm run build` 退出码为 0
  - 构建产物中存在 SendStopButton 相关代码（可在 dist 目录搜索确认）
  - 无 "Failed to resolve import" 错误
  - 无 CSS 编译错误
- **风险点**：
  - 构建可能因内存不足失败（`NODE_OPTIONS=--max-old-space-size=16384` 已配置 16GB 堆内存）
  - `@opentiny/tiny-robot-svgs` 的图标可能未在构建配置中 externals 处理，需确认打包体积无异常增长
- **回滚点**：若构建失败，根据错误信息定位是 T006 的插槽修改还是 T007 的样式修改导致，针对性回滚

### T010 编写 vitest 单元测试覆盖 7 个场景

- **优先级**：P1
- **依赖任务**：T007
- **任务描述**：
  - 在 `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-remoter/src/components/__tests__/` 目录下新建 `SendStopButton.test.ts`（目录不存在则创建）
  - 使用 `@vue/test-utils` 的 `mount` 方法挂载 `SendStopButton` 组件
  - 编写以下 7 个测试场景（对应 design.md §2.7.3）：
    1. **空闲 + 输入框为空**：`loading=false, disabled=true` → 根元素包含 `is-disabled` 类，点击不触发 `submit` 事件
    2. **空闲 + 输入框有内容**：`loading=false, disabled=false` → 显示发送按钮，点击触发 `submit` 事件一次
    3. **处理中**：`loading=true` → 显示停止按钮（`IconStop`），点击触发 `cancel` 事件一次
    4. **处理中 → 空闲**：`loading` 从 `true` 切换为 `false` → 停止按钮切换回发送按钮，响应时间 ≤50ms（使用 `vi.useFakeTimers` 验证）
    5. **快速连续点击停止**：`loading=true` 时连续点击 3 次 → 首次触发 `cancel`，后续点击由父组件 `abortRequest` 的 `.catch(() => {})` 兜底，组件层验证 `cancel` 事件触发次数（注：组件层不防抖，幂等性由父组件保证，本测试验证组件正确分发每次点击）
    6. **库内置按钮隐藏**：在 `TinyRobotChat.vue` 的集成测试中验证 `.tr-sender-submit-button` 的 `display` 为 `none`（需 mount TinyRobotChat 或单独验证 CSS 规则）
    7. **回车键发送兼容**：在 `TinyRobotChat.vue` 的集成测试中验证回车键仍触发 `@submit` 事件（tr-sender 内置 `submitType="enter"` 行为不受 SendStopButton 影响）
  - 测试文件包含中文 `复现：` 关键字（满足 webmcp-sdk AGENTS.md 的 Bug 复现测试要求，若视为 Feature 则不强制）
- **输入**：T001-T007 全部产出；design.md §2.7.3 测试场景表
- **输出**：`SendStopButton.test.ts` 测试文件，7 个测试用例
- **验收标准**：
  - `npx vitest run --reporter verbose` 全部通过（7 个测试用例）
  - 测试覆盖 `SendStopButton` 组件的渲染、事件分发、状态切换
  - 测试覆盖 `TinyRobotChat.vue` 集成后的库内置按钮隐藏与回车键兼容
  - 无未处理的 Promise rejection 警告
- **风险点**：
  - `next-remoter` 包未配置 vitest 脚本（package.json scripts 中无 test 命令），需在测试命令中指定配置文件或继承 web 项目的 vitest 配置
  - `@vue/test-utils` 可能未安装，需确认依赖（若缺失需在 tasks.md 中标注为前置依赖）
  - 场景 6、7 需要 mount `TinyRobotChat.vue`，该组件依赖较多 composable（`useTinyRobotChat` 等），可能需要 mock 大量依赖，考虑仅测试 CSS 规则与 tr-sender 事件绑定
- **回滚点**：删除 `__tests__/SendStopButton.test.ts` 文件

### T011 执行手动验证清单 7 项

- **优先级**：P1
- **依赖任务**：T009
- **任务描述**：
  - 启动开发服务器（`npm run start` 在 `apps/web-admin/web` 目录，端口 3031）
  - 按 design.md §2.7.4 手动验证清单逐项验证：
    1. **悬浮窗模式发送**：打开右下角悬浮窗 → 输入消息 → 点击发送按钮 → 预期：消息发送成功，输入框清空，按钮切换为停止按钮
    2. **悬浮窗模式停止**：发送消息后 → 点击停止按钮 → 预期：Agent 立即停止，按钮切换回发送按钮
    3. **全屏对话模式发送**：访问 `/chat` → 打开聊天 → 输入消息 → 点击发送按钮 → 预期：行为与悬浮窗模式一致
    4. **空输入框禁用**：清空输入框 → 观察发送按钮 → 预期：发送按钮显示为禁用样式（`is-disabled`），点击无响应
    5. **回车键兼容**：输入消息 → 按回车键 → 预期：消息正常发送，行为与点击发送按钮一致
    6. **明暗主题**：切换主题 → 预期：按钮样式正确适配主题（复用库内置 CSS 变量）
    7. **模式切换**：Agent 处理中时切换悬浮窗 ↔ 全屏 → 预期：按钮状态正确显示停止按钮
  - 记录每项验证结果（通过/失败），失败项需记录详细复现步骤与截图
- **输入**：T009 构建产物；design.md §2.7.4 手动验证清单
- **输出**：手动验证报告（7 项全部通过，或失败项清单）
- **验收标准**：
  - 7 项手动验证全部通过
  - 悬浮窗模式与全屏对话模式行为一致（满足 spec.md §5.3 多模式适配）
  - 回车键发送行为不受影响（满足 spec.md §5.1.1 规则 4）
  - 明暗主题下按钮样式正确（满足 spec.md §4.5 兼容性规则 3）
- **风险点**：
  - 全屏对话模式入口 `ChatRemoter.vue` 未显式传 `mode` prop（design.md §1.2.5 已说明），若两种模式行为不一致需补传 `mode="chat-dialog"`
  - Agent 处理中时切换模式可能因组件重新挂载导致状态丢失，需验证 `messageState.status` 是否跨模式保持
  - 手动验证依赖后端 Agent 服务可用，若服务不可用需 mock 或延后验证
- **回滚点**：若验证失败项无法修复，按 design.md §2.6.1 回滚步骤还原

---

## G4. 回滚与风险验证

> **业务目标**：确认回滚方案有效，确保本次修改可在任意阶段安全回退，不影响现有功能。

### T012 验证回滚方案有效性

- **优先级**：P1
- **依赖任务**：T007
- **任务描述**：
  - 按 design.md §2.6.1 回滚步骤执行回滚操作：
    1. 删除新增文件 `SendStopButton.vue`
    2. 还原 `TinyRobotChat.vue`：
       - 移除 `import SendStopButton from './SendStopButton.vue'`
       - 还原 `#footer-right` 插槽为仅包含 `<VoiceButton v-if="allowSpeech" />`
       - 移除 `:deep(.tr-sender-submit-button) { display: none !important; }` 样式
    3. 执行回滚验证：回车键发送消息功能恢复正常，tr-sender 内置按钮在有内容时正常显示
  - 验证回滚后 `npm run build` 构建通过
  - 验证回滚后手动发送消息（回车键 + 有内容时点击库内置发送按钮）功能正常
  - 回滚验证完成后，**重新应用** T001-T007 的修改（即恢复本次需求的实现），因为回滚仅用于验证回滚方案的有效性，最终交付应包含 SendStopButton 功能
- **输入**：T001-T007 全部产出；design.md §2.6.1 回滚步骤、§2.6.2 回滚影响
- **输出**：回滚方案验证报告（回滚后功能恢复正常，重新应用后功能正确）
- **验收标准**：
  - 回滚后 `npm run build` 构建通过
  - 回滚后回车键发送消息功能正常
  - 回滚后 tr-sender 内置按钮在有内容时正常显示（恢复库默认行为）
  - 回滚不影响 `abortRequest`、`handleSendMessageCustom` 等现有逻辑
  - 回滚不影响 `App.vue`、`ChatRemoter.vue` 等入口文件
  - 重新应用修改后，T008-T011 验证仍全部通过
- **风险点**：
  - 回滚验证过程中需确保 git 工作区状态清晰，避免回滚操作污染最终交付
  - 建议在 git 分支上执行回滚验证，验证完成后切换回实现分支
  - 重新应用修改时需确认与回滚前完全一致（建议使用 `git stash` + `git stash pop` 流程）
- **回滚点**：本任务即回滚验证，无需进一步回滚

---

## 风险点汇总

| 风险编号 | 所属任务 | 风险描述 | 影响程度 | 缓解措施 |
|---------|---------|---------|---------|---------|
| R001 | T002 | `@opentiny/tiny-robot-svgs` 未导出 `IconSend` / `IconStop` | 高 | design.md §1.1.1 已验证 tr-sender 内置使用相同图标，导入路径一致 |
| R002 | T007 | `:deep(.tr-sender-submit-button)` 误隐藏自定义 SendStopButton | 高 | SendStopButton 根元素额外添加 `send-stop-button-custom` 类名，`:deep()` 选择器精确化为 `:deep(.tr-default-action-buttons .tr-sender-submit-button)` |
| R003 | T006 | `senderRef?.submit()` 类型不安全或方法未暴露 | 中 | design.md §1.2.1 已验证 tr-sender 通过 defineExpose 暴露 submit()，T008 vue-tsc 会捕获类型错误 |
| R004 | T008 | vue-tsc 报存量类型错误干扰本次修改判断 | 中 | 对比修改前后的 vue-tsc 输出，仅关注新增错误 |
| R005 | T010 | `next-remoter` 包未配置 vitest，`@vue/test-utils` 可能缺失 | 中 | 测试命令指定 web 项目的 vitest 配置，或临时安装 `@vue/test-utils` 作为 devDependency |
| R006 | T010 | 场景 6、7 需 mount `TinyRobotChat.vue`，依赖过多 | 中 | 仅测试 CSS 规则与 tr-sender 事件绑定，mock `useTinyRobotChat` 等 composable |
| R007 | T011 | `ChatRemoter.vue` 未显式传 `mode` prop，两种模式行为可能不一致 | 低 | design.md §1.2.5 已说明两种模式共用同一组件，修改一处即覆盖；若不一致则补传 prop |
| R008 | T011 | Agent 处理中切换模式导致状态丢失 | 低 | 验证 `messageState.status` 跨模式保持，必要时在 `ChatRemoter.vue` 补传 `mode` prop |
| R009 | T012 | 回滚验证污染 git 工作区 | 低 | 使用 git 分支或 stash 流程，验证完成后恢复实现分支 |

---

## 回滚方案

### 整体回滚步骤

1. **删除新增文件**：
   - `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-remoter/src/components/SendStopButton.vue`
   - `apps/web-admin/web/src/lib/webmcp-sdk/packages/next-remoter/src/components/__tests__/SendStopButton.test.ts`（若 T010 已执行）

2. **还原 `TinyRobotChat.vue`**：
   - 移除 `import SendStopButton from './SendStopButton.vue'`
   - 还原 `#footer-right` 插槽为：
     ```vue
     <template #footer-right>
       <VoiceButton v-if="allowSpeech" />
     </template>
     ```
   - 移除 `:deep(.tr-sender-submit-button) { display: none !important; }` 样式规则

3. **回滚验证**：
   - 执行 `npm run build` 确认构建通过
   - 启动开发服务器，验证回车键发送消息功能正常
   - 验证输入框有内容时 tr-sender 内置发送按钮正常显示

### 回滚影响

- 回滚后恢复为 tr-sender 库默认行为：输入框为空时无发送按钮，有内容时显示发送按钮
- 不影响 `abortRequest`、`handleSendMessageCustom`、`senderLoading` 等现有逻辑
- 不影响 `App.vue`、`ChatRemoter.vue`、`views/chat/index.vue` 等入口文件
- 不影响 `useTinyRobotChat.ts`、`cancel.ts` 等业务逻辑文件
- 不影响第三方库 `@opentiny/tiny-robot` 源码（本次未修改）

---

## 验收检查清单

- [ ] T001 SendStopButton 组件骨架与类型契约已创建
- [ ] T002 按钮图标切换与禁用态渲染已实现
- [ ] T003 点击事件分发（submit/cancel）已实现
- [ ] T004 组件样式已编写，复用库内置类名
- [ ] T005 TinyRobotChat 已导入并注册 SendStopButton
- [ ] T006 #footer-right 插槽已接入 SendStopButton
- [ ] T007 tr-sender 内置 SubmitButton 已隐藏
- [ ] T008 vue-tsc 类型检查通过
- [ ] T009 vite build 构建验证通过
- [ ] T010 vitest 单元测试 7 个场景全部通过
- [ ] T011 手动验证清单 7 项全部通过
- [ ] T012 回滚方案验证有效

---

## 附录：关键文件路径与行号索引

| 文件 | 关键位置 | 内容 |
|------|---------|------|
| `TinyRobotChat.vue` | 第 55-57 行 | tr-sender 配置（senderRef、inputMessage、senderLoading、@submit、@cancel） |
| `TinyRobotChat.vue` | 第 77-79 行 | `#footer-right` 插槽（当前仅含 VoiceButton） |
| `TinyRobotChat.vue` | 第 119 行 | `@opentiny/tiny-robot-svgs` 导入示例 |
| `TinyRobotChat.vue` | 第 144-149 行 | 自定义组件导入区域 |
| `TinyRobotChat.vue` | 第 807 行 | `senderLoading` computed 定义 |
| `TinyRobotChat.vue` | 第 868 行 | `senderRef` 类型定义 `Ref<ComponentInstance<typeof TrSender>>` |
| `useTinyRobotChat.ts` | 第 357-362 行 | `abortRequest` 实现（cancelChat + abortActiveRequest） |
| `useTinyRobotChat.ts` | 第 311-317 行 | `messageState.status` 来源链路 |
| `App.vue` | 第 537-548 行 | 悬浮窗入口 `<TinyRemoter mode="remoter">` |
| `views/chat/index.vue` | 第 61-68 行 | 全屏对话入口 |
| `ChatRemoter.vue` | 第 3-46 行 | 全屏对话渲染 `<TinyRemoter>` |