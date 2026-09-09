---
name: due-diligence-agent
description: 企业信用与风控尽调智能体 —— 自动采集天眼查企业数据、股权穿透、风险分级、生成结构化尽调报告并入库。触发词："尽调"、"企业尽调"、"信用尽调"、"风控尽调"、"供应商尽调"、"客户授信"、"投资尽调"、"竞对分析"、"合规排查"、"Due Diligence"、"KYB"。
license: MIT
version: "1.0.0"
compatibility: 需要 runtime 内置工具支持（cli_execute/file_read/file_write/http_request），脚本执行需 Python 3.8+ + requests 库，天眼查 MCP 凭证（TIANYANCHA_MCP_TOKEN）
metadata:
  author: UCToo Team
  version: "1.0.0"
  category: risk-management
  tags: ["due-diligence", "credit-risk", "kyb", "tianyancha", "enterprise-screening", "尽调", "风控"]
allowed-tools: network, filesystem, cli
---

# 企业信用与风控尽调智能体（Due Diligence Agent）

## 概述

本技能实现企业信用与风控尽调全流程最佳实践 SOP：
**名单校验 → 数据采集 → 股权穿透 → 风险分级 → 报告生成 → 幂等落库**。

- 数据来源：天眼查 MCP（工商登记 / 股东信息 / 司法案件等 ≥2 类 ≥3 工具）
- 输出形态：结构化尽调报告（Markdown / HTML / DOCX），含四部分 + 免责声明
- 落库方式：6 张表幂等写入（task / enterprise / equity / risk / report / mcp_call_log）
- 运行底座：agentskills-runtime（仓颉 L3 进程隔离轨插件 + 宿主统一 MCP 开放服务）

## 全流程 SOP

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│ 1. 校验   │ → │ 2. 采集   │ → │ 3. 穿透   │ → │ 4. 分级   │ → │ 5. 报告   │ → │ 6. 落库   │
│ validate │   │ dd-fetch │   │ penetrate│   │ tier     │   │ generate │   │ dd-save  │
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
```

### Step 1：名单校验（Validate）

对企业名单进行非空校验、首尾空白清洗、非法字符标注、自动去重。

- **脚本**：`scripts/validate_enterprise_list.py`
- **输入**：企业名单（逗号分隔或文件）
- **输出**：清洗后名单 + 无效条目清单
- **验收**：空名单报错；重复企业去重并提示；非法条目标注

### Step 2：数据采集（dd-fetch）

经宿主统一 MCP 开放服务调用天眼查 ≥2 类 ≥3 个工具采集企业数据。

| 工具 | 模块 | 用途 |
|------|------|------|
| `registration-info` | company | 工商登记信息（名称/信用代码/法人/注册资本/成立日期/经营范围） |
| `shareholder-info` | company | 股东结构信息（股东名称/持股比例/持股路径） |
| `judicial-case` | risk | 司法案件信息（案件类型/日期/描述） |

- **参数**：`searchKey`（企业名称或统一社会信用代码）
- **调用链**：`脚本 → HTTP API → 宿主 McpOpenService → HttpMCPClient → 天眼查 MCP`
- **审计**：每次调用记录 `due_diligence_mcp_call_log`（工具名/入参/耗时/状态）
- **凭证**：天眼查 Token 仅存宿主 `.env`，插件与脚本不接触凭证本体

### Step 3：股权穿透（Penetrate）

沿股权关系逐层穿透，计算直接/间接股东、持股比例与路径、最终受益人。

- **脚本**：`scripts/penetrate_equity.py`
- **输入**：`shareholder-info` 返回的股权树 JSON
- **输出**：穿透结果 JSON（持股比例/穿透层级/持股路径/是否最终受益人）
- **约束**：防循环（命中已访问节点终止）、层级上限 `--max-depth`（默认 5）

### Step 4：风险分级（Tier）

从多源风险数据采集风险条目，按明确规则分级（高/中/低），附可解释依据。

- **脚本**：`scripts/tier_risks.py`
- **输入**：`dd-fetch` 返回的风险数据
- **输出**：分级风险 JSON（risk_type/risk_level/level_basis/risk_description/source_tool）
- **规则**：司法案件 → 高/中/低（按金额/严重程度）；行政处罚 → 中/低；经营异常 → 低
- **可解释**：每条风险附分级依据说明；依据缺失标注"分级待定"及原因

### Step 5：报告生成（Generate）

汇编四部分结构化尽调报告，含免责声明。

- **脚本**：`scripts/generate_dd_report.py`
- **四部分**：① 企业基本信息 ② 股权结构含穿透 ③ 风险清单分级标注 ④ 结论与建议
- **免责声明**："本报告仅供参考，不构成投资/授信/准入决策建议"
- **格式**：Markdown（核心）/ HTML / DOCX
- **降级**：LLM 不可用时降级模板生成

### Step 6：幂等落库（dd-save）

经插件 `dd-save` handler 幂等写入 6 张表（先查后写：命中 UPDATE / 未命中 INSERT）。

- **判重规则**：
  - 企业表：`credit_code` + `enterprise_name`
  - 股权表：`enterprise_id` + `shareholder_name` + `penetration_level`
  - 风险表：`enterprise_id` + `risk_type` + `risk_description`
  - 报告表：`enterprise_id` + `report_format`
- **行级权限**：`creator = userId`（INSERT 时显式设置）

## 使用方式

### 单企业尽调

```bash
python scripts/run_batch_dd.py --enterprises "腾讯科技（深圳）有限公司" --scene supplier --outdir output/
```

### 批量尽调

```bash
python scripts/run_batch_dd.py --enterprises "企业A,企业B,企业C" --scene investment --outdir output/
```

### 场景类型

| 场景 | 说明 |
|------|------|
| `supplier` | 供应商尽调 |
| `credit` | 客户授信初筛 |
| `investment` | 投资标的画像 |
| `competitor` | 竞对情报 |
| `related_risk` | 关联风险穿透 |

## 数据约束

- 统一社会信用代码 18 位，唯一性辅助判重
- 持股比例 0~100.00%（numeric(5,2)）
- 穿透层级 0=直接股东，1=间接第一层，以此类推
- 是否最终受益人：是/否
- 风险等级：高/中/低
- MCP 调用日志：赛事评分凭证与审计依据

## DFX 约束

- **重试**：MCP 调用超时/5xx 指数退避 ≤3 次，4xx 不重试
- **鉴权失败**：明确提示"天眼查 MCP 凭证无效或过期"
- **审计留痕**：所有 MCP 调用记录 `due_diligence_mcp_call_log`
- **幂等**：重复执行更新而非重复插入
- **批量隔离**：单企业失败不中断批次
- **凭证脱敏**：日志/报告/响应中一律脱敏