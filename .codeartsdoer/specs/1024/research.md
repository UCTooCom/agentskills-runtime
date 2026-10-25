# 1024 超能 Coding 周末｜侦探赛道（对接元宝搜索）研究文档 v2

> 产出：SDD 流程第 1 步（research），子 agent `sdd-researcher`
> 模板：`skills/sdd/templates/research-template.md`
> 输出目录：用户显式指定 `.codeartsdoer/specs/1024/`（sdd README「用户显式指定输出目录时以用户为准」）
>
> **v2 更新依据（本轮三项新输入）**
> 1. 套餐已由极速版升级为**标准版** —— 已用真实密钥实测 15 次确认（见 §2.5 实测矩阵）
> 2. 提供腾讯云官方 SDK 两份可参照 —— `tencentcloud/wsa/v20250508/`（Node / Python）
> 3. L3 进程隔离轨插件**可独立编译**，不占关键路径 —— 已核实仓库内 7 个技能已在用该形态
>
> **⚠ 版本状态更新（v2 之后，本文档已被后续实测部分覆盖）**
> 本文档成文后，账号**再次升级为旗舰版**。经 26 次补充实测，以下 v2 结论需以 `spec.md` 为准：
> - **`Version` 不再恒定**：同一 payload 重复 8 次出现 7 次 `flagship` / 1 次 `standard`，
>   故 `Version` 只能作观测指标，**禁止**用作能力开关。
> - **`authority_level` 已可获得，但非必然**：仅在 flagship 路由下返回，实测值域 **2~4**，
>   该批次内 30/30 条全返回；standard 路由下 0 条返回。⇒ 必须保留降级路径。
> - **`score` 量纲进一步复杂化**：由 `Industry` **与 `Version` 共同**决定，实测跨度 **0.75 ~ 5.46**
>   （无垂直领域 0.75~0.79；`gov`+flagship 5.23~5.46；`finance`+standard 3.16~4.18 等）。
>   ⇒ v2 §5.1「仅同批次排序、禁止写死阈值」的结论不变且更强。
> - **`Mode=1` 在旗舰版下仅召回 1 条**（标准版为 0 条），仍禁止作为主召回通道。
> - 新增字段 **`vr`**（布尔，标记优质权威垂直信源）；`Deeplinks=true` 在旗舰版下生效。
> 详见同目录 `spec.md` §2 领域术语与 §4.5 兼容性。
>
> 取证方式：仓库源码/技能清单实测 grep + 元宝搜索 API **真实调用 15 次** + 官方 SDK 源码精读 + L3 插件工程结构核实。本文所有 API 行为结论均来自实测输出或 SDK 源码，非文档推断。

---

# 用户原始需求

`req.md` 原文（`.codeartsdoer/specs/1024/req.md`）：

> 赛事信息 https://waytoagi.feishu.cn/wiki/Ht49w6i3kipT0Vk61H3cmUxtnJg
> 我们参加的是 侦探｜查得到，信得过 赛道，也就是对接元宝搜索（侦探赛道），这是元宝搜索对接文档 https://cloud.tencent.com/document/product/1806/121811
> API的key和secret和 D:\UCT\projects\uctoo\apps\agentskills-runtime\.env 配置文件的QCLOUD_COS_SECRET_ID 和QCLOUD_COS_SECRET_KEY是一样的。
> 我们之前在D:\UCT\projects\uctoo\apps\agentskills-runtime\skills 中的一些技能已经使用了我们内置的网络搜索技能，但是效果不好，可以替换成元宝搜索看看效果。

**本轮新增需求（用户补充，原文要点）**：

> - 已将元宝**极速版**升级为**标准版**套餐；
> - 已下载官方 SDK 两份供参考：`D:\UCT\products\gitee\tencentcloud-sdk-nodejs`、`D:\UCT\products\gitee\tencentcloud-sdk-python`，元宝路径 `tencentcloud/wsa/v20250508/wsa_client.py`；
> - agentskills-runtime 的 **L3 轨插件是可单独编译的进程隔离轨插件，编译速度非常快，不会影响进度**；
> - 求**夺冠创意建议**；
> - 是否可复用 `skills/beichen-policy-assistant`（1024 活动参与者多为创业者，关心政策自动化：收集/筛选匹配/申报/跟进）；
> - L3 进程隔离插件为**业界首创**，具备**闭源发布技能插件**能力，论据见 `docs/ref/plugin-mechanism-comparison.html`。

- **目标**：以元宝搜索（标准版）替换效果不佳的「内置网络搜索」，并以此为内核产出「侦探｜查得到，信得过」赛道作品。
- **范围（In Scope）**：
  1. 元宝搜索对接能力在仓库内可复用（脚本轨 + L3 进程隔离轨）；
  2. 既有用网技能改造为优先走元宝搜索；
  3. 「信得过」能力工程化（可信度可评估、可追溯、可审计）；
  4. 复用 `beichen-policy-assistant` 构建面向创业者的政策自动化闭环；
  5. 形成可支撑夺冠叙事的差异化设计。
- **非范围（Out of Scope）**：
  - 不改动宿主（`src/`）既有工具链与插件内核；
  - 不做计费、多租户、配额运营等产品化；
  - 不重写与搜索/政策无关的技能。
- **关键约束**：
  - **时间极紧**：赛程 2026-10-24（六）—25（日）。**作品提交 10/25 16:00 截止**（15:00 封板，15:00—16:00 提交窗口）；侦探赛道社媒分享链接可补填至 10/25 23:59，作品本体不延后。
    （注：本条已从选手手册核准，此前流传的"19:02 结束"为误记。）
  - 凭据复用 `.env` 的 `QCLOUD_COS_SECRET_ID` / `QCLOUD_COS_SECRET_KEY`。
  - 工程红线：**AI 不执行 `cjpm build`**，编译由人工执行 —— 但用户已澄清 **L3 插件为独立工程、编译快**，故 L3 轨已**回到可选关键路径内**（见 §4.1）。

---

# 研究结果

## 一、现状与定位

### 1.1 与既有相关工程的关系

