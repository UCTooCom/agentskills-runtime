---
name: web-search-assistant
description: 多引擎网页搜索助理（Web Search Assistant）—— 直接调用运行时自带 web_fetch / http_request 工具抓取 16 个搜索引擎（7 国内 + 9 国际）的结果页，无需 API Key。采用"按需 cookie 刷新 + 限流 + 单次重试 + 结果聚合"的健壮工作流，避免旧版脚本因百度/搜狗 CSS 选择器失效而返回空结果、浪费推理步数。触发词："搜索"、"search"、"查新闻"、"查公告"、"查资讯"、"百度搜索"、"搜狗搜索"、"web fetch"。
license: MIT
metadata:
  author: UCToo Team
  version: "2.0.0"
  category: fintech
  tags: ["fintech", "search", "baidu", "bing", "google", "duckduckgo", "news", "公告", "资讯"]
allowed-tools: network, filesystem, cli
---

# 多引擎网页搜索助理（Web Search Assistant）v2.0

## 概述

本技能封装 16 个搜索引擎（7 国内 + 9 国际），为 Agent 提供**稳定、无需 API Key** 的网页信息检索能力。

**v2.0 核心改进（修复"浪费推理步数"问题）：**
- v1.0 依赖 `scripts/search.py` 用 BeautifulSoup 硬编码解析百度/搜狗结果页的 CSS 选择器（`div.result`、`div.c-container`、`.c-abstract` 等）。这些类名会被搜索引擎频繁轮换，且 `https://www.baidu.com/s` 无 `BAIDUID` cookie 时返回验证码/空白页，导致脚本**静默返回 0 条结果**，Agent 反复重试、空耗步数。另百度结果 `href` 是 `http://www.baidu.com/link?url=...` 重定向，脚本抓到的是重定向地址而非真实 URL。
- v2.0 **不再使用任何本地 HTML 解析脚本**。改为直接调用运行时自带的 `web_fetch` / `http_request` 工具抓取各引擎搜索 URL，由 Agent 自身从返回页提取标题/摘要/链接，并配套"限流 + 按需 cookie 刷新 + 单次重试 + 结果聚合"工作流，从根上消除空结果重试。

> ⚠️ **禁止**调用 `scripts/` 下的旧版抓取脚本（`search.py`、`fetch_ai_market*.py` 等）。它们依赖已失效的百度/搜狗 CSS 选择器，会返回空结果。一律使用下方 `web_fetch` 工作流。

## 全流程 SOP

```
┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐
│ 1.选引擎 │ → │ 2.限流抓 │ → │ 3.失败刷新│ → │ 4.单次重试│ → │ 5.聚合输出│
│ select  │   │ fetch   │   │ cookie  │   │ retry   │   │ aggregate│
└─────────┘   └─────────┘   └─────────┘   └─────────┘   └─────────┘
```

### Step 1：选引擎（按查询语言）
- 查询含中文 → 国内引擎：百度、必应中国、360、搜狗（含微信）、神马。
- 查询为英文/无中文 → 国际引擎：Google、DuckDuckGo、Bing INT、Yahoo、Startpage、Brave、Ecosia、Qwant、WolframAlpha。
- 通常并行 1~3 个引擎即可，不必全上。

### Step 2：限流抓取
调用运行时工具直接抓取搜索 URL（详见下方"搜索引擎 URL 表"），遵循：
- 每次请求间隔 **1~2 秒**，尊重目标站点负载。
- 单批最多 3~4 个引擎，批次间顺序执行。
- 带上标准浏览器请求头（`User-Agent`、`Accept-Language: zh-CN,zh;q=0.9`）。

调用示例（语法以运行时实际工具为准，此处以 `web_fetch` 为例）：
```javascript
web_fetch({"url": "https://www.baidu.com/s?wd=贵州茅台 最新新闻"})
web_fetch({"url": "https://cn.bing.com/search?q=贵州茅台&ensearch=0"})
web_fetch({"url": "https://www.google.com/search?q=Kweichow+Moutai+news&tbs=qdr:w"})
```

### Step 3：失败刷新 cookie（按需，仅内存）
- 若返回 **403 / 429 / 反爬验证页**（页面里出现"请输入验证码"、"访问过于频繁"等），先 `web_fetch` 一次该引擎首页（`https://www.baidu.com/`、`https://www.google.com/`）以获取会话 cookie，再继续。
- cookie **仅保存在内存**，搜索会话结束即清除，**不写盘、不读配置文件**。

