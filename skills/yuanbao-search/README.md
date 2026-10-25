# yuanbao-search — 元宝搜索检索内核

把政策线索的取数通道从「抓取搜索引擎结果页」换成**结构化检索 API**（元宝搜索 · 腾讯云 `wsa` SearchPro），
并在返回前完成**可信度四因子标注**与**政策原文库交叉验证**。

一句话定位：**政策查得到，还敢信**——查不到可靠依据时明确说「不知道」，而不是编一个看起来很像的答案。

- 技能：`skills/yuanbao-search/`（脚本轨，TS 主 + Python 降级）
- 插件：`skills/yuanbao-policy/`（L3 进程隔离轨，编译产物，可闭源分发）
- 协议：MIT
- 完整规格：`.codeartsdoer/specs/1024/`（spec / design / research / tasks）

---

## 一、开源复用声明

本作品**不是从零开始**，是在既有开源资产上的增量改造。下表逐条列明来源，与设计文档
`.codeartsdoer/specs/1024/design.md` §1.2 / §1.3 / §1.4 完全对应。

### 1.1 直接复用（12 项，复用度 100%）

| # | 复用资产 | 来源位置 | 复用方式 |
|---|---|---|---|
| S1 | 云 API 密钥对 | `.env` 的 `QCLOUD_COS_SECRET_ID` / `QCLOUD_COS_SECRET_KEY` | 直接读取，实测可用于 wsa SearchPro |
| S2 | HTTP 请求能力 | `skills/http-client/scripts/http_client.ts` | 调用其 CLI，签名头由本组件生成后传入 |
| S3 | 双版本脚本约定 | `skills/http-client/SKILL.md` | 新技能照此形态建 TS 主 + Python 降级 |
| S4 | L3 工程模板 | `skills/github/cjpm.toml`、`plugin.yaml`、`src/main.cj` | 复制改名，仅改 name / command / 依赖 |
| S5 | L3 stdio 协议与自愈 | `src/plugin/plugin_config.cj` | 遵循 JSON-RPC over stdio，诊断走 stderr |
| S6 | 密钥派生所需摘要能力 | `stdx.crypto.digest` | L3 轨实现 TC3-HMAC-SHA256 |
| S7 | 政策索引与原文库 | `skills/beichen-policy-assistant/knowledge/policy-index.json`（74 条） | 交叉验证的事实底座 |
| S8 | 企业画像生成 | `build_enterprise_profile.ts` | 直接调用 |
| S9 | 政策匹配 | `match_policy.ts` | 直接调用 |
| S10 | 落库（不新建表） | `save_to_db.ts` | 直接调用 |
| S11 | 研判门禁 | `update_policy_kb.ts` | 直接调用，`--reviewer` 强制署名 |
| S12 | 限速 / 重试 / 聚合策略 | `skills/multi-search-engine/SKILL.md` | 编排层复用 |

### 1.2 扩展改造（5 项，复用度约 50%）

| # | 被扩展的资产 | 本次扩展点 | 对应需求 |
|---|---|---|---|
| E1 | `build_enterprise_profile.ts` | 字段缺失时的降级从「标记留空」改为**经元宝检索采集并标注采集来源**（`field_sources` / `search_evidence[]` / `search_meta`） | REQ-PD-021 |
| E2 | `match_policy.ts` | 匹配结论**必须**绑定 `policy_no`，未绑定者不得作为结论输出（新增 `pending` / `policy_no_coverage`） | REQ-PD-022 |
| E3 | `update_policy_kb.ts` | 取数源由固定 4 站点抓取改为元宝检索 + `--freshness` 时效窗；保留 `--commit --reviewer` 门禁 | REQ-PD-026/027 |
| E4 | `save_to_db.ts` | 申报任务的 `task_type='policy-apply'` 与 `extra_data`（材料清单 / 截止时间 / 跟进状态 / 信用代码） | REQ-PD-025/029 |
| E5 | `beichen-policy-assistant/SKILL.md` | 三条指向不存在工具的降级链改指本组件（`:6` `:162` `:166`） | REQ-PD-031 |

### 1.3 本次新建（6 项，复用度 0%）

| # | 新增物 | 说明 |
|---|---|---|
| N1 | `skills/yuanbao-search/` 脚本技能 | `SKILL.md` + `scripts/yuanbao_search.ts` / `.py` |
| N2 | TC3-HMAC-SHA256 签名模块 | `scripts/sign.ts` / `.py`，五步密钥派生 + 规范请求串 |
| N3 | 响应解析器 | 实测 `Pages` 元素是 JSON 字符串，必须二次 parse |
| N4 | 可信度四因子合成器 | 档位降级链：权威度 / 信源分级 / 时效 / 原文库命中 |
| N5 | 政策交叉验证器 | `policy_kb.ts` / `.py`，三级证据 + 绑定 `policy_no` |
| N6 | `skills/yuanbao-policy/` L3 独立工程 | cjpm.toml + plugin.yaml + 6 个 `.cj`，**闭源分发载体** |