| 对象 | 现状 | 本次关系 |
|---|---|---|
| `skills/multi-search-engine` | 已落地 v2.1.3，**无 `plugin.yaml`**（纯提示词/脚本型技能）。内核是抓 16 个搜索引擎的 SERP（`SKILL.md:53-70`） | **替换主体**：把"抓 SERP"内核换成"调元宝搜索 API" |
| `skills/web-search-assistant` | 已落地，偏"AI 市场报告"场景，无 `plugin.yaml` | 次级替换对象 |
| `skills/http-client` | 通用 HTTP 客户端，TS/Python 双版本，零 npm 依赖（`SKILL.md:14-27`） | **直接复用**（取数通道），不解决签名 |
| `skills/beichen-policy-assistant` | **已落地完整 SOP + 74 条政策原文三层知识库**（详见 §2.6） | **本次作品的业务载体**（用户点名复用） |
| `src/tool/web_tools.cj` / `http_tool.cj` | 宿主内置 `web_fetch`（`web_tools.cj:35`）、`http_request`（`http_tool.cj:19`）已实现并登记权限 | 保留；L3 插件侧可用宿主 DB/HTTP 服务 |

### 1.2 本质区别（决定不能简单复用）

**关键实测发现：宿主并不存在 `web_search` 这个工具。**

`src/tool/tool_permission.cj` 登记的内置工具共 23 个（已去重排序）：

```
browser_open, cli_execute, code_snippet_generator, directory_create, directory_list,
file_copy, file_delete, file_edit, file_move, file_read, file_search, file_write,
firecrawl, http_request, python_execute, skill_initializer, skill_install,
skill_packager, skill_search, skill_validate, template_engine, web_fetch
```

其中**没有 `web_search`**，且 `src/` 全量 grep `web_search|webSearch` **零命中**。

然而多个技能在 SKILL.md 里声明依赖 `web_search`：

- `skills/beichen-policy-assistant/SKILL.md:6`：声明需要 `web_search`
- `skills/beichen-policy-assistant/SKILL.md:162`：**工商接口不可用**：画像降级为 `web_search` 采集 + 该字段留空并做标记
- `skills/beichen-policy-assistant/SKILL.md:166`：`cli_execute` stdout 编码失败时按"遇挫不停"原则换 `web_search` / `web_fetch` 采集

**结论（"效果不好"的根因，非猜测）**：
仓库里所谓"内置网络搜索"，实际是**用 `web_fetch` 去抓搜索引擎结果页 HTML**（`multi-search-engine/SKILL.md:33` 明写 "Use web_fetch to execute search requests"，配套"1-2 秒限速 / 3-4 个引擎分批 / 403-429 时抓首页换 cookie"）。这是 **HTML 抓取式搜索**，天然不稳定：反爬、cookie 会话、HTML 结构一变即失效。

而元宝搜索是**结构化 JSON 检索 API**。**二者不是同一层的东西，不能"改改配置"复用，必须换内核。**

> 附带的真实 Bug：`beichen-policy-assistant` 的**两条降级路径都指向一个不存在的工具**，也就是说这两条兜底链路自建成起就是死的。本次替换等于顺带修好它 —— 这是一个可以写进叙事的真实改进点。

### 1.3 本轮三项新输入的定性结论

| 新输入 | 定性结论 | 证据 |
|---|---|---|
| 升级标准版 | **有效，`Version` 已返回 `standard`**；`Cnt`/`Industry`/`score`/`content`/`pics` 全部解锁 | 实测 15 次，见 §2.5 |
| 官方 SDK 两份 | **权威字段矩阵来源**，且**只暴露 `SearchPro` 一个 Action**；`Mode=1` 与 `authority_level`/`deeplinks` 属旗舰版 | `wsa_client.py:29`、 `models.py:152-164` |
| L3 插件可独立编译 | **属实且已是仓库主流形态**：11 个带 `plugin.yaml` 的技能中 **7 个为 `mode: process`**，各有独立 `cjpm.toml`（`output-type = "executable"`） | `skills/github/cjpm.toml`、`skills/github/plugin.yaml` |

---

## 二、已有可复用基础设施盘点

> 仅列与本次强相关项，每条给出「路径 + 能复用什么 + 复用方式」。

### 2.1 凭据与配置读取
- `src/app/services/uctoo/CosConfig.cj:18-39`：`getSecretId()` 读 `AppConfig.env["QCLOUD_COS_SECRET_ID"]`、`getSecretKey()` 读 `AppConfig.env["QCLOUD_COS_SECRET_KEY"]`。
  → **直接复用**：仓颉侧（L3 插件）原样调用 `CosConfig`；脚本侧自行读 `.env` 同名键（本次 15 次实测即用此方式）。
- `.env:265-266`：`QCLOUD_COS_SECRET_ID=AKID…`（已是腾讯云 API 密钥 `AKID` 格式，与云 API 3.0 鉴权要求一致）。

### 2.2 取数通道
- `skills/http-client/scripts/http_client.ts`（+ `.py`）：零 npm 包，`headers` 透传已满足鉴权头需求（`SKILL.md:36-41`）。
- 宿主内置 `http_request`（`src/tool/http_tool.cj:19`）、`web_fetch`（`src/tool/web_tools.cj:35`）保留为兜底与正文深挖。

### 2.3 签名所需的密码学能力
- **仓颉侧**：`std.crypto.digest` / `stdx.crypto.digest` 明确提供 **HMAC**、SHA256、SM3；实战例 `src/scripts/package_release/main.cj:46-50` 已用 `stdx.crypto.digest.SHA256`；`stdx.encoding.hex` 可做十六进制编码。
  → **TC3-HMAC-SHA256 在仓颉侧可自实现，无需新依赖**（这是 L3 插件轨可行的技术前提）。
- **脚本侧**：Node 内置 `node:crypto` 的 `createHmac('sha256', key)`，**零依赖** —— 15 次实测全部成功。

### 2.4 技能/插件形态与注册（本轮重点更新）

- 技能目录共 51 个；**带 `plugin.yaml` 的 11 个**，其中 **7 个为 `mode: process`（L3 进程隔离轨）**：
  `codelabs`、`due_diligence_agent`、`github`、`llm_channel_tokendance`、`long-running-task`、`sdd`、`sheets`；
  其余 4 个为 `mode: sync`：`doc-helper`、`entity`、`feedback`、`hello`。
- `multi-search-engine`、`web-search-assistant`、`http-client`、`beichen-policy-assistant` **均无 `plugin.yaml`**，靠 `SKILL.md` frontmatter 生效 —— **无需编译、改完即生效**。
- **L3 插件工程结构（以 `skills/github` 为范本，已核实）**：