### Step 4：单次重试
- 若某引擎因 cookie/会话问题失败，等待 2 秒后用新 cookie 重试**一次**；仍失败则跳过该引擎，不要无限重试。

### Step 5：聚合输出
- 把各引擎返回页中成功提取的结果（标题、摘要、真实 URL、来源引擎）汇总。
- 百度/搜狗结果里的 `http://www.baidu.com/link?url=...`、`http://www.sogou.com/link?...` 是**重定向地址**，需 `web_fetch` 跟进一次拿到 `Location`/最终落地页，或直接以该跳转链接作为 `url` 字段（由后续工具处理）。**不要**把裸重定向链接当成最终内容源。
- 输出结构化结果给 Agent 消费，格式：
```json
{
  "success": true,
  "query": "贵州茅台 最新新闻",
  "count": 8,
  "results": [
    {"title": "...", "snippet": "...", "url": "https://...", "source": "baidu"}
  ]
}
```

## 搜索引擎 URL 表

### 国内（7）
| 引擎 | 搜索 URL |
|------|----------|
| 百度 | `https://www.baidu.com/s?wd={keyword}` |
| 必应中国 | `https://cn.bing.com/search?q={keyword}&ensearch=0` |
| 必应国际 | `https://cn.bing.com/search?q={keyword}&ensearch=1` |
| 360 | `https://www.so.com/s?q={keyword}` |
| 搜狗（网页） | `https://sogou.com/web?query={keyword}` |
| 搜狗（微信） | `https://wx.sogou.com/weixin?type=2&query={keyword}` |
| 神马 | `https://m.sm.cn/s?q={keyword}` |

### 国际（9）
| 引擎 | 搜索 URL |
|------|----------|
| Google | `https://www.google.com/search?q={keyword}` |
| Google HK | `https://www.google.com.hk/search?q={keyword}` |
| DuckDuckGo | `https://duckduckgo.com/html/?q={keyword}` |
| Yahoo | `https://search.yahoo.com/search?p={keyword}` |
| Startpage | `https://www.startpage.com/sp/search?query={keyword}` |
| Brave | `https://search.brave.com/search?q={keyword}` |
| Ecosia | `https://www.ecosia.org/search?q={keyword}` |
| Qwant | `https://www.qwant.com/?q={keyword}` |
| WolframAlpha | `https://www.wolframalpha.com/input?i={keyword}` |

## 常用搜索语法（直接拼进 URL 的 `q` / `wd` 参数）
- 站内：`site:github.com python`
- 文件类型：`filetype:pdf 年报`
- 精确匹配：`"machine learning"`
- 排除：`python -snake`
- 时间筛选（Google）：`&tbs=qdr:w`（周）/ `qdr:m`（月）/ `qdr:y`（年）
- DuckDuckGo Bang：`https://duckduckgo.com/html/?q=!gh+tensorflow`（跳转 GitHub）

## 复用产品体系能力
| 能力 | 复用方式 |
|------|---------|
| 内置工具 `web_fetch` / `http_request` | 直接抓取上表搜索 URL（**主路径，替代旧脚本**） |
| 内置工具 `cli_execute` / `python_execute` | 仅用于把聚合结果落库或做轻量后处理（非抓取） |
| `output/` 目录结构 | 与投研技能共享输出目录（可选落库） |

## 健壮性准则（务必遵守，避免空耗步数）
1. **绝不为空结果反复重试同一引擎**——若返回 0 条，先按 Step 3 刷新 cookie 重试一次，仍空则换引擎。
2. **不解析 HTML 选择器**——由 Agent 直接从 `web_fetch` 返回文本抽取，避免选择器失效。
3. **尊重 `robots.txt` 与限流**，单请求间隔 ≥1s。
4. **cookie 不落盘**，会话结束清除。

## 安全与合规
- 仅抓取公开搜索结果页的摘要与链接，不绕过反爬、不抓付费/登录内容。
- 记录搜索关键词、时间、来源引擎（合规留痕）。
- 优先国产引擎以满足信创合规；抓取个人隐私数据、伪造来源均严禁。

## 严禁事项
- 严禁调用 `scripts/search.py` 等旧版 HTML 抓取脚本（已失效）。
- 严禁伪造搜索结果来源、抓取个人隐私数据、绕过反爬机制。

## 参考文档
- 业界成熟实现参考：SkillHub `zcwl/multi-search-engine`（v2.1.x，16 引擎，无需 API Key）。
- 内置工具：`docs/builtin-tools.md`。
- 投研技能：`skills/investment-research-assistant/SKILL.md`。
