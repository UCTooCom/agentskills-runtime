---
name: yuanbao-policy
description: >
  L3 进程隔离轨插件（yuanbao-policy）—— 把元宝搜索（腾讯云 wsa · SearchPro）检索内核
  编译成独立可执行文件，输出带可信度四因子标签与政策原文库交叉验证的结构化线索。
  触发场景：需要以「不暴露脚本源码」的方式交付政策检索能力；宿主要求以进程插件形式
  提供检索服务；脚本轨（skills/yuanbao-search）不可用时作为同规则降级通道。
  与 skills/yuanbao-search 共用同一套判定规则与输出形态，可互为降级。
license: MIT
plugin: yuanbao-policy
metadata:
  author: UCToo Team
  version: "1.0.0"
  category: search
  track: l3-process
---

# yuanbao-policy 插件（L3 进程隔离轨·检索内核）

## 概述

本插件是 `skills/yuanbao-search` 脚本轨的**编译态孪生兄弟**：同一套检索内核、同一套可信度
四因子规则、同一套「敢说不知道」门禁，差别只在于**载体**——

| | 脚本轨 `yuanbao-search` | 插件轨 `yuanbao-policy` |
|---|---|---|
| 载体 | TypeScript / Python 明文脚本 | 编译产物 `skill_yuanbao_policy.exe` |
| 分发 | 源码必须可见 | **删掉 `src/` 照样跑**（REQ-PD-042） |
| 时效判定 | 精确到日 | 按发布年份近似（见「已知差异」） |
| 参数 | 全参数 | 子集：`query` / `industry` / `cnt` / `freshness` |
| 通道 | `http_client.ts` 子进程 → 内置 fetch | 内置 `curl` 子进程 |

三条硬行为与脚本轨完全一致（本技能的立身之本）：

1. **不编造**：检索不到的字段留空，绝不用推测值填充。
2. **敢说不知道**：过不了门禁的结论一律置「待核实」，**不进入正式报告**，而是列进
   `excluded[]` 并逐条说明原因。
3. **可溯源**：每条结论必带 `url`，命中原文库的额外带 `policy_no` 与原文路径。

## 能力契约

- **handler key**：`yuanbao-policy`（宿主 `invoke` 转发时 `service="yuanbao-policy"`）
- **协议**：JSON-RPC over stdio（NewlineFraming 逐行解析）
- **入参**：`args[0]` 为单个对象，用 `action` 分派；缺省 `action` 视为 `search`
- **诊断**：一律 `eprintln` 走 **stderr**。stdout 是协议通道，写它就是破坏协议（G8）

### action = `search`

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `action` | string | 否 | 固定 `search`；缺省亦走检索 |
| `query` | string | 是 | 检索词，长度 ≤200 字符，为空直接返回 `ok=false` |
| `industry` | string | 否 | 垂直领域，默认 `gov` |
| `cnt` | number | 否 | 结果条数，收敛到 `{10,20,30,40,50}`，默认 50 |
| `freshness` | string | 否 | 时效窗：`y<n>` / `m<n>` / `d<n>`；不传按 1 年兜底 |

> **能力边界（诚实标注）**：本轨暂不支持 `site` / `exclude` / `deeplinks`。
> 需要限定或排除域名时请走脚本轨 `yuanbao-search`。

### action = `selftest`

只验证连通性、服务档位与原文库可用性，用固定检索词「政策 申报」跑 10 条，不跑完整闭环。

## 输出

### search 成功

```json
{
  "ok": true,
  "requestId": "...",
  "version": "flagship",
  "elapsedMs": 668,
  "degraded": false,
  "query": "专精特新 中小企业 申报 条件",
  "track": "l3-process",
  "kb": true,
  "kbCount": 74,
  "returned": 30,
  "credible": 20,
  "excludedCount": 10,
  "items": [
    {
      "title": "...", "url": "https://...", "site": "...", "date": "2026-09-12",
      "passage": "...", "status": "可采信", "scoreNorm": 0.82, "authorityLevel": 4,
      "policyNo": "48",
      "credibility": {
        "authority": "高", "sourceTier": "最高", "freshness": "现行有效",
        "kbHit": "已命中", "policyNo": "48",
        "policyFile": "knowledge/policies/48-北京市高精尖产业发展项目资金管理办法.md",
        "status": "可采信", "level": "高",
        "reason": "权威度=4(高)；信源=最高(...gov.cn)；时效=现行有效；原文库=已命中(policy_no=48)"
      }
    }
  ],
  "excluded": [ { "title": "...", "status": "待核实", "credibility": { "reason": "…" } } ]
}
```

`excluded[]` 是「敢说不知道」的对外可见证据——过不了门禁的条目不会被丢弃，而是明确列出并说明原因。

`scoreNorm` / `authorityLevel` / `vr` / `policyNo` 为**存在才写入**的可选字段：
服务档位未提供 `score` / `authority_level` 时不会凭空造数。

### selftest 成功

```json
{ "ok": true, "status": "200", "version": "flagship", "requestId": "...",
  "pages": 10, "elapsedMs": 1300, "kb": true, "kbCount": 74, "track": "l3-process" }
```

### 失败（统一形态，不抛异常）

```json
{ "ok": false, "degraded": true, "error": "…", "items": [], "excluded": [] }
```

