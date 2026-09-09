# 企业信用与风控尽调智能体 编码任务规划

> **文档定位**：本文档将 `design.md`（方案 B：宿主统一 MCP 开放服务 + L3 插件 6 张表 CRUD + Python/TS 脚本业务编排）拆解为可执行、可验收的编码任务清单，按依赖顺序编排。
>
> **配套文档**：`spec.md`（需求规格）、`design.md`（实现方案设计）。
> **运行底座**：agentskills-runtime（仓颉语言，L3 进程隔离轨插件机制 / 一切皆技能）。
> **版本**：v1.0 | **日期**：2026-09-08

---

## 项目铁律（全任务强制遵守）

1. **严禁 `cjpm build` 自动编译**：开发工具内运行编译会长时间超时；所有仓颉编译验证须由**人工在独立 cmd 环境**执行并反馈结果。
2. **仓颉代码必须先检索到确定编码依据再生成**：cangjie-coder 四步流程（`doc-consultant` → `code-searcher` → `code-editor` → `code-verifier`），严禁直接大模型生成。
3. **MCP/HTTP 优先用 `http_lib` 库**：复用 `src/utils/http/http_cj.cj` + `src/mcp/http_mcp_client.cj`，禁止引入已废弃的 `stdx.net.http`/`stdx.net.tls` 手写 HTTPS。
4. **POST 路由禁止连接劫持**：宿主 Controller 与插件路由统一用 `res.json()`/`res.send()` 声明式返回，**严禁 `req.takenOver = true` + `ConnectionController.write()`**。
5. **凭证脱敏、宿主集中管理**：天眼查 API Key 仅存宿主（`.env`/`EnvFileService`），插件与脚本不接触凭证本体，日志/报告/响应中一律脱敏。
6. **数据库变更须先落 DDL 再 loaddbinfo**：表结构变更在 `sql/incremental/` 目录生成 DDL 并由人工执行，之后 `cjpm run --skip-build --name magic.app.tools.loaddbinfo --run-args "--db uctoo"` 加载到 `db_info`。

---

## 任务元信息约定

每个任务项标注：
- **任务 ID**：T<阶段>.<子序>
- **所属层**：宿主 / 插件 / 脚本 / 技能 / 文档 / 数据库
- **依赖任务**：前置任务 ID
- **输入产物** / **输出产物**
- **验收标准**
- **负责角色**：cangjie-coder / skill-creator / 人工编译 / 人工 DDL / 脚本编写 / 人工联调

---

## 1. 数据库 DDL 与表结构加载

> 对应 design.md §2.3.3 步骤 0、1。6 张新表 DDL 须先于一切代码生成。

### 1.1 T1.1 人工编写 6 张表 DDL 文件
- [ ] 在 `sql/incremental/` 目录新建 `20260908_due_diligence_tables.sql`，按 design.md §2.3.2 表结构编写 6 张表 DDL：`due_diligence_task`、`due_diligence_enterprise`、`due_diligence_equity`、`due_diligence_risk`、`due_diligence_report`、`due_diligence_mcp_call_log`。
  - **所属层**：数据库
  - **依赖任务**：无
  - **输入产物**：design.md §2.3.2 表结构定义、`sql/incremental/20260807_fintech_demo_company.sql`（规范样例）
  - **输出产物**：`sql/incremental/20260908_due_diligence_tables.sql`
  - **验收标准**：6 张表均含规范骨架字段（`id uuid DEFAULT gen_random_uuid()`、`creator uuid`、`created_at/updated_at/deleted_at timestamptz`）；字段类型/约束与 design.md §2.3.2 一致；`due_diligence_equity.shareholding_ratio` 为 `numeric(5,2)`；`due_diligence_enterprise.enterprise_list` 为 `jsonb`。
  - **负责角色**：人工 DDL

### 1.2 T1.2 人工在 PostgreSQL 执行 DDL
- [ ] 在目标 PostgreSQL（uctoo 库）执行 `20260908_due_diligence_tables.sql`，确认 6 张表创建成功。
  - **所属层**：数据库
  - **依赖任务**：T1.1
  - **输入产物**：`sql/incremental/20260908_due_diligence_tables.sql`
  - **输出产物**：uctoo 库内 6 张新表
  - **验收标准**：`\dt due_diligence_*` 列出 6 张表；字段与 DDL 一致。
  - **负责角色**：人工 DDL

