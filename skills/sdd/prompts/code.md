# 编码实现步执行提示词（step: code）

> 执行者：**主 agent 自己** —— 加载编程技能（`cangjie-coder` / `web-coder` / `app-coder`）后按本 SOP 执行，**不派生编码子 agent**
>
> 宿主侧口径：`SddOrchestrationService.HOST_DIRECT_STAGES` 只含 `code`；该步走 `runHostDirectStage`——
> 需 `agent_id`（主 agent 定义 id，必填）+ `language`（选技能），**不写 `sub_agent_invocations`**；
> 编程技能未挂载即显式失败（禁止无依据编码）。

## 这一步做什么

按 `tasks.md` 的语言标签**加载对应编程技能**，由主 agent 按技能 SOP 执行编码。

## 语言分派路由契约

| 语言标签 | 编程技能 | 状态 | 过渡路由 |
|---|---|---|---|
| `cangjie` | `cangjie-coder` | 已存在 | — |
| `web` | `web-coder` | 已建（`skills/web-coder/SKILL.md`） | `fullstack-codegen` / `frontend-dev` |
| `app` | `app-coder` | 已建（`skills/app-coder/SKILL.md`） | `frontend-dev`（近似，原生部分待补） |

三个编程技能均为**纯技能形态**（无 `agents/` 目录、不派生编码子 agent），
与 `cangjie-coder` 同构遵循"确定性优先"四步工作流。

使用过渡路由时**必须**在回传结果中写明，**禁止**静默 fallback。

## 铁律：确定性优先（三个 coder 统一哲学）

1. **先查依据再写代码** —— 目标工程内既有 import 先例 / 同类实现 / 调用范式 + 技术栈官方文档技能确认 API 契约。判据是"文档 + 工程既有先例"。
2. **复制粘贴 + 二次编辑** —— 产出路径是"定位既有正确代码 → 复制 → 最小适配"，等价人类开发行为；**禁止**从零凭空生成、禁止凭跨语言经验臆造 API。
3. **官方文档技能** —— cangjie → `CangjieSkills`；web → 前端技术栈；app → 鸿蒙/安卓/苹果原生。三者必须包含或引用。
4. **依据留痕与降级** —— 查不到必须显式标注缺口并请人工确认，**禁止**静默猜写。

## 执行步骤

1. 读取 `tasks.md`，按语言标签分组。
2. 加载对应编程技能（或过渡路由技能），逐个任务执行编码。
3. 产物经 `code-gen-verifier` 闸门；未通过**禁止**标记完成。
4. 至少一份 `usage=deliverable` 代码产物入 `long_running_task_artifact`（`stage=code`）。
5. 触发 `gate-code` 闸口：confirm → 进测试；revise → 回退重做（**新 task_id，上下文不串味**）；abandon → 终止。

## 硬约束

- **不派生编码子 agent**（语言专用子 agent 架构已作废，见 `research.md` §十二）。
- **不编译**：`cjpm build` 与日志回传由人工在独立 cmd 完成。
- **连续质量闸门失败**挂人工闸口，不得无限重试。
- 改动只落在 `target_project_root` 内。

## 回传

`{"changed_files": [...], "verify_passed": true|false, "language": "cangjie|web|app"}`；失败时附失败项清单。
