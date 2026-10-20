# SDD 方法论与模板基线（sdd-methodology-baseline）

> 本文档是 `specs/sdd/` 工程的"模板宪法"。它记录了 **CodeArts Agent SDD 方法论的最新明文来源**，并据此为 SDD 融合插件的六个步骤**敲定每一类文档采用哪个模板、来源何处**。
> 配套研究文档：`research.md`（§七 为本次溯源结论）。配套模板：`research-template.md` / `tasks-template.md` / `test-report-template.md`（本文直接内嵌其结构要点）。

---

## 1. 最新明文方法论的位置（可直接引用，不必重写）

| 技能 | 明文路径（产品安装目录） | 缓存副本 | 用途 |
|---|---|---|---|
| 引导建目录 | `D:\Program Files\CodeArts Agent\resources\app\extensions\vscode-codebot\skills\creating-sdd-directory\SKILL.md` | `C:\Users\patrick\.codeartsdoer\cache\system\skills\creating-sdd-directory\SKILL.md` | 建 `.codeartsdoer/specs/{feature_name}/` |
| 需求规格 | `…\vscode-codebot\skills\managing-spec-document\{SKILL.md, spec_template.md, ears-format.md}` | `…\cache\system\skills\managing-spec-document\` | spec.md 6 节组件定位 + EARS |
| 设计 | `…\vscode-codebot\skills\managing-design-document\{SKILL.md, design_template.md}` | `…\cache\system\skills\managing-design-document\` | design.md（仅 3 节骨架，偏薄） |
| 任务规划 | `…\vscode-codebot\skills\managing-tasks-document\SKILL.md` | `…\cache\system\skills\managing-tasks-document\` | tasks.md（流程，无模板） |
| PRD | `…\vscode-codebot\skills\prd\SKILL.md` | `…\cache\system\skills\prd\SKILL.md` | 独立 10 节 PRD（输出到 `output/`） |

> 注：`apps/.../.codeartsdoer/skills/managing-sdd-*` 是**旧明文快照**（spec 内容同上、design 为更完整的 10 节）。新插件以产品最新 6 节 spec 为准；design **优先采用 legacy 10 节版**（比产品 3 节骨架更实用）。早期 `specs/sdd-skills/spec.md` 是四段式 Style B 的 concrete 样本（项目背景→核心问题→功能需求→验收标准），特征/需求型项目可作 Style A 的替代。

---

## 2. 六步编排 → 模板映射（最终基线）

| 步骤 | 是否必选 | 产出文档 | 采用模板 | 来源 / 文件 |
|---|---|---|---|---|
| 1 研究 | 可选 | `research.md` | 本目录 `research-template.md` | 自研（long-running-task/research.md + PRD 10 节可选） |
| 2 需求规格 | 必选 | `spec.md` | 6 节组件定位模板 | 产品 `managing-spec-document/spec_template.md`（= legacy managing-sdd-spec-markdown） |
| 3 设计 | 必选 | `design.md` | 10 节通用设计 + 两段式首章 | legacy `managing-sdd-design-markdown/design_template.md` + long-running-task 范式 |
| 4 任务规划 | 必选 | `tasks.md` | 本目录 `tasks-template.md` | 反演 house style（缺口补齐） |
| 5 编码 | 必选 | 代码产物 | **编程 / 领域技能**（非子 agent） | cangjie-coder / 路由 fullstack-codegen·frontend-dev；web-coder·app-coder 以**技能**形态待建。三者均**无 `agents/` 目录**，遵循"确定性优先" |
| 6 测试验收 | 必选 | `test-report.md` | 本目录 `test-report-template.md` | 反演 house style（缺口补齐） |

> 每步完成后挂载**人在回路闸口**（决策点 + `web_request_approval`），支持"修改→回退上一步"迭代，否则 SDD 退化为一次性自动生成四份文档。

---

## 3. 各模板结构要点（速查）

### 3.1 spec.md（采用，来源：managing-spec-document）
1. 组件定位（核心职责 / 核心输入 / 核心输出 / 职责边界）
2. 领域术语
3. 角色与边界（核心角色 / 外部系统 / 交互上下文 PlantUML）
4. DFX 约束（性能 / 可靠性 / 安全性 / 可维护性 / 兼容性）
5. 核心能力（按业务模块：业务规则+EARS验收 / 交互流程 / 异常场景）
6. 数据约束（领域对象逻辑约束，非库表设计）
> 严禁写入"怎么做"（库表/类图/算法）。特征型项目可用 Style B（项目背景→核心问题→功能需求→验收标准）作可选替代。

### 3.2 design.md（采用，来源：legacy 10 节 + 两段式）
- 建议首章：`一、需求与存量功能关系分析`（已实现功能对比表 / 需扩展功能对比表）—— 来自 long-running-task 范式，强调复用。
- 主体（legacy 10 节，按需裁剪）：设计概述 / 系统架构 / 详细设计 / 数据设计 / API 设计 / 接口设计 / 安全设计 / 性能设计 / 部署设计 / 附录（约束清单 + 变更历史）。

### 3.3 tasks.md（本目录 tasks-template.md）
文档信息 → 开发规范（强制）→ 任务总览（表）→ 任务依赖关系图（DAG）→ 任务详细说明（按编号）→ 需求覆盖追踪矩阵 → 验收检查清单 → 多轮修订记录。

### 3.4 research.md（本目录 research-template.md）
原始需求 → 现状定位 → 基础设施盘点 → 能力缺口表 → 推荐方案 → 决策风险 → 后续指引 → 文件索引。

### 3.5 test-report.md（本目录 test-report-template.md）
文档信息 → 测试概述 → 测试依据 → 测试环境/工具 → 测试执行与结果（用例表）→ 一致性核查（vs spec/design/代码）→ 完成度评估 → 缺陷清单（P0/P1/P2）→ 完善意见 → 验收结论 → 附录。

---

## 4. 落地清单（交接给 design / tasks 步骤）
1. 将本节 §3 的模板固化进 `skills/sdd/` 的各子 agent prompt（research/spec/design/task/code/test）。
2. 把 `managing-spec/design-document` 与 legacy `managing-sdd-design-markdown` 的模板**随插件打包或引用路径**，保证离线可用。
3. `web-coder` / `app-coder` 两个缺失的**编程技能**须新建（**不建 `agents/` 子目录、不派生编码子 agent**），或显式路由到 `fullstack-codegen` / `frontend-dev` 并写明调用契约。
4. **编码形态判别（v3 决策）**：**"需要换脑子的才派生，只需要换说明书的用技能"**——流程编排类（SDD）建 `agents/`；编程 / 领域类（cangjie-coder / web-coder / app-coder）不建，由主 agent 加载 SOP 执行。`skills/cangjie-coder/agents/` 四个遗留语言角色须删除，职责并入其 SKILL.md 四步工作流。
4. 六步 COMPOSITION 编排 + 步步决策点（人在回路）作为 `skills/sdd/COMPOSITION.yaml` 的核心。