### 1.3 T1.3 执行 loaddbinfo 加载表结构
- [ ] 执行 `cjpm run --skip-build --name magic.app.tools.loaddbinfo --run-args "--db uctoo"`，从 `information_schema` 读取 6 张新表结构写入 `db_info` 表。
  - **所属层**：数据库
  - **依赖任务**：T1.2
  - **输入产物**：uctoo 库内 6 张新表
  - **输出产物**：`db_info` 表含 6 张新表结构元数据
  - **验收标准**：`db_info` 中可查到 6 张 `due_diligence_*` 表及其字段；后续 `plugingen` 可读结构生成代码。
  - **负责角色**：人工 DDL

---

## 2. 宿主统一 MCP 开放服务

> 对应 design.md §2.0、§2.3.3 步骤 2。宿主侧复用 `magic.mcp.HttpMCPClient` + http_lib，零移植。

### 2.1 T2.1 cangjie-coder 编写 McpOpenService（宿主核心服务）
- [ ] 走 cangjie-coder 四步流程编写 `McpOpenService`（建议路径 `src/app/services/mcp/McpOpenService.cj`，包 `magic.app.services.mcp`）：
  - ① `doc-consultant`：查阅 `libs/http_lib/docs/client/` 使用手册 + CangjieSkills 文档；
  - ② `code-searcher`：检索首选依据 `src/mcp/http_mcp_client.cj`（`HttpMCPClient` 组装复用）、`src/mcp/mcp_client.cj`、`src/mcp/protocol.cj`、`src/utils/http/http_cj.cj`、`src/utils/http/http_utils.cj`、`src/app/services/uctoo/EnvFileService.cj`；备选 `CangjieMagic/src/examples`（降级）；
  - ③ `code-editor`：实现 `mcpAlias → {endpoint, credentialRef}` 映射解析 + 组装 `HttpMCPInitParams{url, header}` 注入凭证 + `initialize → tools/call` + 有限次重试（超时/5xx 指数退避 ≤3，4xx 不重试）+ 返回 `{data, meta:{tool, durationMs, status, errorMessage}}`；**服务无落库副作用**；
  - ④ `code-verifier`：验证（失败自动修复 ≤3 次）。
  - **所属层**：宿主
  - **依赖任务**：T1.3
  - **输入产物**：宿主既有 `magic.mcp` / `magic.utils.http` 代码、http_lib 库
  - **输出产物**：`src/app/services/mcp/McpOpenService.cj`
  - **验收标准**：可按 `mcpAlias + tool + arguments` 调用并返回结构化结果 + meta；凭证从 `EnvFileService` 读取且脱敏；重试策略符合状态机（design.md §2.1.3(1)）；不引入 `stdx.net.http`。
  - **负责角色**：cangjie-coder

### 2.2 T2.2 cangjie-coder 编写 McpOpenController + McpOpenRoute（HTTP API）
- [ ] 走 cangjie-coder 四步流程编写 `McpOpenController`（建议 `src/app/controllers/uctoo/mcpopen/McpOpenController.cj`）+ `McpOpenRoute`（建议 `src/app/routes/mcpopen/McpOpenRoutes.cj`），注册 `POST /api/v1/uctoo/mcp/open/call`。
  - **code-searcher 检索依据**：`src/app/controllers/uctoo/webmcp/WebMCPController.cj`（非流式 `res.json()` 范式）、`src/app/routes/webmcp/WebMCPRoutes.cj`、`src/app/core/router/Router.cj`。
  - **关键约束**：同步 JSON 请求/响应，Controller 用 `res.json()`/`res.send()` 返回；**严禁 `req.takenOver = true` 连接劫持**；过 `RequirePermission` 鉴权 + `mcpAlias` 白名单校验。
  - **所属层**：宿主
  - **依赖任务**：T2.1
  - **输入产物**：`McpOpenService.cj`、宿主路由范式
  - **输出产物**：`McpOpenController.cj`、`McpOpenRoutes.cj`
  - **验收标准**：`POST /api/v1/uctoo/mcp/open/call` 可接收 `{mcpAlias, tool, arguments}` 返回 `{errno:0, data, meta}`；错误返回 `{errno, errmsg}`；无连接劫持代码。
  - **负责角色**：cangjie-coder

