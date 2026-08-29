# 产业政策技能（北辰产业政策智能体）编码任务清单

> **文档定位**：本文档为 shenicest 黑客松参赛作品核心开发件《产业政策技能》（`beichen-policy-assistant`）的任务清单（tasks.md），定义"按什么顺序做什么"。
>
> **版本**：v1.0 | **日期**：2026-08-29

---

## 任务总览

| 阶段 | 内容 | 状态 |
|------|------|------|
| Phase 0 | 需求分析与命题要求对照 | ✅ 完成 |
| Phase 1 | 种子数据与三层知识库初始化 | ⬜ 待完成 |
| Phase 2 | 创建技能（SKILL.md + COMPOSITION.yaml + scripts） | ⬜ 待完成 |
| Phase 3 | 撰写需求文档（spec/design/tasks） | ✅ 完成 |
| Phase 4 | 配置昇腾算力（.env → AtomGit） | ⬜ 待完成 |
| Phase 5 | 端到端验证 + 演示素材 | ⬜ 人工验证 |

---

## Phase 0：需求分析与命题要求对照

- [x] TASK-0-01：研读《北辰产业云社区命题 PPT》政策赋能精准化章节（政策库—匹配库—申报库、74 条政策目录）
- [x] TASK-0-02：研读产业政策智能体四项功能示例（全景企业画像 / 多元政策匹配 / 三层知识库 / 自动化更新政策库）
- [x] TASK-0-03：确定技能形态实现方案（技能与智能体可互转，asr 一切皆技能插件系统）
- [x] TASK-0-04：对照 shenicest 赛道要求（真实解决具体问题 / 必须能跑 / 注重稳定与数据安全）
- [x] TASK-0-05：确认复用清单（runtime 内置工具 / 昇腾 API / company+tasks 表 / aibuilder / WebMCP）

## Phase 1：种子数据与三层知识库初始化

- [x] TASK-1-01：从命题附件提取 74 条政策目录，生成 `policy-seed.json`（2026-08-29 完成，由 `extract_policy_seed.py` 从命题 PPT 第 3 页表格自动提取，双栏表格 + 合并单元格前向填充 + 部首异体字规范化；含 meta 字段说明与统计）
  - 字段：编号（1-74）、所属领域（人才支持/知识产权/融资服务/人工智能/智能机器人/数据要素/数字医疗/互联网3.0/高新技术产业/商务经济/金融业/文化产业/中小企业/外商投资/青年科技人才/商务中心区）、政策层级（市级/区级）、发布部门、政策名称
  - 分布：市级 47 条 / 区级 27 条；17 个领域（高新技术产业 14 条最多，数字医疗 11 条、互联网3.0 10 条次之）
  - 特判：第 74 条《支持人工智能OPC创新发展行动方案（试行）》原表领域留空，按政策名称推断为人工智能（JSON 内有 note 标注）
- [ ] TASK-1-02：编写 `scripts/init_policy_kb.py`，生成 74 条政策原文库条目骨架 + `policy-index.json`
- [ ] TASK-1-03：创建官方解读库（`policy-interpretation/`）与实操洞察库（`policy-insight/`）目录及 3-5 个示例条目
- [ ] TASK-1-04：为高频领域（人工智能、高新技术企业、专精特新、知识产权质押融资）补充政策要点与申报条件结构化数据

## Phase 2：创建技能与脚本

- [ ] TASK-2-01：创建 `skills/beichen-policy-assistant/SKILL.md`（SOP 主文档）
  - 定义六步 SOP：画像 → 匹配 → 报告 → 更新 → 落库 → 呈现
  - 定义输入参数（company/policy_no/topn/reviewer/mode）
  - 安全合规章节（数据合规/研判门禁/内容合规/信创合规）
- [ ] TASK-2-02：创建 `COMPOSITION.yaml`（六步编排）
- [ ] TASK-2-03：`scripts/build_enterprise_profile.py` —— 全景企业画像
  - 工商/经营/舆情多渠道公开数据聚合
  - LLM 要点萃取 + 无 LLM 规则降级
  - 输出 `output/profiles/{企业slug}.json/.md`