**复用度概览**：直接复用 12 项 + 部分复用 5 项 + 新建 6 项 → **复用度 ≈ (12 + 5×0.5) / 23 ≈ 63%**。

### 1.4 与上游项目的关系

上游 `beichen-policy-assistant` 是「政策匹配」的既有开源技能（三层知识库 + 画像→匹配→报告→落库→巡检脚本链）。
本次**没有 fork 改写**，而是在其脚本链上做 E1–E5 五处扩展，并把它的取数通道换成元宝检索内核。
上游脚本链保持可独立运行，本组件关闭后上游不受影响。

---

## 二、快速开始

```bash
# 1) 自检：只验证连通性与服务档位，不跑完整闭环
node --experimental-strip-types scripts/yuanbao_search.ts --selftest

# 2) 检索：输出单行 JSON（诊断与进度走 stderr）
node --experimental-strip-types scripts/yuanbao_search.ts \
  --query "专精特新 中小企业 申报 条件" \
  --industry gov --cnt 50 --freshness 1y --json

# 3) Python 降级版（同签名，仅标准库；TS 版跑不起来时用）
python scripts/yuanbao_search.py --query "…" --industry gov --cnt 50
```

前置条件：

- Node.js ≥22.6（推荐 v23.10+，内置 fetch）或 Python 3.8+
- `.env` 中配置 `QCLOUD_COS_SECRET_ID` / `QCLOUD_COS_SECRET_KEY`
- 政策原文库（默认 `../beichen-policy-assistant/knowledge/policy-index.json`），缺了也能跑，只是结论全转「待核实」

## 三、目录结构

```
scripts/
├── sign.ts / .py               # N2 TC3-HMAC-SHA256 签名
├── policy_kb.ts / .py          # N5 政策原文库加载 + 三级证据交叉验证
└── yuanbao_search.ts / .py     # N1 CLI 入口（N3 解析 + N4 合成都在这里）
SKILL.md                        # 模型行为契约与闭环流程
README.md                       # 本文件
```

TypeScript 与 Python **双版本同 CLI、输出逐字节对齐**（仅 JSON 数字写法 `1` vs `1.0` 的差异）。
出网复用 `skills/http-client/scripts/http_client.ts`，本技能只负责生成签名头，不重写 HTTP 客户端。

## 四、实测数据（真实调用，非构造）

| 场景 | 结果 |
|---|---|
| 自检 | HTTP 200 / `Version=flagship` / 10 条 / `authority_level` 10/10 可用 / 原文库 74 条 / 2.3s（TS）、1.3s（PY） |
| 真实查询（cnt=30） | 30 条 → 可采信 20 / 待核实 10；命中原文库 2 条（`policy_no=48`） |
| 排除原因分布（50 条批次） | 未知站点 / 自媒体 21 条、过期 1 条，均为真实不可核验项 |
| 端到端联调（3 家企业） | 北辰实业 13/7、朝阳智算 16/4、中关村软件园 17/3（items/excluded），三次均 HTTP 200，`policy_no` 覆盖率 1.0 |
| 异常用例（原文库索引改名） | 退出码 0、`ok=true`、20 条中 7 条被排除，流程不中断 |

## 五、能力边界（诚实标注，不为凑数放宽阈值）

- **检索侧 `policy_no` 绑定率偏低**：三次联调的检索侧绑定均为 0。原因是本轮检索词命中的多为
  「申报通知 / 新闻通稿」，与原文库政策名的标题 Jaccard 普遍 < 0.6、正文全名命中率极低。
  此前一次查询绑定成功 3 条，是因为检索通道自身已标注 `policyNo`（48 / 74）。
  **这是能力边界，不通过放宽阈值来凑数。**
- **政策原文库是北京地区 74 条**：报告必须明示适用范围，不得让用户误认为全国通用。
- **`score` 不可跨批次比较**：实测跨度 0.75~5.46，只在批次内做 min-max 归一化使用。
- **权威度依赖服务档位**：`standard` 档位下 `authority_level` 整批缺失，此时该因子记「不可用」并降级，不编造。

## 六、合规

- 仅做客观政策的检索与条件比对，不做政策解读或倾向性评价。
- 报告必须附「仅供申报参考，不构成法律意见」。
- 凭据只从 `.env` 读取，不进产物、日志、异常堆栈与进程参数（实测 `output/` 密钥扫描 0 命中）。
- 内容禁区：不涉时政评论与特定个人。

## 七、License

MIT。本文件所声明的复用资产遵循各自 upstream 的许可证。