### 2.3 T2.3 cangjie-coder 扩展 cordis_host_services.cj 新增 host.mcp 服务
- [ ] 走 cangjie-coder 四步流程扩展 `src/plugin/cordis_host_services.cj`，在 `registerFor(instance, pluginId)` 内新增 `client.registerRequestHandler("host.mcp", …)`，方法 `call`，params `{mcpAlias, tool, arguments}`，委托 `McpOpenService` 返回 `{data, meta}` 或 `{error}`。
  - **code-searcher 检索依据**：`src/plugin/cordis_host_services.cj`（`host.db`/`host.log`/`host.cache` 同构范式）。
  - **所属层**：宿主
  - **依赖任务**：T2.1
  - **输入产物**：`McpOpenService.cj`、`cordis_host_services.cj`
  - **输出产物**：`cordis_host_services.cj`（新增 host.mcp handler）
  - **验收标准**：L3 插件可经 `ctx.invoke("host.mcp", "call", args)` 调用并得到 `{data, meta}`；与 `host.db` 注册机制同构。
  - **负责角色**：cangjie-coder

### 2.4 T2.4 cangjie-coder 新增宿主 CLI 工具 uctoo-mcp-call
- [ ] 走 cangjie-coder 四步流程新增宿主 CLI 子命令 `uctoo-mcp-call --alias <mcpAlias> --tool <tool> --args '<json>'`，stdout 输出 `{data, meta}` JSON。
  - **code-searcher 检索依据**：`src/tool/cli_tool.cj`（`cli_execute` / `newProcess` 模式）。
  - **所属层**：宿主
  - **依赖任务**：T2.1
  - **输入产物**：`McpOpenService.cj`、`cli_tool.cj`
  - **输出产物**：宿主 CLI `uctoo-mcp-call`
  - **验收标准**：命令行可调通天眼查 MCP 工具并输出 JSON；可被脚本经 `cli_execute` 调用。
  - **负责角色**：cangjie-coder

### 2.5 T2.5 宿主凭证配置（mcpAlias 映射 + EnvFileService）
- [ ] 配置天眼查 MCP 凭证：在宿主 `.env` 写入 `TIANYANCHA_MCP_TOKEN` 等凭证；建立 `mcpAlias → {endpoint, credentialRef}` 映射（`tianyancha → {https://mcp.tianyancha.com/mcp, TIANYANCHA_MCP_TOKEN}`），由 `McpOpenService` 解析。
  - **所属层**：宿主
  - **依赖任务**：T2.1
  - **输入产物**：天眼查 MCP 接入凭证
  - **输出产物**：`.env` 配置项、mcpAlias 映射
  - **验收标准**：`McpOpenService` 可按 `mcpAlias="tianyancha"` 解析出端点 + 凭证；凭证不出现在日志/响应。
  - **负责角色**：人工联调

---

## 3. L3 插件骨架生成与仓颉代码编写

> 对应 design.md §2.3.3 步骤 3、4。插件承载 6 张表 CRUD + dd-fetch 采集聚合 + dd-save 落库。

### 3.1 T3.1 plugingen 生成 L3 轨插件骨架
- [ ] 执行 `cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name due_diligence_agent --db uctoo --table due_diligence_enterprise --mode process"`，生成 L3 轨进程插件骨架到 `skills/due_diligence_agent/`（含 `plugin.yaml` + `cjpm.toml` + `src/main.cj` + `handlers.cj` + `effects.cj`）。
  - **所属层**：插件
  - **依赖任务**：T1.3、T2.3（host.mcp 契约就绪）
  - **输入产物**：`db_info` 中 6 张表结构
  - **输出产物**：`skills/due_diligence_agent/` 插件骨架
  - **验收标准**：`plugin.yaml` 含 6 条标准 CRUD 路由 + `dd-fetch`/`dd-save` 自定义路由声明；`cjpm.toml` 依赖 `cordis_plugin`/`cordis_core`/`jsonvalue`/`jsonrpc`（**无需 http_lib**，插件不再自建 MCP 客户端）；`command` 指向 `./target/release/bin/skill_due_diligence_agent.exe`。
  - **负责角色**：人工联调（执行 plugingen）

