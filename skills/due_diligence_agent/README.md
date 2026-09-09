# 企业信用与风控尽调智能体（Due Diligence Agent）

> **华为云首届企业级智能体创新赛** — 基础赛题参赛作品
> **运行底座**：[agentskills-runtime](../../../)（仓颉编程语言 AI 驱动开发框架，L3 进程隔离轨插件机制 / 一切皆技能）
> **版本**：v1.0.0 | **日期**：2026-09-09

---

## 一、项目简介

本智能体在 agentskills-runtime 新一代 AI 驱动开发框架基础上**增量开发**，实现企业信用与风控尽调全流程自动化：

```
企业名单 → 名单校验 → 天眼查 MCP 数据采集 → 股权穿透 → 风险分级 → 尽调报告生成 → 幂等入库
```

**核心价值**：从"企业名称"到"结构化风控尽调报告 + 入库企业信息"的端到端闭环，面向供应商准入、客户授信、投资尽调、竞对分析、合规排查等场景。

**技术特色**：
- **L3 进程隔离轨插件**：独立 executable 工程，经 JSON-RPC over stdio 与宿主通信，崩溃自愈
- **宿主统一 MCP 开放服务**：零移植复用 `HttpMCPClient` + http_lib，凭证宿主集中管理
- **动态脚本业务编排**：Python 脚本承载穿透/分级/报告生成，经 HTTP API 调宿主开放服务
- **一切皆技能**：SKILL.md 定义尽调 SOP，COMPOSITION.yaml 声明步骤编排

---

## 二、架构设计

### 2.1 系统上下文

```
┌──────────────┐     ┌──────────────────────────────────────────┐     ┌──────────────┐
│  业务人员     │────▶│         企业信用与风控尽调智能体           │────▶│  天眼查 MCP   │
│  上游系统     │     │                                          │     │  (162 工具)  │
└──────────────┘     │  ┌─────────┐  ┌──────────┐  ┌─────────┐ │     └──────────────┘
                     │  │ Python  │  │  L3 插件  │  │  宿主   │ │
                     │  │ 脚本层  │─▶│ (仓颉)   │─▶│  服务   │ │
                     │  │(穿透/   │  │(CRUD+    │  │(MCP/DB/ │ │     ┌──────────────┐
                     │  │ 分级/   │  │ dd-fetch │  │ 权限/   │ │────▶│  PostgreSQL  │
                     │  │ 报告)   │  │ dd-save) │  │ 日志)   │ │     │  (6 张表)    │
                     │  └─────────┘  └──────────┘  └─────────┘ │     └──────────────┘
                     └──────────────────────────────────────────┘
```

### 2.2 分层架构

| 层 | 技术栈 | 职责 | 目录 |
|---|---|---|---|
| **D 层（动态脚本）** | Python 3.8+ | 名单校验、股权穿透、风险分级、报告生成、批量编排 | `scripts/` |
| **P 层（L3 插件）** | 仓颉 1.1.3 | 6 表 CRUD + dd-fetch 采集聚合 + dd-save 幂等落库 | `src/` |
| **H 层（宿主服务）** | 仓颉 1.1.3 | MCP 开放服务 + host.db + 行级权限 + 审计日志 | `apps/agentskills-runtime/src/` |
| **E 层（技能定义）** | YAML + Markdown | 尽调 SOP + 步骤编排声明 | `SKILL.md` + `COMPOSITION.yaml` |

### 2.3 数据流

```
1. 用户提交企业名单
       │
       ▼
2. validate_enterprise_list.py ── 校验/清洗/去重 ──▶ 有效名单
       │
       ▼
3. dd-fetch ── 宿主 McpOpenService ──▶ 天眼查 MCP
       │           │
       │           ├── get_company_registration_info (工商信息)
       │           ├── get_risk_overview (风险概览)
       │           └── get_shareholder_info / get_judicial_case (VIP)
       ▼
4. penetrate_equity.py ── 逐层穿透 ──▶ 股权结构 + 最终受益人
       │
       ▼
5. tier_risks.py ── 分级研判 ──▶ 风险清单（高/中/低 + 可解释依据）
       │
       ▼
6. generate_dd_report.py ── 汇编四部分 ──▶ Markdown / HTML / DOCX 报告
       │
       ▼
7. dd-save ── PersistService ──▶ 6 张表幂等 upsert + MCP 调用日志
```