```
skills/github/
  cjpm.toml          # 独立工程：[package] output-type = "executable"，name = "skill_github"
                     # 依赖 ystyle::cordis_plugin / cordis_core / jsonvalue / ystyle::jsonrpc
  plugin.yaml        # mode: process
                     # command: ./skills/github/target/release/bin/skill_github.exe
                     # enabled / order / autoRestart / tableWhitelist / routes（AutoCreateCode 保护区）
  SKILL.md           # 面向模型的行为契约
  src/main.cj  handlers.cj  effects.cj
```

→ **关键推论**：L3 轨产物是**一个独立可执行文件** `skill_<name>.exe`，运行时宿主经 stdio 拉起。**`.cj` 源码不需要随包分发** —— 这正是"闭源发布技能插件"的工程事实基础（§6.2 展开）。

### 2.5 【本轮核心】官方 SDK 权威字段矩阵 + 标准版实测

**官方 SDK 事实**（`tencentcloud-sdk-python/tencentcloud/wsa/v20250508/`）：

- `wsa_client.py:23-26`：`_apiVersion = '2025-05-08'`、`_endpoint = 'wsa.tencentcloudapi.com'`、`_service = 'wsa'`
- `wsa_client.py:29`：**唯一 Action 为 `SearchPro`**（SDK 内无其它方法）
- `models.py:21-49` 请求参数：`Query`、`Mode`、`Site`、`Cnt`、`Industry`、`Freshness`、`Deeplinks`
- `models.py:152-164` 响应字段：`Query`、`Pages`（**每个元素是 JSON 字符串**）、`Version`（`lite/standard/flagship`）、`Msg`、`RequestId`

**版本能力边界（SDK 原文标注，逐字）**：

| 参数/字段 | 极速版 lite | 标准版 standard | 旗舰版 flagship |
|---|---|---|---|
| `Mode`（0 网页 / 1 垂直信源 / 2 混合） | 不支持 | 支持 | 支持 |
| `Cnt`（10/20/30/40/50） | 不支持 | 支持 | 支持 |
| `Industry`（gov/news/acad/finance） | 不支持 | 支持 | 支持 |
| `Freshness` | 支持 | 支持 | 支持 |
| `Site` | 支持 | 支持 | 支持 |
| `Deeplinks` | — | — | 仅旗舰版 |
| `content`（动态摘要） | 不返回 | **返回** | 返回 |
| `pics` | 不返回 | **返回** | 返回 |
| `score`（相关性 0~1） | 不返回 | **返回** | 返回 |
| `authority_level`（权威度 0~5） | — | — | 仅旗舰版 |
| `deeplinks`（附件子链） | — | — | 仅旗舰版 |

> 依据：`models.py:30`「极速版不支持该参数」（Mode）、`:34`（Cnt）、`:36`（Industry）、`:40`「仅旗舰版支持该参数」（Deeplinks）、`:156`（content/pics 极速版不返回、authority_level 仅旗舰版、deeplinks 仅旗舰版）。

**标准版实测矩阵（15 次真实调用，`.env` 真实密钥，本文最硬的一组证据）**：

| # | 参数组合 | HTTP | 耗时 | Version | 条数 | score 范围 | gov 域名占比 |
|---|---|---|---|---|---|---|---|
| A | 基线（默认） | 200 | 1488ms | **standard** | 10 | 0.776–0.791 | — |
| B | `Cnt=50` | 200 | 837ms | standard | **50** | 0.776–0.791 | — |
| C | `Mode=1` 垂直信源 | 200 | 304ms | standard | **0** | — | — |
| D | `Mode=2` 混合 | 200 | 280ms | standard | 10 | 0.776–0.791 | — |
| E | `Industry=gov` | 200 | 668ms | standard | 10 | 前 3 条：3.848 / 3.723 / 3.688 | — |
| F | `Industry=gov`+`Cnt=50` | 200 | 701ms | standard | **50** | **3.164–4.191** | **98%** |
| G | `Freshness=m3` | 200 | 608ms | standard | 10 | 0.758–0.759 | — |
| H | `Site=beijing.gov.cn` | 200 | 349ms | standard | 2 | 0.551–0.435 | 100% |
| I | `Deeplinks=true` | 200 | 469ms | standard | 10 | 0.789–0.788 | — |

同 query（`专精特新 中小企业 申报 条件`，`Cnt=50`）下的模式对照：

| 参数组合 | 条数 | scoreMin | scoreMax | 有 `date` | gov 占比 |
|---|---|---|---|---|---|
| 默认（无 Mode/Industry） | 50 | 0.777 | 0.791 | 42/50 | **96%** |
| `Mode=0` | 50 | 0.777 | 0.791 | 42/50 | 96% |
| `Mode=2` | 50 | 0.777 | 0.791 | 42/50 | 96% |
| `Industry=gov` | 50 | **3.164** | **4.191** | 47/50 | **98%** |
| `Industry=news` | 50 | 2.484 | 3.678 | 47/50 | 80% |
| `Industry=finance` | 50 | 2.836 | 4.176 | 46/50 | 92% |
| `Industry=acad` | 50 | 2.824 | 4.188 | 49/50 | 94% |
| `Mode=2`+`Industry=gov` | 50 | 3.164 | 4.191 | 47/50 | 98% |
| `Mode=1`+`Industry=gov` | **0** | — | — | — | — |

**由实测得出的四条硬结论**：

1. **升级生效**：`Version` 恒为 `standard`；`Cnt=50` 实测返回 **50 条**（极速版恒为 10）；`content`/`pics`/`score` **全部返回**；`authority_level` **仍不返回**（符合"仅旗舰版"）。
2. **【头号陷阱】`score` 量纲不一致**：公开网页信源（默认 / `Mode=0` / `Mode=2`）下 `score ∈ (0,1)`；而垂直领域模式（`Industry=gov/news/finance/acad`）下 `score ≈ 2.5–4.2`。**`score` 是排序信号，不是跨模式可比的可信度分数**，写死阈值（如 0.5）会导致垂直检索全量误判。详见 §5.1。
3. **`Mode=1` 在标准版下恒返回 0 条**（单独用、配合 `Industry=gov` 用都是 0）。可用的是**默认 / `Mode=0` / `Mode=2`**；`Mode=2` 与默认返回一致，故**不额外传 Mode** 最稳。
4. **元宝在政策类查询上信源本就极权威**：默认模式 gov 域名占比已 **96%**，`Industry=gov` 提升至 **98%**。同时 `date` 覆盖率仅 **42–49/50**（约 84%–98%），**时效判断必须处理 `date` 缺失**。