失败一律返回空集 + 原因，**不中断调用方**。典型 `error`：
`query 为必填项` / `query 长度超过 200 字符` /
`未配置云 API 密钥（QCLOUD_COS_SECRET_ID / QCLOUD_COS_SECRET_KEY）` /
`API <Code>（不回显服务端原始消息）` / `响应结构异常，按空结果处理` / `检索通道不可用（HTTP …），已按降级处理`。

## 可信度判定规则（四因子档位降级链）

与脚本轨**逐条对齐**（design §2.5.5、tasks T-06/T-07）：

| 因子 | 取值 | 判定 |
|---|---|---|
| 权威度 | 高 / 中 / 低 / 不可用 | `authority_level ≥4` 高、`≥3` 中、其余低、字段缺失为不可用 |
| 信源分级 | 最高 / 中间 / 最低 | `.gov.cn` 等政府序列 → 最高；已知门户/机构 → 中间；`site` 空或未知 → 最低 |
| 时效 | 现行有效 / 已过期 / 未知 | 见「已知差异」：本轨按年份近似 |
| 原文库命中 | 已命中 / 未命中 / 库不可用 | 三级证据：标题 Jaccard ≥0.6 / 核心名重叠 ≥0.75 / 正文出现政策全名 |

合成：`base` 由信源分级定 → 时效非「现行有效」降一档 → 权威度低或不可用降一档。

**结论状态 = 可核验出处门禁（v1.1）**：

> 敢说不知道 = **拿不出可核验出处时说不知道**，而不是「本地库里没有就说不知道」。
> 官方发布页（.gov.cn 等）URL 点得开、发布日期看得见，本身就是可核验出处。

置「待核实」的三条硬门禁：

1. 信源分级 = 最低（未知站点 / 自媒体，无法核验发布主体）；
2. 时效 = 已过期（过期政策不作申报依据）；
3. 原文库不可用 **且** 信源非政府（失去事实底座，又不是官方一手来源）。

其余情况可采信。原文库命中是**加分项**：绑定 `policy_no` 与原文路径；未命中则标注
「未在本地政策原文库备案，需人工复核」，仍可采信。

`score` 只在**批次内**做 min-max 归一化后使用，**不跨批次比较、不写死阈值**（实测跨度 0.75~5.46）。

## 已知差异（插件轨 vs 脚本轨）

| 项 | 插件轨行为 | 影响 |
|---|---|---|
| 时效判定 | 从 `date` 取年份，`nowYear - year > windowYears` 判过期（`windowYears = days/365 + 1`） | 精度到年，比脚本轨保守宽松；不做更细判定是因为 L3 轨不依赖外部日期库 |
| 参数子集 | 不支持 `site` / `exclude` / `deeplinks` | 需限定域名时走脚本轨 |
| 出网 | 写临时请求文件后 `curl --data-binary @file` | 依赖系统 `curl.exe`，缺失则 `检索通道不可用` |
| 原文库定位 | 依次尝试 5 个相对路径（`./skills/beichen-policy-assistant/knowledge/policy-index.json` 起，逐级 `../`） | 进程工作目录由宿主决定；全部失败则 `kb=false`，按门禁第 3 条处理 |

## 闭源分发（本插件的独有能力）

分发目录只需三样东西，**不需要 `src/`**：

```
yuanbao-policy/
├── plugin.yaml                                   # mode: process / enabled: true
├── SKILL.md                                      # 本文件
└── target/release/bin/skill_yuanbao_policy.exe   # 编译产物 + 同目录 DLL
```

脚本型技能做不到这一点：JS / Python 必须以明文源码分发。对照演示见 T-24。

> ⚠️ exe 依赖的 DLL 必须一并分发（SDK std / libs stdx / 依赖包 / OpenSSL 四路），
> 缺一路是加载期 `0xC0000135` 秒退、**一行日志都没有**，需按既有做法补齐到 exe 同目录。

## 错误处理与降级

| 情况 | 处置 |
|---|---|
| `RequestLimitExceeded` 等限流 | 指数退避重试至多 2 次 → 仍失败则 `degraded: true` |
| `AuthFailure` / `UnauthorizedOperation` | 不重试，**不回显服务端原始消息** |
| 响应结构异常 / 空集 | 按空结果处理并 `eprintln` 告警，返回 `ok=false` 但不中断 |
| `Pages` 元素解析失败 / `url` 缺失 | 该条丢弃并计数（`丢弃 N 条无效结果`），其余照常返回 |
| `Version=standard` / `authority_level` 整批缺失 | 记降级事件并继续，不抛异常 |
| 插件不可用 | 宿主回退脚本轨 `yuanbao-search`（同规则、同输出形态） |

## 合规与边界

- 仅做**客观政策的检索与条件比对**，不做政策解读或倾向性评价。
- 报告必须附「仅供申报参考，不构成法律意见」。
- 政策原文库为**北京地区 74 条**政策，报告必须明示适用范围，不得让用户误认为全国通用。
- 凭据只从 `.env` 读取（`QCLOUD_COS_SECRET_ID` / `QCLOUD_COS_SECRET_KEY`），
  不进产物、日志、异常堆栈与进程参数。
- 内容禁区：不涉时政评论与特定个人。

## 编译与运行

```bash
cd skills/yuanbao-policy
cjpm build                                     # 产物 target/release/bin/skill_yuanbao_policy.exe
```

宿主启动后按 `plugin.yaml` 自动注册（`mode: process`、`autoRestart: true`、`order: 20`）。
诊断日志以 `[yuanbao-policy]` / `[skill_yuanbao_policy]` 前缀走 stderr。