---

## 三、目录结构

```
skills/due_diligence_agent/
├── plugin.yaml                 # L3 插件声明（38 条路由）
├── cjpm.toml                   # 仓颉独立 executable 工程配置
├── SKILL.md                    # 尽调 SOP 技能定义
├── COMPOSITION.yaml            # 步骤编排声明（validate→fetch→penetrate→tier→generate→save）
├── skill_evaluation_report.md  # 技能评估报告
│
├── src/                        # 仓颉插件源码（L3 进程隔离轨）
│   ├── main.cj                 # 进程入口（PluginRuntime.run）
│   ├── dd_handlers.cj          # 路由分发 + CRUD + dd-fetch + dd-save
│   ├── persist_service.cj      # 6 表幂等读写封装
│   └── dd_effects.cj           # 可逆效果注册
│
├── scripts/                    # Python 动态脚本（业务编排层）
│   ├── validate_enterprise_list.py  # 名单校验/清洗/去重
│   ├── penetrate_equity.py          # 股权穿透计算
│   ├── tier_risks.py                # 风险分级研判
│   ├── generate_dd_report.py        # 尽调报告生成（md/html/docx）
│   ├── run_batch_dd.py              # 批量尽调编排
│   ├── run_dd_pipeline.py           # 全链路直连天眼查 MCP
│   ├── test_dd_fetch.py             # 宿主 McpOpenController 测试
│   └── test_tianyancha_direct.py    # 天眼查 MCP 直连测试
│
├── sql/                        # 数据库数据导出
│   └── *.sql                        # 插件相关数据库数据
│
├── output/                     # 尽调产物
│   ├── fetched/                     # 天眼查原始数据
│   ├── penetration/                 # 股权穿透结果
│   ├── risks/                       # 风险分级结果
│   ├── report/                      # 尽调报告（md + html）
│   └── pipeline_result.json         # 全链路结果
│
├── log/                        # 调用日志（赛事评分凭证）
│   ├── dd_pipeline_*.json           # MCP 调用 + 脚本调用日志
│   └── tianyancha_mcp_log.png         # 天眼查MCP调用截图
│
└── target/                     # 编译产物
    └── release/bin/
        ├── skill_due_diligence_agent.exe  # L3 插件可执行文件
        └── *.dll                          # 84 个运行时依赖
```

---

## 四、核心能力

### 4.1 尽调任务发起（名单校验）

- 空名单拒绝、首尾空白清洗、非法字符标注、自动去重
- 支持单企业 / 批量两种模式
- 5 种场景维度：`supplier` / `credit` / `investment` / `competitor` / `related_risk`

### 4.2 企业信息采集（天眼查 MCP）

| 工具 | 模块 | 用途 | Free 账号 |
|------|------|------|-----------|
| `get_company_registration_info` | company | 工商登记信息 | ✅ 可用 |
| `get_risk_overview` | risk | 风险概览 | ✅ 可用 |
| `get_shareholder_info` | company | 股东结构 | ❌ 需 VIP |
| `get_judicial_case` | risk | 司法案件 | ❌ 需 VIP |

- 经宿主 `McpOpenService` 统一调用，凭证宿主集中管理（脱敏）
- 每次调用记录 `due_diligence_mcp_call_log`（工具名/入参/耗时/状态）
- 有限次重试（超时/5xx 指数退避 ≤3，4xx 不重试）

### 4.3 股权结构穿透

- 沿股权关系逐层追溯，输出直接/间接股东、持股比例与路径、最终受益人
- 防循环（命中已访问节点终止）、层级上限约束（`--max-depth` 默认 5）

### 4.4 风险清单分级研判

- 从司法案件、行政处罚、经营异常等多源风险数据采集
- 按明确规则分级：高/中/低（附可解释依据 `level_basis`）
- 分级依据缺失标注"分级待定"及原因

### 4.5 尽调报告生成

- **四部分结构**：① 企业基本信息 ② 股权结构含穿透 ③ 风险清单分级标注 ④ 结论与建议
- **免责声明**："仅供参考、不构成投资/授信/准入决策依据"
- **多格式输出**：Markdown（核心）/ HTML / DOCX
- **降级策略**：LLM 不可2不可用时降级模板生成