### 3.2 T3.2 cangjie-coder 编写 dd_handlers.cj（CRUD 分发 + dd-fetch + dd-save）
- [ ] 走 cangjie-coder 四步流程编写 `skills/due_diligence_agent/src/dd_handlers.cj`：
  - ① `doc-consultant`：查阅 CangjieSkills 文档（json/jsonvalue 等）；
  - ② `code-searcher`：检索首选依据 `skills/codelabs/src/handlers.cj`（`dispatch` 路由分发 + `host.db` 调用 + 白名单字段范式）、`src/plugin/cordis_host_services.cj`（`host.mcp` 契约）；
  - ③ `code-editor`：实现 6 张表 CRUD 分发（列表/单查/增删改查，列表键名 = 表名 + s）+ `dd-fetch`（经 `ctx.invoke("host.mcp", "call", …)` 依次调 ≥2 类 ≥3 工具：registration-info / shareholder-info / judicial-case 等，参数 `searchKey` 传企业名或统一社会信用代码，每次据返回 `meta` 经 `host.db` 写 `due_diligence_mcp_call_log`，汇总结构化结果）+ `dd-save`（经 `host.db` 幂等 upsert 企业/股权/风险/报告）；
  - ④ `code-verifier`：验证（失败自动修复 ≤3 次）。
  - **所属层**：插件
  - **依赖任务**：T3.1、T2.3
  - **输入产物**：插件骨架、codelabs 范式、host.mcp 契约
  - **输出产物**：`dd_handlers.cj`
  - **验收标准**：6 张表 CRUD 路由可分发；`dd-fetch` 可聚合 ≥2 类 ≥3 工具调用并落 `mcp_call_log`；`dd-save` 可幂等 upsert；INSERT 时显式设置 `creator = userId`；诊断信息走 stderr。
  - **负责角色**：cangjie-coder

### 3.3 T3.3 cangjie-coder 编写 persist_service.cj（6 张表幂等读写封装）
- [ ] 走 cangjie-coder 四步流程编写 `skills/due_diligence_agent/src/persist_service.cj`，封装 6 张表经 `host.db` 的幂等读写（先查后写：命中 UPDATE / 未命中 INSERT），含 `mcp_call_log` 落库。
  - **code-searcher 检索依据**：`skills/codelabs/src/handlers.cj`（`host.db` execute 参数：`table/subOp/where/data/userId/permissions`、`$raw:` 前缀约定）。
  - **所属层**：插件
  - **依赖任务**：T3.1
  - **输入产物**：插件骨架、codelabs host.db 范式
  - **输出产物**：`persist_service.cj`
  - **验收标准**：企业表以 `credit_code` + `enterprise_name` 联合判重；股权/风险以 `enterprise_id + 特征` 判重；重复执行更新而非重复插入；`creator` 由 `ExternalRequest.userId` 显式写入。
  - **负责角色**：cangjie-coder

### 3.4 T3.4 cangjie-coder 校验 dd_effects.cj（可逆效果注册）
- [ ] 走 cangjie-coder 四步流程校验/补全 `skills/due_diligence_agent/src/dd_effects.cj`（ctx.effect 可逆效果注册框架）。
  - **code-searcher 检索依据**：`skills/codelabs/src/effects.cj`。
  - **所属层**：插件
  - **依赖任务**：T3.1
  - **输入产物**：插件骨架、codelabs effects 范式
  - **输出产物**：`dd_effects.cj`
  - **验收标准**：与 codelabs effects 同构；不影响 CRUD/dd-fetch/dd-save 主流程。
  - **负责角色**：cangjie-coder

---

## 4. 人工编译验证

> 对应 design.md §2.3.3 步骤 5。**项目铁律：开发工具内严禁 cjpm build，须人工在独立 cmd 环境执行。**

### 4.1 T4.1 人工编译宿主主工程
- [ ] 人工在独立 cmd 环境对宿主主工程执行 `cjpm build`，反馈编译结果；若有错误，回传给 cangjie-coder 修复（重走 code-editor → code-verifier），再人工编译，直至通过。
  - **所属层**：宿主
  - **依赖任务**：T2.1、T2.2、T2.3、T2.4
  - **输入产物**：宿主新增/修改的仓颉源码
  - **输出产物**：宿主编译产物 + 编译通过确认
  - **验收标准**：宿主主工程 `cjpm build` 通过；`McpOpenService`/`McpOpenController`/`host.mcp`/`uctoo-mcp-call` 均编入产物。
  - **负责角色**：人工编译