另实测：`Deeplinks=true`（旗舰版参数）在标准版下**被静默忽略** —— 不报错、不报错码、不返回字段。属"传了没用"，需按"响应字段存在性"而非"参数合法性"做防御。

### 2.6 【本轮新增】`beichen-policy-assistant` 可复用资产盘点

已核实的真实资产（非文档承诺）：

| 资产 | 实测 | 本次价值 |
|---|---|---|
| 政策原文库 `knowledge/policy-original/` | **74 条**（北京市市/区两级政策全文，`.md`） | **"信得过"的事实底座** —— 可离线交叉验证 |
| 官方解读库 `knowledge/policy-interpretation/` | 3 条 | 锚定官方口径 |
| 实操洞察库 `knowledge/policy-insight/` | 3 条（中小企业/人工智能/高新技术产业） | 申报流程要点、常见退回原因 |
| 索引 `knowledge/policy-index.json` | `count: 74`，含 `policy_no/domain/level/department/title/status/conditions/support/file` | 结构化匹配入口 |
| 编排 `COMPOSITION.yaml` | `build-profile → match-policy → generate-report`（`step_type: script`） | 全流程可复用 |
| 脚本 `scripts/` | **9 组 TS + Python 双版本**（init_policy_kb / build_enterprise_profile / match_policy / generate_policy_report / save_to_db / update_policy_kb / gen_policy_summary / verify_summary） | 基建完备 |

**SOP（`SKILL.md:42-47`）**：`0.初始化 → 1.画像 → 2.匹配 → 3.报告 → 4.申报 → 5.落库`，另含 `6.政策库自动更新`（每日 cron）。

**已内置的"信得过"机制（`SKILL.md:38` 原文硬性要求）**：
> 所有匹配结论必须引用政策原文库条目编号（`policy_no`），无出处的匹配结果一律标记为"待核实"，**不进入正式报告**。

以及 `SKILL.md:179-193` 的合规与门禁：人工研判门禁（储备库 → 正式库必须 `--commit --reviewer` 留痕）、严禁输出无溯源结论、严禁绕过门禁。

→ **这是本仓库最被低估的资产**：它已经把"信得过"实现成了**机制**（强制溯源 + 门禁 + 留痕），而不是"标注"。赛道名恰是"查得到，**信得过**"。

**同时它有一个真实断点**：`update_policy_kb`（Step 6 自动更新）依赖抓政府网站，`SKILL.md:165` 自己写了"政府网站反爬：多源重试 + 指数退避"—— 即这条链路脆弱。而元宝标准版的 `Industry=gov` + `Freshness` 正好是它的标准化替代品（实测 gov 占比 98%）。

---

## 三、能力缺口分析（已有 vs 待建）

| 缺口 | 现状 | 待建（本工程范围） | 复用/新建 |
|---|---|---|---|
| G1 元宝搜索鉴权（TC3-HMAC-SHA256） | 无任何 TC3 实现；`src` 内仅 JWT HMAC（`JWTUtil.cj:47`） | 实现 TC3 签名：SecretDate→SecretService→SecretSigning→Signature | 新建（脚本侧 `node:crypto`；仓颉侧 `stdx.crypto.digest`+`stdx.encoding.hex`） |
| G2 SearchPro 调用与结果解析 | 无 | 封装 `Action=SearchPro` / `Version=2025-05-08`；解析 `Pages`（**元素是 JSON 字符串，需二次 parse**） | 新建 |
| G3 **标准版参数编排**（Cnt/Industry/Freshness/Site） | 无 | 面向政策场景的默认编排：`Industry=gov` + `Cnt=50` + `Freshness` 时效窗 | 新建（依据 §2.5 实测） |
| G4 **`score` 自适应归一化** | 无 | 不写死阈值；按本次请求实际 score 分布做 min-max 归一化，或按模式分档设阈值 | 新建（见 §5.1） |
| G5 「信得过」可信度评估 | 无统一层 | **三层交叉验证**：元宝 `Industry=gov` 信源 + 本地 74 条政策原文库 `policy_no` 强制溯源 + 时效（`date`/`Freshness`）与域名权威分级 | 新建 + **复用 beichen 三层知识库与门禁** |
| G6 结果可追溯/引用 | 无统一结构 | 每条结果保留 `url + site + date + passage` 与 `RequestId`；命中政策附 `policy_no` | 新建（字段已由 API 提供） |
| G7 依赖 `web_search` 的死降级链修复 | `beichen` 两条降级路径指向不存在的工具 | 改指元宝搜索入口 | 改造 |
| G8 政策库自动更新换内核 | `update_policy_kb` 抓政府网站、受反爬制约 | 改为元宝 `Industry=gov` + `Freshness=d7/m1` 巡检，入储备库待人工研判 | 改造 |
| G9 L3 进程隔离轨插件（闭源分发） | 7 个技能已用该形态，但无搜索/政策类插件 | 新建 `skill_yuanbao_policy`（独立 `cjpm.toml`，`output-type=executable`） | 新建（范本 `skills/github`） |

---

## 四、推荐方案（工程方案）

### 4.1 总体形态：双轨并行（本轮相对 v1 的关键调整）

**v1 结论**：仅做纯脚本技能，L3 后置。
**v2 修正理由**：用户澄清 **L3 插件为独立工程、编译快、不影响进度**；且 §2.4 已核实仓库内 **7 个技能已是 `mode: process`** 主流形态，范本齐全。**故 L3 轨回到交付范围内。**

```
轨一（必做，零编译）  skills/yuanbao-search/          脚本技能，改完即生效
                       └─ 今天 16:00 前必须可用，保证交付下限

轨二（加分，独立编译） skills/yuanbao-policy/          L3 mode: process 插件
                       ├─ cjpm.toml（output-type = executable）
                       ├─ plugin.yaml（mode: process + command 指向 exe）
                       ├─ SKILL.md（模型行为契约）
                       └─ src/*.cj（TC3 签名用 stdx.crypto.digest 自实现）
                       └─ 产物为独立 exe，源码可不随包分发 → 支撑 §6.2 闭源叙事

业务载体（必做）      skills/beichen-policy-assistant/  改造：检索内核换元宝 + 修复死降级链
```

**时间盒建议**（距 16:00 提交截止）：轨一 + beichen 改造为**必须完成项**；轨二为**可裁剪项**，即使不编译成功，已完成的 `cjpm.toml`/`plugin.yaml`/源码本身也是可展示的工程证据。