### 4.6 企业信息持久化

- 6 张表幂等写入（先查后写：命中 UPDATE / 未命中 INSERT）
- 行级权限：`creator = userId`（INSERT 时显式设置）
- 判重规则：企业表 `credit_code + enterprise_name`，股权/风险/报告按业务特征联合判重

### 4.7 批量企业对比分析

- 批量尽调全流程：逐企业执行 → 横向对比 → 汇总报告 + 明细报告
- 部分失败隔离（单企业失败不中断批次）
- 进度反馈（已完成/失败/剩余）

---

## 五、数据库设计

### 5.1 新增 6 张表

| 表名 | 用途 |
|------|------|
| `due_diligence_task` | 尽调任务记录（单/批量、进度状态） |
| `due_diligence_enterprise` | 企业基础信息（天眼查工商采集结果） |
| `due_diligence_equity` | 股权结构条目（穿透计算后的股东与持股关系） |
| `due_diligence_risk` | 风险条目（多源风险分级结果） |
| `due_diligence_report` | 尽调报告（四部分结构化正文） |
| `due_diligence_mcp_call_log` | MCP 调用清单/日志（赛事评分凭证） |

### 5.2 表结构规范

- 主键：`id uuid DEFAULT gen_random_uuid()`
- 行级权限：`creator uuid`（关联 `uctoo_user.id`）
- 软删除：`deleted_at timestamptz`（NULL = 未删除）
- 时间戳：`created_at` / `updated_at`（`DEFAULT CURRENT_TIMESTAMP`）

DDL 文件：`apps/agentskills-runtime/sql/incremental/20260908_due_diligence_tables.sql`

---

## 六、使用方式

### 6.1 单企业尽调

```bash
cd skills/due_diligence_agent

# 全链路（Python 直连天眼查 MCP）
python scripts/run_dd_pipeline.py --enterprise "腾讯科技（深圳）有限公司"

# 经宿主 API（需宿主运行中）
python scripts/run_batch_dd.py --enterprises "腾讯科技（深圳）有限公司" --scene supplier --outdir output/
```

### 6.2 批量尽调

```bash
python scripts/run_batch_dd.py --enterprises "企业A,企业B,企业C" --scene investment --outdir output/
```

### 6.3 分步执行

```bash
# 1. 名单校验
python scripts/validate_enterprise_list.py --input "腾讯科技,阿里巴巴,,字节跳动"

# 2. 股权穿透
python scripts/penetrate_equity.py --input equity.json --enterprise "腾讯科技" --max-depth 5

# 3. 风险分级
python scripts/tier_risks.py --input risk.json --enterprise "腾讯科技"

# 4. 报告生成
python scripts/generate_dd_report.py --enterprise "腾讯科技" --basic-info basic.json --format md,html --outdir output/report
```

### 6.4 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `TIANYANCHA_MCP_TOKEN` | — | 天眼查 MCP API Key（宿主 `.env` 配置） |
| `HOST_BASE_URL` | `http://localhost:8080` | 宿主 API 基地址 |
| `MCP_ALIAS` | `tianyancha` | 天眼查 MCP 别名 |
| `PYTHONIOENCODING` | — | 须设为 `utf-8`（Windows 子进程编码） |

---

## 七、宿主侧增量开发

本智能体在 agentskills-runtime 宿主基础上新增以下组件：

| 组件 | 路径 | 说明 |
|------|------|------|
| `McpOpenService` | `src/app/services/mcp/McpOpenService.cj` | 宿主统一 MCP 开放服务（凭证管理 + 重试） |
| `McpOpenController` | `src/app/controllers/uctoo/mcpopen/` | HTTP API 控制器 |
| `McpOpenRoutes` | `src/app/routes/mcpopen/` | 路由注册 |
| `host.mcp` handler | `src/plugin/cordis_host_services.cj` | L3 插件经 `ctx.invoke("host.mcp", ...)` 调用 |
| `uctoo-mcp-call` CLI | `src/cli/mcp_call_cli.cj` | 命令行工具 |
| `plugins.yaml` 声明 | `config/plugins.yaml` | L3 process 插件声明 |

---

## 八、开发流程与工具链