### 4.2 T4.2 人工编译 L3 插件工程
- [ ] 人工在独立 cmd 环境对 `skills/due_diligence_agent/` 执行 `cjpm build`，反馈编译结果；若有错误，回传给 cangjie-coder 修复，再人工编译，直至通过。
  - **所属层**：插件
  - **依赖任务**：T3.2、T3.3、T3.4
  - **输入产物**：插件仓颉源码
  - **输出产物**：`skills/due_diligence_agent/target/release/bin/skill_due_diligence_agent.exe` + 编译通过确认
  - **验收标准**：插件 `cjpm build` 通过；产物路径与 `plugin.yaml` 的 `command` 一致；插件不进宿主编译图。
  - **负责角色**：人工编译

---

## 5. Python/TS 脚本业务编排

> 对应 design.md §1.1.3 D 层、§2.2.2 组 C。脚本承载业务流程（穿透/分级/报告），经 HTTP API / cli_execute 调宿主开放服务与插件 API。

### 5.1 T5.1 编写 validate_enterprise_list.py（名单校验/清洗/去重）
- [ ] 编写 `skills/due_diligence_agent/scripts/validate_enterprise_list.py`，实现名单非空校验、首尾空白清洗、非法字符标注、自动去重，输出校验结果 + 无效条目清单。
  - **所属层**：脚本
  - **依赖任务**：无（可并行于宿主/插件开发）
  - **输入产物**：spec.md §5.1 业务规则
  - **输出产物**：`validate_enterprise_list.py`
  - **验收标准**：空名单返回"企业名单不能为空"；重复企业去重并提示；非法条目单独标注；CLI 支持 `--input` 参数。
  - **负责角色**：脚本编写

### 5.2 T5.2 编写 penetrate_equity.py（股权穿透计算）
- [ ] 编写 `skills/due_diligence_agent/scripts/penetrate_equity.py`，沿股权关系逐层穿透，输出直接/间接股东、持股比例与路径、最终受益人；防循环（命中已访问节点终止）、层级上限约束。
  - **所属层**：脚本
  - **依赖任务**：T5.1
  - **输入产物**：`dd-fetch` 返回的股权树原始 JSON、spec.md §5.3/§6.2
  - **输出产物**：`penetrate_equity.py`、`output/penetration/{name}.json`
  - **验收标准**：输出含持股比例（0~100%）、穿透层级、持股路径、是否最终受益人；循环持股标注终止；支持 `--max-depth`。
  - **负责角色**：脚本编写

### 5.3 T5.3 编写 tier_risks.py（风险分级研判）
- [ ] 编写 `skills/due_diligence_agent/scripts/tier_risks.py`，从司法/行政处罚/经营异常等多源风险数据采集风险条目，按明确规则分级（高/中/低），附分级依据说明（可解释）。
  - **所属层**：脚本
  - **依赖任务**：T5.1
  - **输入产物**：`dd-fetch` 返回的风险数据、spec.md §5.4/§6.3
  - **输出产物**：`tier_risks.py`、`output/risks/{name}.json`
  - **验收标准**：每条风险含 risk_type/risk_level/level_basis/risk_description/source_tool；分级依据可追溯；分级依据缺失标注"分级待定"及原因。
  - **负责角色**：脚本编写

### 5.4 T5.4 编写 generate_dd_report.py（尽调报告生成）
- [ ] 编写 `skills/due_diligence_agent/scripts/generate_dd_report.py`，汇编四部分报告（企业基本信息/股权结构含穿透/风险清单分级标注/结论与建议），含免责声明；LLM 增强结论生成 + 不可用时降级模板；支持 Markdown（核心）/word/网页多格式输出。
  - **所属层**：脚本
  - **依赖任务**：T5.2、T5.3
  - **输入产物**：穿透结果、分级风险、spec.md §5.5/§6.4
  - **输出产物**：`generate_dd_report.py`、`output/report/{name}.{md|docx|html}`
  - **验收标准**：报告四部分缺一不可（数据缺失占位标注）；含免责声明"仅供参考、不构成投资/授信/准入决策"；LLM 不可用时降级模板生成；支持 `--format md,docx,html`。
  - **负责角色**：脚本编写