### 4.2 核心编排草图

```
企业 / 创业者诉求
     │
     ▼
[检索层 · 元宝搜索 标准版]
  Industry=gov  +  Cnt=50  +  Freshness=时效窗  +  Site（可选限定/排除）
     │  TC3-HMAC-SHA256（脚本: node:crypto ／ 仓颉: stdx.crypto.digest）
     ▼
Pages[]（元素是 JSON 字符串 → 二次 parse）→ 50 条结构化 doc
     │
     ├─► [score 自适应归一化层]  按本次分布 min-max，禁止跨模式写死阈值
     │
     ├─► [信源可信层]  域名分级（.gov.cn 为最高档）+ date 时效校验（处理 date 缺失）
     │
     ├─► [事实交叉验证层]  与本地 74 条政策原文库比对
     │        ├─ 命中 policy_no  → 进正式报告（可溯源）
     │        └─ 未命中          → 强制标"待核实"，不进正式报告（beichen SKILL.md:38 硬性要求）
     │
     ▼
[消费方]
  multi-search-engine（内核换元宝，保留 SERP 兜底）
  beichen-policy-assistant（画像→匹配→报告→申报→落库 + 每日政策巡检）
```

闸口：`research(本文) → gate-research → spec → design → tasks → code`

### 4.3 复用决策（严守"复用优先"）

- **凭据读取**：仓颉侧**原样复用** `CosConfig.getSecretId()/getSecretKey()`（`CosConfig.cj:18-23`）；脚本侧读 `.env` 同名键。
- **HTTP 发送**：复用 `http-client` 调用惯例（`headers` 透传已满足鉴权头），不新增 HTTP 封装。
- **已有技能内核**：`multi-search-engine` 的**结果聚合、限速、重试**保留复用（`SKILL.md:33-48`），只换"取数"层 —— 不推翻重来。
- **业务资产全量复用**：beichen 的 74 条政策原文库、`policy-index.json`、`COMPOSITION.yaml`、9 组双版本脚本**全部保留**，只换检索内核 + 修死链。
- **L3 工程范本复用**：`skills/github` 的 `cjpm.toml` / `plugin.yaml` 结构照抄（依赖块与保护区注释一并沿用）。
- **降级通道**：保留 `web_fetch` / `firecrawl` 兜底，不删除。
- **新建表/配置**：**不新建任何数据库表**，凭据走既有 `.env`。

### 4.4 需新建 / 改造的最小集合

```
新建：
  skills/yuanbao-search/
    SKILL.md                    # frontmatter + 工作流 + 参数表（含版本能力矩阵）
    scripts/yuanbao_search.ts   # TC3 签名 + SearchPro + Pages 解析 + score 归一化 + 可信度标注
    scripts/yuanbao_search.py   # Python 降级版

  skills/yuanbao-policy/        # （轨二 · L3，可裁剪）
    cjpm.toml                   # output-type = "executable"，name = skill_yuanbao_policy
    plugin.yaml                 # mode: process，command 指向 target/release/bin/skill_yuanbao_policy.exe
    SKILL.md
    src/main.cj  handlers.cj    # 仓颉侧 TC3 签名（stdx.crypto.digest + stdx.encoding.hex）

改造：
  skills/multi-search-engine/SKILL.md          # 检索内核改指元宝，保留 SERP 兜底
  skills/beichen-policy-assistant/SKILL.md     # ① web_search 死链改指元宝 ② 检索改用 Industry=gov
  skills/beichen-policy-assistant/scripts/update_policy_kb.{ts,py}  # 换元宝巡检内核
```

---

## 五、关键设计决策与风险

### 5.1 【头号风险 · 已由实测定性】`score` 量纲不一致

**事实**：公开网页信源（`默认`/`Mode=0`/`Mode=2`）下 `score ∈ (0,1)`（实测 0.777–0.791）；垂直领域（`Industry=gov/news/finance/acad`）下 `score ≈ 2.48–4.19`。官方文档 `models.py:156` 只写了"取值 0～1"，**与实测不符**。

**后果**：若按文档写死"score ≥ 0.5 视为可信"，垂直检索将 100% 通过；反之若按垂直档设阈值 3.0，普通检索将 100% 被拒。**两条路都全错。**

**决策**：
1. `score` **仅用于同批次内排序**，不作为绝对可信度阈值；
2. 需要跨批次比较时，做**本次请求内的 min-max 归一化**；
3. 对外呈现的"可信度"用**可解释标签**（信源分级 + 是否命中政策原文库 + 时效档位），而非单一黑箱分数。

> 这条同时也是**叙事资产**：把它写进作品说明，能直接证明"我们是真跑过、真量过"，与"调个 API 就交卷"拉开差距。

### 5.2 【二号】`Mode=1` 恒返回 0 条

实测标准版下 `Mode=1`（含配合 `Industry=gov`）返回 **0 条**。可用组合为默认 / `Mode=0` / `Mode=2`，且 `Mode=2` 与默认结果一致。
**决策**：**不传 `Mode`**（用默认），避免踩空结果；仅在明确需要时传 `Mode=2`。

### 5.3 参数按版本分支 + 字段存在性防御

- 标准版不支持 `Deeplinks`、不返回 `authority_level`：实测为**静默忽略**（不报错）。
- `date` 覆盖率仅 84%–98%：时效判断必须处理缺失。
- **决策**：所有响应字段一律"存在性校验后使用"，**禁止**假定存在（实测已见 `Deeplinks` 传了不返回、`score` 跨模式量纲漂移两例）。

### 5.4 形态选型（相对 v1 的调整）

由「先脚本、L3 后置」调整为「脚本轨保底 + L3 轨并行」。依据：用户澄清 L3 独立编译且快；仓库 7 个 L3 实例可照抄；L3 是 §6.2 闭源叙事的**唯一工程载体**（脚本轨是明文，无法支撑该叙事）。

### 5.5 其它

- **`Pages` 是 JSON 字符串数组**：`models.py:157` 类型 `list of str`，每个元素需二次 parse。解析层最易踩的坑。
- **错误码**：`RequestLimitExceeded`（超频）、`ResourceNotFound`（资源未开通）、`ResourceUnavailable`、`UnauthorizedOperation`、`InvalidParameter`、`InternalError` —— 前两个要给可行动提示。
- **密钥安全**：`.env` 含真实密钥，**脚本与文档一律不打印密钥**（15 次探针均按此执行，输出仅含脱敏统计）。
- **地域性风险**：beichen 知识库为**北京市**政策（74 条）。若评委/受众不在北京，需明确标注适用范围，或补充一层"换地域即换知识库"的说明 —— 不要让它看起来像只能跑一个城市。
- **实测性能基线**：15 次调用全部 HTTP 200、无 `Response.Error`，端到端 **280 ms ~ 1488 ms**；`Cnt=50` 稳定返回 50 条。

