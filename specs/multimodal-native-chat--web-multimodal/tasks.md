# 任务规划：`web-multimodal`（前端多模态交互）

> 关联需求：本目录 `spec.md` v1 ｜ 关联契约：本目录 `contract.md` v1
> 主工程账本：`specs/multimodal-native-chat/SPECS_INDEX.md`（开工前必读）
> 阶段：task ｜ 日期：2026-10-15 ｜ 状态：草稿

## 开发规范（全任务强制遵守）

- **语言与工具绑定**：前端（TS/Vue）→ `web-coder` / `fullstack-codegen`。
- **大工程拆分态（铁律 15）**：本子系统 ID = `web-multimodal`；上游 = `host-attach-core` v1；验收档位 L1+L2+L3；禁止直连其它子系统私有表/目录；跨子系统接口改动成对成条。
- **vendored SDK 改动纪律**：`web-admin/src/lib/webmcp-sdk/` 是本地 vendored 依赖，改动须最小化并留注释说明为何改（避免后续 SDK 升级冲突）。
- **复用优先**：已落地能力（门控扩展、accept、发送按钮、归一化）只做收口与回归，不重写。
- **编译约束**：`npm run build` / lint 由人工执行并回传。

## 任务总览

| 编号 | 任务 | 关联需求(spec §) | 状态 | 预计产出 |
|---|---|---|---|---|
| T-WEB-01 | 契约确认（IF-05 已冻结；与宿主演进约定对齐） | contract §1 | [ ] | 契约确认记录 |
| T-WEB-02 | `convertAttachmentsToContent` 保留 AI-SDK 形状 + 补 filename + 非图片分支 | §5.2.1.1/1.2 | [x] | 已落地 `useMultimodal.ts` |
| T-WEB-03 | `handleSendMessage` 改 `engine.send({role:'user',content:块数组})` | §5.2.1.3 | [x] | 已落地 `useTinyRobotChat.ts` |
| T-WEB-04 | `hasMultimodalSupport` 扩展为图片或文档能力（不新增 `supportFiles`） | §5.1.1.1/1.2 | [x] | 已落地 |
| T-WEB-05 | `TrUploadButton` accept 覆盖 ppt/pptx/md/csv/json | §5.1.1.3 | [x] | 已落地 |
| T-WEB-06 | 发送按钮 disabled 改为「无文本且无附件」 | §5.2.1.4 | [x] | 已落地 |
| T-WEB-07 | `normalizeContentForWebMCP` 作为唯一形状转换点 | §5.3.1 | [x] | 已落地 `AgentModelProvider.ts` |
| T-WEB-08 | 切模型清理不兼容附件（回归验证） | §5.1.1.4 | [ ] | 回归记录 |
| T-WEB-09 | 留痕呈现：`<attachment_notices>` UI | §5.4.1.1/1.2 | [ ] | 提示组件/渲染逻辑 |
| T-WEB-10 | 前端预估拦截超 `maxFileSize` 的文件 | §4.1.2 | [ ] | 拦截与提示 |
| T-WEB-11 | 多模态与技能注入 / profile_context 并行共存回归 | 主工程 §5.5 | [ ] | 回归记录（AC2） |
| T-WEB-12 | L1 自测 | §5 全章 | [ ] | 前端用例 |
| T-WEB-13 | L2 集成冒烟（contract §6 SC-21~SC-24） | contract §6 | [ ] | L2 报告 |

## 任务依赖关系图

```
T-WEB-01 ─→ T-WEB-08 ─┐
T-WEB-02 ✅ ─┐         ├─→ T-WEB-11 ─→ T-WEB-12 ─→ T-WEB-13
T-WEB-03 ✅ ─┼─→ T-WEB-09
T-WEB-04 ✅ ─┤
T-WEB-05 ✅ ─┤
T-WEB-06 ✅ ─┤
T-WEB-07 ✅ ─┘
T-WEB-10 ─────────────┘
```

## 任务详细说明（按编号展开）

