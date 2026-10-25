---
name: yuanbao-search
description: 元宝搜索（腾讯云 wsa · SearchPro）检索内核 —— 提供政策/产业信息检索、可信度四因子标注与政策原文库交叉验证。当需要根据企业名称或政策主题收集可溯源的公开线索、判定信息是否可信、并在查不到可靠依据时明确说"不知道"时使用；配合 beichen-policy-assistant 完成画像→匹配→报告→落库→巡检闭环。
license: MIT
metadata:
  author: UCToo Team
  version: "1.0.0"
  category: search
---

# 元宝搜索检索内核（Yuanbao Search）

## 概述

本技能把政策线索的取数通道从"抓取搜索引擎结果页"换成**结构化检索 API**（元宝搜索 `wsa` / `SearchPro`），
并在返回前完成**可信度四因子标注**与**政策原文库交叉验证**。

三条硬行为（本技能的立身之本）：

1. **不编造**：检索不到的字段留空，绝不用推测值填充。
2. **敢说不知道**：未绑定 `policy_no` 的结论一律置「待核实」，**不进入正式报告**，而是列进 `excluded[]` 并说明原因。
3. **可溯源**：每条结论必带 `url`，命中原文库的额外带政策原文路径，来源必须点得开。

## 脚本运行说明

TypeScript 与 Python 双版本，**优先 TypeScript**（零 npm 依赖）。

- **TypeScript 版本（推荐）**：`scripts/yuanbao_search.ts`
  - 运行：`node --experimental-strip-types scripts/yuanbao_search.ts --query "…" [选项]`
  - 依赖：Node.js ≥22.6（推荐 v23.10+，内置 fetch）
- **Python 版本（降级备选）**：`scripts/yuanbao_search.py`
  - 运行：`python scripts/yuanbao_search.py --query "…" [选项]`（同签名，仅标准库）
  - 仅在 TypeScript 版本运行出错时降级使用

出网复用 `skills/http-client/scripts/http_client.ts`（`<method> <url> [json_body] [headers_json]`），
本技能**只负责生成签名头**，不重写 HTTP 客户端；该通道不可用时自动回退内置 fetch（stderr 会说明实际通道）。

## 可用工具

### yuanbao_search

执行一次结构化检索并输出带可信度标签的结果。

**参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `query` | string | 是 | 检索词，长度 ≤200 字符，为空直接报错退出 |
| `industry` | string | 否 | 垂直领域：`gov`（默认，政策场景）/ `news` / `acad` / `finance` |
| `freshness` | string | 否 | 时效窗：`d1~d30` / `m1~m12` / `y1~y5` / `YYYY-MM-DD` / `YYYY-MM-DD,YYYY-MM-DD`；兼容友好写法 `1d` `1w`(=d7) `1m` `1y` 与 `A..B` |
| `site` | string | 否 | 限定单个域名，如 `bjchy.gov.cn` |
| `exclude` | string | 否 | 排除域名，`\|` 分隔，最多 5 个；与 `site` 互斥 |
| `cnt` | int | 否 | 结果条数，收敛到 `{10,20,30,40,50}`，默认 50 |
| `deeplinks` | flag | 否 | 返回附件子链（仅旗舰版生效，缺失不视为错误） |
| `selftest` | flag | 否 | 自检：只验证连通性与服务档位，不跑完整闭环 |
| `json` | flag | 否 | 显式要求单行 JSON 输出（默认即为单行 JSON） |
| `env-file` | string | 否 | 指定 `.env` 路径，默认 `<runtime>/.env` |
| `kb` | string | 否 | 政策原文库索引路径，默认 `../beichen-policy-assistant/knowledge/policy-index.json` |
| `no-kb` | flag | 否 | 跳过原文库交叉验证（此时所有结论置「待核实」） |

**运行示例：**

```bash
node --experimental-strip-types scripts/yuanbao_search.ts \
  --query "专精特新 中小企业 申报 条件" \
  --industry gov --cnt 50 --freshness 1y --json

node --experimental-strip-types scripts/yuanbao_search.ts --selftest
```

## 输出

stdout **单行 JSON**（诊断与进度一律走 stderr）：