---

## 六、夺冠创意与差异化策略（本轮新增）

> 说明：以下为**基于实测事实的策略建议**，每条都标注了支撑证据。其中 §6.5 的"叙事红线"直接引自 `docs/ref/plugin-mechanism-comparison.html` 对本项目的**自我警示**，务必遵守。

### 6.1 赛题本质拆解（已按官方评审维度校准）

**官方评审维度与权重**（选手手册第七节原文）：

| 维度 | 权重 | 官方"看什么" |
|---|---|---|
| 完成度与可用性 | **30%** | 能跑、能播、能直接用 |
| 创意 | **25%** | 想法新、玩法有趣 |
| 场景价值 | **25%** | 解决真实问题，有人愿意用 |
| 展示 | **20%** | 3 分钟讲清做了什么、为什么做、下一步 |

**官方"评委看什么"（侦探赛道原文，逐字引用）**：
> 搜索是作品的核心，**查得准**，来源**点得开**，**查不到敢说不知道**，好用或好玩；
> **问题越难、越有人真在用，分越高**。

**这条原文直接验证了 §6.2 护城河一的方向是对的** —— "查不到敢说不知道"就是 beichen 已有的
`policy_no` 强制溯源门禁。我们的核心创意不是自嗨，是**踩在明文评分点上**。

**由此得出的三条优先级结论**（相对 v2 的调整）：
1. **完成度权重最高（30%）且最可控** ⇒ 交付下限必须守住：能跑、能播、能直接用。
   §4.1 的"轨一脚本技能 + beichen 改造"是这一分的来源，**优先级高于 L3 插件**。
2. **"查不到敢说不知道"是明文评分点** ⇒ 必须做成**可现场演示的可见行为**
   （当场演示一条查不到出处的结果被判"待核实"并拒绝入库），不能只是代码里有。
3. **场景价值 25%：官方说"有人真在用"** ⇒ 政策助手对创业者是刚需，方向成立；
   但需注意官方同时要求**"不碰时政"**，故定位必须是**客观政策检索与条件比对**，
   **不做政策解读/评价**，避免越界。

### 6.2 三条差异化护城河（按杀伤力排序）

**护城河一：「信得过」从"标注"升级为"机制"（靠 beichen 已有资产）**

我们有别人没有的东西 —— 一个**已经把可溯源做成硬性门禁**的政策知识库：

1. **信源层**：元宝 `Industry=gov` 检索，实测 gov 域名占比 **98%**（§2.5）；
2. **事实层**：与本地 **74 条政策原文**比对，**必须命中 `policy_no`** 才进正式报告（`beichen SKILL.md:38` 原文硬性要求）；
3. **时效层**：`date` + `Freshness` 判定现行有效 / 已过期，并处理 `date` 缺失（实测缺失率约 2%–16%）；
4. **门禁层**：储备库 → 正式库必须 `--commit --reviewer` 留痕（`SKILL.md:179-193`）。

**关键话术**：不是"我们的答案带引用"，而是**"没有出处的结论，系统拒绝输出"**。后者是机制，前者是装饰。

**护城河二：L3 闭源二进制插件 —— AI 技能第一次能闭源售卖（业界绝活）**

这是仓库已有的工程事实，且是**其它三家框架做不到**的：

- 对照报告 `docs/ref/plugin-mechanism-comparison.html` 原文：**"闭源分发：dylib 二进制可不开源，JS 必须可见（feasibility.md 第 1540 行）。对编译型语言是实打实的能力差。"**
- 同报告：**"这是四家里唯一一个『默认把第三方插件生成为独立进程工程』的脚手架 —— 把最安全、最可闭源分发、最易做插件市场的那一轨设为默认"**（`plugingen` 默认 `--mode process`）
- 工程事实（§2.4 已核实）：`skills/github/cjpm.toml` → `output-type = "executable"`；`plugin.yaml` → `mode: process` + `command: ./skills/github/target/release/bin/skill_github.exe`。**运行时不需要 `.cj` 源码。**

**为什么这件事有商业说服力**：
政策匹配的核心算法（怎么给企业打分、怎么判断可申报、隐性规则怎么编码）是咨询机构的核心 know-how，**不可能开源**。而在现有 Agent 技能生态里（deepseek-harness / openclaw / hermes-agent），技能全是 JS/Python 脚本 —— **必须明文可见**，等于强制开源。唯一能让你"把算法闭源封装、装进任何 Agent 里跑"的，是 ASR 的 L3 静态二进制轨。

→ 这一条把作品从"我们接了个搜索 API"拉升到"**我们在定义 AI 技能的分发方式**"。

**护城河三：把实测踩到的坑做成诚实性证据**

`score` 量纲漂移（§5.1）、`Mode=1` 返回 0 条（§5.2）、`Deeplinks` 静默忽略 —— 这三条都是**官方 SDK 文档没写、只有真跑才知道**的。
在作品说明里明写"我们实测发现了 X，并处理为 Y"，是极强的**真实性信号**：评委一眼能分辨"真做过"和"调通就交"。建议单独列一节"实测与修正"。

### 6.3 作品定位与命名建议

**推荐定位**：面向创业者的**政策自动化闭环助手**（收集 → 筛选匹配 → 申报 → 跟进），而非通用搜索问答。

理由（对应用户判断"1024 活动大部分可能是创业者"）：
- 创业者真实痛点不是"搜不到"，而是"**不知道自己能申请什么政策**"；
- beichen 已有 74 条政策原文 + 完整 SOP，**是现成的、可演示的、闭环的**；
- "政策"天然要求"信得过"（过期政策、错误解读会直接造成损失）—— **与赛道名天然契合**。

**命名建议**（三选一）：
- 「**政策侦探**」（直扣赛道名"侦探"）
- 「**Policy Detective · 政策侦探**」
- 「**北辰政策侦探**」（沿用 beichen 资产品牌）

**一句定位话术**：
> 元宝搜索负责"查得到"，三层知识库与强制溯源门禁负责"信得过"，L3 闭源二进制插件负责"可交付"。