### T-WEB-01 契约确认
- **目标**：确认 IF-05 沿用已落地形态，演进约定（minor/major）与宿主对齐。
- **验收**：双方书面确认「未知块类型宿主忽略」与「前端只呈现不加工留痕」。

### T-WEB-02 ~ T-WEB-07（已完成，仅做回归）
- **状态**：全部已在 P0 轮落地。本轮只做回归验证，不重写。
- **验收**：`npm run build` + eslint 通过（人工回传）；行为与 spec §5.2/§5.3 一致。

### T-WEB-08 切模型清理不兼容附件（回归）
- **目标**：确认切换模型后不兼容附件被清理。
- **验收**：由有文档能力的模型切到纯文本模型后，文档附件被清除且入口隐藏。

### T-WEB-09 留痕呈现
- **目标**：AC7 不静默丢弃。
- **步骤**：① 解析宿主回传的 `<attachment_notices>`；② 在会话流中呈现（不做二次拼接）；③ 无留痕时不显示。
- **验收**：SC-22 通过；提示文案直接来自宿主。

### T-WEB-10 前端预估拦截
- **目标**：超限文件不进入网络传输。
- **步骤**：① 选文件后按 `maxFileSize` 预估（base64 膨胀约 4/3 需计入）；② 超限则拦截并提示；③ 最终裁定仍以宿主为准。
- **验收**：超限文件不出现在请求体；提示明确。

### T-WEB-11 并行共存回归
- **目标**：AC2。
- **验收**：多图 + 技能注入 + `profile_context` 同轮三者并存互不覆盖。

### T-WEB-12 L1 自测 / T-WEB-13 L2 冒烟
- **验收**：SC-21~SC-24 全绿；SC-23 需 `doc-parser-plugins` done。

## 需求覆盖追踪矩阵

| spec 条目 | 覆盖任务 | 覆盖状态 | 备注 |
|---|---|---|---|
| §5.1.1 门控（图片/文档/accept/切模型） | T-WEB-04、T-WEB-05、T-WEB-08 | 全覆盖 | 已落地 + 回归 |
| §5.2.1 转块与发送（图片/非图片/随消息/只图可发/禁降级） | T-WEB-02、T-WEB-03、T-WEB-06 | 全覆盖 | 已落地 |
| §5.3.1 边界归一化（唯一点/转换/纯文本透传） | T-WEB-07 | 全覆盖 | 已落地 |
| §5.4.1 留痕呈现（可见/不重复） | T-WEB-09 | 全覆盖 | |
| §4.1 性能（2s 本地处理 / 预估拦截） | T-WEB-10 | 全覆盖 | |
| §4.2 可靠性（无文本可发 / 错误呈现 / 纯文本不变） | T-WEB-06、T-WEB-09、T-WEB-11 | 全覆盖 | |
| §4.5 兼容性（AI-SDK 直连不变 / 官方契约） | T-WEB-02、T-WEB-07、T-WEB-12 | 全覆盖 | |
| §6 数据约束 | T-WEB-02、T-WEB-07 | 全覆盖 | |

## 验收检查清单（终验）

- [ ] 契约已确认，实现与 `contract.md` 无偏差
- [ ] 形状归一化只有一处（无重复转换点）
- [ ] 上传入口门控与 accept 覆盖符合 spec
- [ ] 只传附件不打字可发送
- [ ] 留痕可见且不重复
- [ ] 多模态与技能注入 / profile_context 并行共存
- [ ] 未新增任何表/列（零表 ✓）
- [ ] `npm run build` + lint 通过（人工确认）
- [ ] L2 冒烟（SC-21~SC-24）全绿

## 修订记录

| 日期 | 轮次 | 触发来源 | 改动摘要 | 验证结果 |
|---|---|---|---|---|
| 2026-10-15 | R1 | 主工程 v2 架构调整 | 新建子系统 spec/contract/tasks；已落地 6 项标注为回归项；新增留痕呈现与预估拦截 | 待主工程闸口 confirm |