```json
{
  "ok": true,
  "requestId": "...",
  "version": "flagship",
  "elapsedMs": 668,
  "degraded": false,
  "items": [
    {
      "title": "...", "url": "https://...", "site": "...", "date": "2026-09-12",
      "passage": "...", "scoreNorm": 0.82, "authorityLevel": 4,
      "credibility": {
        "authority": "高", "sourceTier": "最高", "freshness": "现行有效",
        "kbHit": "已命中", "policyNo": "12", "status": "可采信", "level": "高",
        "reason": "权威度=4(高)；信源=最高(...gov.cn)；时效=现行有效；原文库=已命中(policy_no=12)"
      }
    }
  ],
  "excluded": [ { "title": "...", "status": "待核实", "reason": "原文库未命中" } ]
}
```

`excluded[]` 是"敢说不知道"的对外可见证据——未命中项不会被丢弃，而是被明确列出并说明原因。

## 可信度判定规则（四因子档位降级链）

| 因子 | 取值 | 判定 |
|---|---|---|
| 权威度 | 高 / 中 / 低 / 不可用 | `authority_level ≥4` 高、`=3` 中、`≤2` 低、字段缺失为不可用 |
| 信源分级 | 最高 / 中间 / 最低 | `.gov.cn` 或政府序列 → 最高；已知门户/机构 → 中间；`site` 空或未知 → 最低 |
| 时效 | 现行有效 / 已过期 / 未知 | 落在时效窗内 → 现行有效；早于 → 已过期；`date` 缺失 → 未知 |
| 原文库命中 | 已命中 / 未命中 / 库不可用 | 三级证据：标题 Jaccard ≥0.6 / 核心名重叠系数 ≥0.75 / 正文出现政策全名 |

合成：`base` 由信源分级定 → 时效非「现行有效」降一档 → 权威度低或不可用降一档。

**结论状态 = 可核验出处门禁（2026-10-25 修订）**：

> 敢说不知道 = **拿不出可核验出处时说不知道**，而不是"本地库里没有就说不知道"。
> 官方发布页（.gov.cn 等）URL 点得开、发布日期看得见，本身就是可核验出处。

置「待核实」的三条硬门禁：

1. 信源分级 = 最低（未知站点 / 自媒体，无法核验发布主体）；
2. 时效 = 已过期（过期政策不作申报依据）；
3. 原文库不可用 **且** 信源非政府（失去事实底座，又不是官方一手来源）。

其余情况可采信。原文库命中是**加分项**：绑定 `policy_no` 与原文路径；未命中则标注
「未在本地政策原文库备案，需人工复核」，仍可采信。

`score` 只在**批次内**做 min-max 归一化后使用，**不跨批次比较、不写死阈值**（实测跨度 0.75~5.46）。

## 错误处理与降级策略

| 错误 | 处置 |
|---|---|
| `RequestLimitExceeded` | 指数退避重试至多 2 次 → 仍失败则降级 |
| `AuthFailure` / `UnauthorizedOperation` | 不重试，提示"凭据无效"，**不回显服务端原始消息** |
| 资源未开通类 | 不重试，给出开通排查指引 |
| 响应结构异常 / 空集 | 按空结果处理并告警，**不抛异常中断调用方** |
| 网络超时（5s） | 退避重试 → 降级到 `http_request` + `multi-search-engine` 抓取通道，结果标 `degraded: true` |

双通道均失败时返回空集 + 告警，流程不中断。

## 闭环流程（与 beichen-policy-assistant 串联）

```
Step 0  自检：yuanbao_search.ts --selftest
Step 1  画像：build_enterprise_profile.ts --company "X"
Step 2  检索：yuanbao_search.ts --query "<画像关键词>" --industry gov --cnt 50 --freshness 1y
Step 3  可信度：四因子合成 + 交叉验证 → 绑定 policy_no / 待核实分流（本技能完成）
Step 4  匹配：match_policy.ts --profile {画像} --topn 10
Step 5  报告：generate_policy_report.ts --profile {画像} --matches {匹配}
Step 6  落库：save_to_db.ts --profile {} --report {} --matches {} [--sql-only]
Step 7  巡检：update_policy_kb.ts --sources yuanbao --freshness 7d
Step 8  研判：update_policy_kb.ts --commit --date <日期> --reviewer <人>（缺 reviewer 拒绝）
```

聚合、限速与重试策略沿用 `skills/multi-search-engine/SKILL.md` 的既有约定（cookie 被拒时动态获取、
403/429 换新 cookie、失败延迟后重试一次）。

## 合规与边界

- 仅做**客观政策的检索与条件比对**，不做政策解读或倾向性评价。
- 报告必须附"仅供申报参考，不构成法律意见"。
- 政策原文库为**北京地区 74 条**政策，报告必须明示适用范围，不得让用户误认为全国通用。
- 凭据只从 `.env` 读取，不进产物、日志、异常堆栈与进程参数。