### 5.5 T5.5 编写 run_batch_dd.py（批量任务编排）
- [ ] 编写 `skills/due_diligence_agent/scripts/run_batch_dd.py`，批量尽调全流程入口：名单校验 → 创建任务记录 → 逐企业（dd-fetch 采集 → 穿透 → 分级 → 报告 → dd-save 落库）→ 汇总横向对比 + 汇总报告；部分失败隔离；进度反馈。
  - **所属层**：脚本
  - **依赖任务**：T5.1、T5.2、T5.3、T5.4、T3.2（dd-fetch/dd-save 就绪）
  - **输入产物**：T5.1~T5.4 脚本、插件 dd-fetch/dd-save 接口
  - **输出产物**：`run_batch_dd.py`、`output/report/` 汇总 + 明细报告
  - **验收标准**：支持 `--enterprises "A,B,C" --scene supplier --outdir output/`；单企业失败不中断批次，汇总报告标注失败企业及原因；输出汇总报告 + 各企业明细；进度反馈（已完成/失败/剩余）。
  - **负责角色**：脚本编写

---

## 6. 技能生成与评估

> 对应 design.md §2.3.3 步骤 6、§1.1.3 E 层。skill-creator 生成/评估/优化 due-diligence-agent 技能。

### 6.1 T6.1 skill-creator 生成 due-diligence-agent 技能草稿
- [ ] 走 skill-creator 流程生成 `skills/due_diligence_agent/SKILL.md`（尽调 SOP 说明）+ `COMPOSITION.yaml`（步骤编排声明：validate → dd-fetch → penetrate → tier → generate → dd-save，step_type: script + depends_on）。
  - **所属层**：技能
  - **依赖任务**：T5.5、T4.2
  - **输入产物**：T5.1~T5.5 脚本、插件 dd-fetch/dd-save 接口、投研助手 COMPOSITION.yaml 范式
  - **输出产物**：`SKILL.md`、`COMPOSITION.yaml`
  - **验收标准**：SKILL.md 描述尽调 SOP 完整流程；COMPOSITION.yaml 步骤依赖正确；可被 `cli_execute` 编排。
  - **负责角色**：skill-creator

### 6.2 T6.2 skill-creator 评估与迭代优化
- [ ] 走 skill-creator 流程：造测试 prompt 运行 → 定性+定量评估（`eval-viewer/generate_review.py`）→ 依据反馈重写 → 扩大测试集，循环至满意；固化"企业名单→报告+入库"验收样本。
  - **所属层**：技能
  - **依赖任务**：T6.1
  - **输入产物**：技能草稿、验收样本企业名单
  - **输出产物**：优化后的 SKILL.md/COMPOSITION.yaml + 评估报告
  - **验收标准**：评估报告显示尽调流程稳定可复现；验收样本企业可端到端产出报告 + 入库。
  - **负责角色**：skill-creator

---

## 7. 端到端联调与验收

> 对照 spec.md 验收条件做端到端验证。

### 7.1 T7.1 单企业尽调端到端联调
- [ ] 以单个真实企业名称发起尽调，验证全链路：名单校验 → dd-fetch（经 host.mcp 调天眼查 ≥2 类 ≥3 工具）→ 穿透 → 分级 → 报告生成 → dd-save 落库 → MCP 调用日志落 `due_diligence_mcp_call_log`。
  - **所属层**：文档（联调）
  - **依赖任务**：T4.1、T4.2、T5.5、T6.1
  - **输入产物**：编译通过的宿主 + 插件 + 脚本 + 技能、天眼查 MCP 凭证
  - **输出产物**：单企业尽调报告 + 入库数据 + 调用日志
  - **验收标准**：60 秒内完成（不含 MCP 网络抖动）；报告四部分完整；MCP 调用清单记录 ≥2 类 ≥3 工具；企业信息入库可查询；凭证不出现在日志/报告。
  - **负责角色**：人工联调

### 7.2 T7.2 批量尽调端到端联调
- [ ] 以不少于 50 个企业名单发起批量尽调，验证批量编排、部分失败隔离、进度反馈、横向对比、汇总报告 + 明细报告。
  - **所属层**：文档（联调）
  - **依赖任务**：T7.1
  - **输入产物**：50+ 企业名单
  - **输出产物**：批量汇总报告 + 各企业明细报告
  - **验收标准**：部分企业失败不中断批次；汇总报告标注失败企业及原因；进度反馈（已完成/失败/剩余）；输出横向对比结果。
  - **负责角色**：人工联调