### 6.4 3 分钟路演脚本（按官方"展示 20% / 3 分钟讲清"校准）

官方要求：3 分钟讲清**做了什么、为什么做、下一步**；另需单独提交**至少 3 次真实查询的录屏或截图**（每次含结果 + 点得开的来源）。

| 时段 | 内容 | 对应评分点 |
|---|---|---|
| 0:00–0:30 | 一句话定位 + 痛点：创业者不知道自己能申报什么政策 | 场景价值 |
| 0:30–1:10 | 实屏跑一次：元宝 `Industry=gov` + `Cnt=50`，展示 50 条 + gov 占比 98% + 权威度分档 | 完成度、查得准 |
| 1:10–1:50 | **高潮：当场演示一条查不到出处的结果被判"待核实"并拒绝进入正式报告** | **"查不到敢说不知道"** |
| 1:50–2:20 | 命中项输出可溯源报告（每条点得开的来源）+ 生成申报任务 | 完成度、来源点得开 |
| 2:20–2:50 | **L3 闭源插件**：目录下没有 `.cj` 源码，只有 `skill_yuanbao_policy.exe` + `plugin.yaml`，照样在跑 | 创意 |
| 2:50–3:00 | 下一步：算法可闭源售卖 = AI 技能的商业闭环 | 拔高 |

> **演示铁律**：两个高潮必须都在。缺了"敢说不"退化成普通 RAG（且丢掉明文评分点）；
> 缺了"无源码可跑"退化成普通接 API。
> **另需单独交付**：3 次真实查询的录屏/截图（含可点开来源）—— 这是"交什么"的硬性要求，别漏。

### 6.4.1 进阶挑战（官方"做到了明显加分"，建议至少占一项）

官方列出三项进阶挑战，我们**天然对上一项，且是现成的**：

| 官方进阶挑战 | 我们的对应 | 状态 |
|---|---|---|
| **持续盯梢**（每天自己去查，有变化就提醒） | beichen 已有 `update_policy_kb`（Step 6 每日 cron）+ 元宝 `Freshness=d7/m1` 巡检 | **现成，改造即得** —— 建议主攻 |
| **深度调查**（自己拆步骤、多轮搜索、交叉比对，交带证据链的报告） | 三层知识库交叉验证 + `policy_no` 证据链 | **现成**，可包装为"证据链报告" |
| 截图查证（丢一张截图，先认出再去查） | 图像识别非本组件范围 | 不占 |

⇒ **建议**：把"持续盯梢"做成演示里的第 4 个亮点（每日自动巡检新政策 + 变更提醒），
它是三项里我们成本最低、且官方明确"明显加分"的一项。

### 6.5 叙事红线（引自对照报告对本项目的自我警示，**务必遵守**）

`docs/ref/plugin-mechanism-comparison.html` 明确警告：

> **"单说『我们支持了仓颉这门静态语言』不是创新，只是『多支持一种语言』——Java SPI/ServiceLoader、OSGi、.NET MEF、原生 dylib 插件都是几十年前的东西。『动态库加载插件』是教科书操作，没人会为这个给一等奖。"**

以及：

> **"不要写『颠覆性创新』『比 dsh 更原生智能』这类营销断言。"**

**因此**：
- **仓颉 / L3 是论据，不是论点**。论点必须是"闭源分发让 AI 技能第一次可以商业化售卖"这个**能力差**；
- **真正的创新主线**是报告原文的 **RSI 主线**：**"以系统工程的确定性消解 LLM 的不确定性"** —— 静态编译 + 确定性工具链（crudgen/plugingen/sdd）+ 强制溯源门禁，共同消解 LLM 的幻觉。这与"信得过"是同一件事的两种表述，**建议作为全篇主线**；
- 建议定调为**"对 AgentSkills 开放标准的务实拓展"**，而非"颠覆"。

### 6.6 需要主动规避的失分点

1. **地域局限**：74 条全为北京政策。必须在材料中明确适用范围，或说明"换地域只需换知识库"—— 否则会被认为通用性差。
2. **`authority_level` 拿不到**：标准版不返回（仅旗舰版）。**不要承诺"权威度评分"**，用"域名分级 + 命中原文库 + 时效"三要素合成可解释标签（§5.1 决策 3）。
3. **`score` 别当绝对分**：写死阈值必错（§5.1）。
4. **别把演示做成"搜索框 + 聊天窗"**：那是基线形态，评委一天看几十个。

---

## 七、后续步骤指引（交接给 spec / design / tasks）

- **下一步（需求规格 spec）**：固化以下 REQ ——
  - **REQ-1**：提供 `yuanbao-search` 检索能力；输入 `Query`（+ 可选 `Site`/`Freshness`/`Industry`/`Cnt`），输出结构化结果数组；
  - **REQ-2**：鉴权使用 `.env` 的 `QCLOUD_COS_SECRET_ID`/`QCLOUD_COS_SECRET_KEY`，TC3-HMAC-SHA256；**密钥不得出现在输出/日志**；
  - **REQ-3**：默认编排为政策场景：`Industry=gov` + `Cnt=50` + `Freshness` 时效窗；**不传 `Mode`**（实测 `Mode=1` 恒 0 条，§5.2）；
  - **REQ-4**：`score` 仅用于同批次排序，跨批次须 min-max 归一化；**禁止**写死阈值（§5.1）；
  - **REQ-5**：结果须含 `title/url/site/date/passage` 与 `RequestId`，并附**可解释可信度标签**（信源分级 + 是否命中 `policy_no` + 时效档位）及理由；
  - **REQ-6**：命中本地政策原文库须绑定 `policy_no`；**未命中一律标"待核实"且不进入正式报告**（沿用 `beichen SKILL.md:38`）；
  - **REQ-7**：所有响应字段按存在性校验后使用；`Deeplinks` 在标准版下静默无效，不得依赖；
  - **REQ-8**：检索失败（含 `RequestLimitExceeded`/`ResourceNotFound`）须给出可行动提示并支持降级 `web_fetch`；
  - **REQ-9**：`multi-search-engine` 检索内核改为优先调本能力，保留 SERP 兜底；`beichen` 两条 `web_search` 死链改指本能力；`update_policy_kb` 换元宝巡检内核；
  - **REQ-10（可裁剪）**：`skills/yuanbao-policy/` L3 进程隔离轨插件，`output-type=executable`，仓颉侧 TC3 签名用 `stdx.crypto.digest` 自实现。