```
人工 DDL → loaddbinfo → plugingen --mode process → cangjie-coder → 人工编译 → skill-creator
```

1. **DDL**：编写 6 张表 DDL，人工在 PostgreSQL 执行
2. **loaddbinfo**：`cjpm run --skip-build --name magic.app.tools.loaddbinfo --run-args "--db uctoo"`
3. **plugingen**：`cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name due_diligence_agent --db uctoo --table due_diligence_enterprise --mode process"`
4. **cangjie-coder**：仓颉四步流程编写插件代码（Consult → Retrieval → Editing → Writing）
5. **人工编译**：`cjpm build`（须在独立 cmd 环境执行）
6. **skill-creator**：生成 SKILL.md + COMPOSITION.yaml + 评估优化

---

## 九、验收结果

### 9.1 端到端联调

| 指标 | 结果 |
|------|------|
| 测试样本 | 腾讯科技（深圳）有限公司 |
| 端到端状态 | `status=completed, errors=0` |
| 总耗时 | ~9 秒（spec 要求 ≤60s） |
| MCP 调用 | 7 次（initialize + 2 call_tool + close 等） |
| 报告格式 | Markdown + HTML |
| 报告四部分 | ✅ 完整（基本信息/股权穿透/风险分级/结论建议） |
| 免责声明 | ✅ 包含 |

### 9.2 验收条件通过率

**39/43 = 90.7%**

- 2 项部分通过：天眼查 Free 账号限制（`get_shareholder_info`/`get_judicial_case` 需 VIP）
- 2 项未执行：批量 50+ 企业联调（Free 账号调用次数限制）

详细报告：`acceptance_report.md`

---

## 十、赛事评分凭证

| 凭证 | 路径 |
|------|------|
| MCP 调用日志 | `log/dd_pipeline_*.json` |
| 尽调报告（Markdown） | `output/report/腾讯科技（深圳）有限公司.md` |
| 尽调报告（HTML） | `output/report/腾讯科技（深圳）有限公司.html` |
| 工商信息原始数据 | `output/fetched/get_company_registration_info.md` |
| 风险概览原始数据 | `output/fetched/get_risk_overview.md` |
| 全链路结果 | `output/pipeline_result.json` |
| 数据入库 SQL | `apps/agentskills-runtime/sql/incremental/20260909_due_diligence_data_insert.sql`、 agentskills-runtime\skills\due_diligence_agent\sql 目录中due_diligence_agent开发和运行生成的数据库数据|

---

## 十一、进阶题说明
本参赛项目虽然未使用赛题要求的技术栈，但是用仓颉编程语言完全实现了对标赛题要求技术栈的全链路开源基础设施，是更加基础和原创的产品能力，可与已有产品线形成差异化全覆盖的解决方案。aagentskills-runtime\skills\due_diligence_agent目录中是赛题开发产物，agentskills-runtime\.codeartsdoer\specs\due_diligence_agent目录中是赛题开发规范驱动文档。 due_diligence_agent实现了【基础赛题】企业信用与风控尽调智能体要求的全部功能，又实现了【进阶题二】多智能体协作创新的能力，展示了如何用支持仓颉语言的技能插件和python的动态语言的服务编排良好协作的能力。

进阶题一（办公提效助手 + 多智能体协作）直接复用既有 `fintech-agent-hackathon` 成果，不在本插件范围内展开。
进阶题二（多智能体协作创新）due_diligence_agent 本身的开发过程即示例了AI驱动开发框架的代码+技能+数据库全流程自主进化能力。

---

## 十二、技术约束

- **仓颉编译**：严禁在开发工具内运行 `cjpm build`，须人工在独立 cmd 环境执行
- **MCP/HTTP**：优先用 `http_lib` 库（已替代 `stdx.net.http`）
- **POST 路由**：禁止 `req.takenOver` 连接劫持，用 `res.json()`/`res.send()` 返回
- **凭证脱敏**：天眼查 API Key 仅存宿主 `.env`，插件与脚本不接触凭证本体
- **SSL**：Python 脚本禁止禁用 SSL（`verify=False`），须正常使用 SSL
- **permissions**：`host.db` 调用时 permissions 为空数组不设置该字段（避免行级权限过滤导致查不到数据）

---

## License

MIT