- [ ] TASK-2-04：`scripts/match_policy.py` —— 多元政策匹配
  - 硬性条件初筛（region/qualification/industry vs policy-index）
  - 双源检索（本地知识库 + web_search）
  - 语义适配评分 + 匹配依据 + 缺口项；policy_no 绑定（幻觉治理）
  - 输出 `output/matches/{企业slug}-{date}.json`
- [ ] TASK-2-05：`scripts/update_policy_kb.py` —— 政策库自动更新
  - 抓取模式：市政府/朝阳区政府/市科委/中关村管委会列表页 → `output/pending/{date}.json`
  - commit 模式：--reviewer 研判确认 → 正式库 + 索引更新
- [ ] TASK-2-06：`scripts/generate_policy_report.py` —— 适配研判报告
  - 昇腾 API（AtomGit OpenAI 兼容）生成
  - 匹配清单 + 条件对标表（满足/部分满足/不满足）+ 缺口分析 + 申报建议
  - 无 LLM 模板降级；固定合规声明
- [ ] TASK-2-07：`scripts/save_to_db.py` —— 结果落库
  - company upsert（org_type='beichen-enterprise'）
  - tasks 插入 policy-match（completed）+ policy-apply（pending，含材料清单）
  - psycopg2 直连或生成 SQL 文件

## Phase 3：撰写需求文档

- [x] TASK-3-01：`spec.md` —— 需求规格（组件定位/设计原则/领域术语/角色边界/核心能力/数据约束/命题对照/验收标准）
- [x] TASK-3-2：`design.md` —— 技术设计（架构图/目录结构/知识库格式/模块设计/昇腾接入/落库设计/合规安全/风险缓解/验收清单）
- [x] TASK-3-03：`tasks.md` —— 本任务清单

## Phase 4：配置昇腾算力（.env → AtomGit）

- [ ] TASK-4-01：确认 `apps/agentskills-runtime/.env` 大模型提供商为 AtomGit（昇腾 API）
  ```env
  MODEL_PROVIDER=atomgit
  MODEL_NAME=deepseek-v4-flash
  MODEL_CONFIG=atomgit:deepseek-v4-flash
  ATOMGIT_API_KEY=<token>
  ATOMGIT_BASE_URL=https://api-ai.gitcode.com/v1
  ```
- [ ] TASK-4-02：核对脚本侧 `LLM_BASE_URL/LLM_API_KEY/LLM_MODEL` 环境变量

## Phase 5：端到端验证与演示素材（人工操作）

- [ ] TASK-5-01：启动 runtime，确认技能加载成功（`skills/beichen-policy-assistant`）
- [ ] TASK-5-02：执行画像：`skill run beichen-policy-assistant:build-profile company="北京XX科技有限公司"`
- [ ] TASK-5-03：执行匹配与报告，验证 output/profiles、matches、reports 各阶段产物
- [ ] TASK-5-04：模拟政策更新（抓取 + commit 研判入库），验证 pending 流水与索引变更
- [ ] TASK-5-05：验证 company / tasks 落库，aibuilder 呈现画像/报告/申报任务
- [ ] TASK-5-06：抽取匹配报告结论回溯 policy_no，验证幻觉治理有效
- [ ] TASK-5-07：录制演示片段（供作品演示视频剪辑：画像→匹配→报告→申报任务闭环）
- [ ] TASK-5-08：更新 shenicestHackathon 项目文档 4.3 节（产业政策智能体→技能实现）引用本技能

---

## 提交物清单

| # | 交付件 | 形式 | 状态 |
|---|--------|------|------|
| 1 | 技能源码 | skills/beichen-policy-assistant（SKILL.md + knowledge + scripts） | ⬜ 待开发 |
| 2 | 种子数据 | knowledge/policy-seed.json（74 条政策目录） | ⬜ 待生成 |
| 3 | 需求文档 | spec.md / design.md / tasks.md | ✅ 完成 |
| 4 | 端到端演示 | 演示视频片段 + aibuilder 截图 | ⬜ 待录制 |