- **再下一步（设计 design）**：签名模块接口、`Pages` 二次 parse 与容错、score 归一化算法、可信度三要素规则、与 beichen 三层知识库的交叉验证契约、L3 插件 stdio 协议与 `tableWhitelist`/`routes` 设计、降级与重试策略。
  - **状态：已完成** → `design.md`（同目录）。存量复用度约 63%（直接复用 12 项 / 部分复用 5 项 / 新建 6 项），含四因子档位降级链、`score` 批次内 min-max 归一化、15 条防回退约束。
  - **注意口径**：本节 REQ-3 的"`Mode=1` 恒 0 条"与 REQ-7 的"`Deeplinks` 静默无效"为**标准版实测口径**；升级旗舰版后实测 `Mode=1` 召回 1 条、`Deeplinks` 已生效。**结论未变（仍禁止依赖 `Mode=1`）**，但以 `spec.md` §2 术语与 `design.md` §2.5.2 的旗舰版口径为准。
- **任务规划（tasks）** 大致五类：
  1. 新建 `skills/yuanbao-search/`（SKILL.md + TS + Python）；
  2. 改造 `multi-search-engine` 与 `beichen-policy-assistant`（检索内核 + 死链修复 + 政策巡检）；
  3.（可裁剪）新建 `skills/yuanbao-policy/` L3 插件工程；
  4. 可信度标注层与 `score` 归一化；
  5. 赛道演示与素材：按 §6.4 脚本产出录屏，按 §6.2 产出"实测与修正"一节。

---

# 附录 A：本研究直接复用的关键文件索引

| 用途 | 文件 | 备注 |
|---|---|---|
| 需求原文 | `.codeartsdoer/specs/1024/req.md` | 原文引用，未改写 |
| **官方 SDK（Python）** | `D:\UCT\products\gitee\tencentcloud-sdk-python\tencentcloud\wsa\v20250508\wsa_client.py:23-26,29` | endpoint/service/version；**唯一 Action = SearchPro** |
| **官方 SDK 字段矩阵** | 同目录 `models.py:21-49`（请求）、`:152-164`（响应） | 版本能力边界与 `Pages: list of str` |
| 官方 SDK（Node） | `D:\UCT\products\gitee\tencentcloud-sdk-nodejs\src\services\wsa\v20250508\wsa_client.ts` + `wsa_models.ts` | 同契约的 TS 版参照 |
| 凭据读取（仓颉） | `src/app/services/uctoo/CosConfig.cj:18-39` | 原样调用 |
| 凭据来源 | `.env:265-266` | `QCLOUD_COS_SECRET_ID` / `QCLOUD_COS_SECRET_KEY` |
| 内置工具清单 | `src/tool/tool_permission.cj`（23 项） | 证明**无 `web_search`** |
| 抓取工具实现 | `src/tool/web_tools.cj:35`、`src/tool/http_tool.cj:19` | 保留复用 |
| 现搜索内核（待替换） | `skills/multi-search-engine/SKILL.md:33-70` | 抓 SERP，改造 |
| **业务载体** | `skills/beichen-policy-assistant/SKILL.md:38,42-47,162,166,179-193` | 三层知识库、SOP、强制溯源、门禁 |
| **政策资产** | `skills/beichen-policy-assistant/knowledge/policy-original/`（74 条）、`policy-index.json` | "信得过"事实底座 |
| **编排** | `skills/beichen-policy-assistant/COMPOSITION.yaml` | 流程可复用 |
| HTTP 通道惯例 | `skills/http-client/SKILL.md:14-41` | 直接仿写 |
| 双版本脚本惯例 | `skills/multi-search-engine/SKILL.md:12-21` | 直接仿写 |
| **L3 工程范本** | `skills/github/cjpm.toml`、`skills/github/plugin.yaml` | `output-type=executable`、`mode: process` |
| L3 生成器 | `src/plugin/tools/plugingen`（`plugingen.cj:48` 默认 `mode = "process"`） | 一键生成独立工程 |
| **L3 论据** | `docs/ref/plugin-mechanism-comparison.html` | 闭源分发、默认 L3、RSI 主线、叙事红线 |
| 密码学能力（仓颉） | `std(x).crypto.digest`（HMAC、SHA256）；实战例 `src/scripts/package_release/main.cj:46-50` | L3 侧 TC3 自实现 |
| 元宝搜索 API 文档 | `https://cloud.tencent.com/document/product/1806/121811` | 接口契约 |
| 赛事手册 | `https://waytoagi.feishu.cn/wiki/Ht49w6i3kipT0Vk61H3cmUxtnJg` | 见下方缺口 |

---

## 缺口与待办

### 已闭合（v2 曾列为头号缺口，现已核准）

1. ~~**评审标准/评分维度与提交格式**~~ —— **已闭合**。同目录 `1024 超能 Coding 周末｜选手手册.md`
   已提供完整信息，要点已并入 §6.1（权重表）、§6.4（3 分钟路演 + 3 次查询录屏）、
   §4.6（spec 中的赛事交付约束）。**关键修正：提交截止 16:00（非 19:02）；路演 3 分钟（非 5 分钟）。**
2. ~~**是否值得再升级旗舰版**~~ —— **已闭合**。已升级旗舰版，`authority_level` 实测值域 2~4；
   但因 `Version` 波动（8 次中 1 次 standard），**仍必须保留无权威度时的降级路径**。

### 待办（需人工执行，不在 AI 范围）

1. **【硬性获奖条件 · 最易漏】社媒分享**：作品必须公开发到**小红书或视频号**，
   带话题 `#元宝搜索 #WaytoAGI #AI切磋大会 #1024超能Coding周末`，并在提交页补填分享链接
   （最晚 10/25 23:59）。**没有分享则不评侦探赛道前三和 10 名优秀奖。**
   ⇒ 建议 16:00 提交作品后立即补发，别拖到晚上。
2. **邀请码与额度**：侦探赛道每人每月 6000 次免费搜索需领邀请码（元宝搜索群）并在活动专区参与；
   未领则只有 2000 次。超出后按量扣费（标准版每千次 20 元）⇒ 调试时**禁止**循环调用。
3. **配额（`RequestLimitExceeded` 阈值）未知**：演示前先跑一遍限量预热，避免现场高频连续调用。
4. **参赛账号是否为该密钥专属**：`.env` 密钥同时被 COS 使用，演示时避免触发与 COS 相关的配额竞争。
