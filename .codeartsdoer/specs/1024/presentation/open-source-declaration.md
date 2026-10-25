# 开源复用声明（提交页 / 社媒可直接粘贴版）

> 完整逐条对照见 [`skills/yuanbao-search/README.md`](../../../skills/yuanbao-search/README.md) 第一章
> 与设计文档 [`design.md`](../design.md) §1.2 / §1.3 / §1.4。本文件是短版，用于提交页与社媒文案。

---

## 一、复用了什么

本项目**不是从零开始**，是在既有开源资产上做增量改造。复用度约 **63%**。

**直接复用 12 项**（复用度 100%）：

| 资产 | 来源 |
|---|---|
| 云 API 密钥对 | 项目 `.env` 既有配置，实测可用于 wsa SearchPro |
| HTTP 请求能力 | `skills/http-client/scripts/http_client.ts` |
| 双版本脚本约定（TS 主 + Python 降级） | `skills/http-client/SKILL.md` |
| L3 进程插件工程模板 | `skills/github/`（cjpm.toml / plugin.yaml / main.cj） |
| L3 stdio 协议与自愈机制 | `src/plugin/plugin_config.cj` |
| HMAC-SHA256 摘要能力 | 仓颉 `stdx.crypto.digest` |
| 政策索引与原文库（北京地区 74 条） | `skills/beichen-policy-assistant/knowledge/` |
| 企业画像 / 政策匹配 / 落库 / 巡检四条脚本链 | `skills/beichen-policy-assistant/scripts/` |
| 限速 / 重试 / 聚合策略 | `skills/multi-search-engine/SKILL.md` |

**扩展改造 5 项**（复用度约 50%）：画像脚本的字段补采与来源标注、匹配结论强制绑定 `policy_no`、
巡检取数源换成元宝检索 + 时效窗、落库扩展申报任务结构、修正上游三条指向不存在工具的降级链。

**新建 6 项**（复用度 0%）：`yuanbao-search` 脚本技能、TC3-HMAC-SHA256 签名模块、
`Pages` 二次解析的响应解析器、可信度四因子合成器、政策交叉验证器、`yuanbao-policy` L3 独立工程。

## 二、本次新增点

1. **检索内核替换**：从「抓搜索引擎结果页」换成结构化检索 API，取数从 HTML 变成带字段的数据。
2. **可信度四因子**：权威度 / 信源分级 / 时效 / 原文库命中，档位降级链，判定过程全写进 `reason` 可逐条核对。
3. **`policy_no` 强制溯源**：匹配结论未绑定政策编号不得作为结论输出，一律转「待核实」。
4. **「可核验出处」门禁**：拿不出可核验出处才说不知道——官方页面 URL 点得开、日期看得见，本身就是出处。
5. **L3 闭源分发轨**：同一套内核编译成 exe，**删掉 `src/` 照样加载运行**，脚本型技能做不到。

## 三、与上游项目的关系

上游 `beichen-policy-assistant` 是「政策匹配」的既有开源技能。**本次没有 fork 改写**，
是在其脚本链上做 5 处扩展，并把取数通道换成元宝检索内核。
上游脚本链保持可独立运行，本组件关闭后上游不受影响。

## 四、许可证

MIT。上述复用资产遵循各自 upstream 的许可证。

## 五、不含内容声明

- 不含任何密钥、口令或内部敏感路径（产物目录密钥扫描实测 0 命中）。
- 不涉时政评论与特定个人。
- 政策原文库为北京地区 74 条政策，报告已明示适用范围，不代表全国通用。