### 7.3 T7.3 验收测试（对照 spec.md 验收条件）
- [ ] 逐项核对 spec.md §5.1~§5.7 验收条件与 §4 DFX 约束：名单校验、多类别采集、股权穿透、风险分级可解释、报告四部分 + 免责声明、幂等入库、批量对比、MCP 重试、鉴权失败提示、审计留痕、多格式输出、API/CLI 兼容。
  - **所属层**：文档
  - **依赖任务**：T7.2
  - **输入产物**：端到端联调结果
  - **输出产物**：验收核对清单（通过/未通过 + 证据）
  - **验收标准**：spec.md 所有验收条件均有对应测试证据；未通过项有跟进措施。
  - **负责角色**：人工联调

---

## 8. 赛事举证材料与文档

### 8.1 T8.1 整理赛事评分凭证材料
- [ ] 整理赛事评分所需凭证：天眼查 MCP 工具调用清单与调用日志（`due_diligence_mcp_call_log` 导出）、结构化尽调报告样本（Markdown/word/网页）、入库企业信息样本、批量对比报告、技能评估报告。
  - **所属层**：文档
  - **依赖任务**：T7.3
  - **输入产物**：联调产物、数据库导出
  - **输出产物**：赛事举证材料包
  - **验收标准**：调用清单含工具名/入参/耗时/结果状态；报告含四部分 + 免责声明；材料可独立查阅。
  - **负责角色**：人工联调

### 8.2 T8.2 更新技能与项目文档
- [ ] 更新 `skills/due_diligence_agent/SKILL.md`（使用说明）、`plugin.yaml`（路由声明最终版）、README（可选）；确认接口文档向后兼容。
  - **所属层**：文档
  - **依赖任务**：T8.1
  - **输入产物**：最终实现
  - **输出产物**：更新后的文档
  - **验收标准**：文档与实现一致；接口变更保持向后兼容。
  - **负责角色**：人工联调

---

## 9. 进阶题说明

> **进阶题一（fintech-agent-hackathon 复用：办公提效助手 + 多智能体协作）不纳入本 tasks.md**，仅复用既有 `fintech-agent-hackathon` 成果，本任务清单不展开。

---

## 任务依赖关系总览

```
T1.1 → T1.2 → T1.3
                ├→ T2.1 → T2.2 ┐
                │       ├→ T2.3 ┐
                │       ├→ T2.4 ┤
                │       └→ T2.5 ┤
                └→ T3.1 ─────────┤
                        ├→ T3.2 ← T2.3
                        ├→ T3.3
                        └→ T3.4
T2.* → T4.1（人工编译宿主）
T3.* → T4.2（人工编译插件）
T5.1 → T5.2 → T5.4
T5.1 → T5.3 → T5.4
T5.4 + T3.2 → T5.5
T5.5 + T4.2 → T6.1 → T6.2
T4.1 + T4.2 + T5.5 + T6.1 → T7.1 → T7.2 → T7.3 → T8.1 → T8.2
```

---

## 任务统计

- **主任务组**：9 个阶段
- **子任务总数**：22 个（T1.1~T1.3、T2.1~T2.5、T3.1~T3.4、T4.1~T4.2、T5.1~T5.5、T6.1~T6.2、T7.1~T7.3、T8.1~T8.2）
- **负责角色分布**：
  - cangjie-coder（仓颉四步流程）：T2.1、T2.2、T2.3、T2.4、T3.2、T3.3、T3.4（7 项）
  - skill-creator（技能生成/评估）：T6.1、T6.2（2 项）
  - 人工编译（独立 cmd cjpm build）：T4.1、T4.2（2 项）
  - 人工 DDL（sql/incremental + PostgreSQL + loaddbinfo）：T1.1、T1.2、T1.3（3 项）
  - 脚本编写（Python/TS）：T5.1~T5.5（5 项）
  - 人工联调/配置/验收/文档：T2.5、T3.1、T7.1、T7.2、T7.3、T8.1、T8.2（7 项）
- **覆盖 spec.md 核心能力**：§5.1~§5.7 全部、§4 DFX 全部、§6 数据约束全部