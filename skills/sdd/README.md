# Agentic Software Factory Hackathon 参赛说明
1. 本sdd技能即是对应本次黑客松的课题：如何可复用的高质量开发软件。本sdd技能实现了多agent协作的规范驱动开发流程，子agent定义在agents目录。本sdd技能只支持运行在https://atomgit.com/UCToo/agentskills-runtime 智能体开源项目基础设施中，主agent定义在agentskills-runtime根目录。在业界首创文件系统的AGENTS.md及子agent定义自动与agents数据库表双向数据同步。agentskills-runtime在业界首创实现了“一切皆技能”的插件系统，为数字系统赋能原生智能特性。支持技能可商业化闭源发布实现技能市场盈利模式闭环。这是一个可以发表nature级别论文的成果，能够推动智能体生态商业化历史进程的原创创新。在sdd/src 目录中可以看到支持了仓颉静态编程语言，在sdd/target目录中可以看到仓颉技能插件可以采用二进制闭源发布，可以有效保护技能中的SOP资产。
2. 本sdd运行生成了本次黑客松赛题的AgenticSoftwareFactoryHackathon规范驱动开发工程目录，由于时间有限，作者从2026.09.29才开始开发本次参赛的两个课题项目。因此目前只使用sdd由agent对赛题进行了需求分析，创建了规范驱动开发文档以及使用plugingen插件生成工具，从数据库结构确定性生成了github和sheets两个L3技能插件，两个插件所包含的数据库表的全部crud各层代码，以及在web项目中生成了对这些数据库表的crud管理界面，还未进行全面测试以及二次定制开发。在https://atomgit.com/UCToo/agentskills-runtime 和https://atomgit.com/UCToo/web-admin 的AgenticSoftwareFactoryHackathon分支可获取完整代码。在agentskills-runtime/log目录中有完整开发和运行日志记录。agentskills-runtime中内置了crudgen、crudweb、plugingen等从数据库结构确定性生成大量基建代码的工具，因此大量代码并不需要大模型推理生成，很省token。
3. 由于agentskills-runtime采用的是仓颉编程语言全栈国产自研技术栈，因此上传的sdd技能在arc-bench平台上是跑不起来的。agentskills-runtime已经在2026.10.01更新的v0.0.29版本中添加了对arc-bench平台大模型通道的支持。
4. agentskills-runtime开源项目以及配套的Web管理端开源项目 https://atomgit.com/UCToo/web-admin 中已包含大量可复用开源基础设施，可用于完成本次赛事的赛题开发，sdd所创建的工程文档中已列明。
5. 2026.09.11工信部印发《“人工智能+软件”专项行动实施方案》，（七）夯实智能体软件技术基础。AgentSkills-runtime正与此符合。（九）建设智能体软件应用市场。正是作者2026.02发表文章《深度解析agent skill标准》公开提案的建议。本开源项目政策命中率100%。本项目已支持智能体互联国标，是建设智能体互联网骨干网络及核心节点的最佳开源基础设施。参考文章 
https://mp.weixin.qq.com/s/qFae5uqJsOAEkn1LN12tuA
6. 本开源项目入选第一批CCF&中国光华科技基金会青年开源专项基金种子计划支持，在2026.08CCF开源大会获得颁奖(国家级)。作者受邀参加2026.04.24仓颉伙伴发展与开发者交流大会，做了《仓颉智能体框架设计哲学》主题演讲。作者受邀作为主题演讲嘉宾参加WAIC 2026世界人工智能大会，介绍采用仓颉编程语言的全国产智能体开源项目。发布继Harness之后的智能体新范式——AI驱动开发框架。智能体领域的“韬定律”，国产技术定义新一代技术话语权。响应WAIC2026开幕式主席主旨演讲，“中国在人工智能领域始终致力于做国际公共产品的提供者”号召，为世界提供更好的中国方案。

# sdd 插件（SDD 规范驱动开发 / L3 进程隔离轨）

独立 cjpm executable 工程，对标 DeepSeek Harness Cordis 的进程隔离插件轨。

> **部署与排障请看 `OPS.md`**（含 design §2.6 十三条防回退约束对照）。本文件只讲形态与构建。

## 这个插件承担什么

**资产包为主，薄壳为辅**——六步编排引擎落在宿主侧
（`src/app/services/bridge/sdd_orchestration_service.cj`），因为宿主向插件进程只暴露
`host.db` / `host.mcp` / `host.event` / `host.db_schema_lookup` / `host.cache` / `host.log`，
**没有 `host.agent.invoke`**，插件进程里跑不了子 agent。

| 目录 | 内容 |
|---|---|
| `SKILL.md` | 六步方法论 + 五闸口 `decision-points` + 子 agent 声明表 |
| `COMPOSITION.yaml` | 六步编排（long-running-task 同款 schema） |
| `DATA_CONTRACT.yaml` | 表/字段读写契约 |
| `agents/` | 五个子 agent 声明文件（**约定即注册**：文件是唯一来源，删文件即下线） |
| `prompts/` | 每步执行提示词（"这一步怎么做"） |
| `templates/` | 文档模板（实体复制，插件自完备，不依赖目录外文件；共九份：六步七份 + 主工程子系统目录 `specs-index-template.md` + 子系统集成契约 `subsystem-contract-template.md`） |
| `src/` | 薄壳：`main.cj` + `effects.cj` |

## 编译

```bash
cd ./skills/sdd
cjpm build
```

产物：`target/release/bin/skill_sdd.exe`（`plugin.yaml` 的 `command` 即此路径，
且该路径是**相对宿主工作目录**，不是相对插件目录）。

## 登记到宿主

在宿主 `config/plugins.yaml` 追加：

```yaml
plugins:
  - name: sdd
    mode: process
    command: ./skills/sdd/target/release/bin/skill_sdd.exe
    enabled: true
    autoRestart: true
```

## 约束

- 依赖仅 `ystyle::cordis_plugin` + `jsonvalue`（+仓颉标准库）——零 magic 包依赖。
- 禁用 `@Plugin` 宏：用显式 API `PluginRuntime.run(...)`。
- 数据访问一律经 `host.db` 服务代理（不直连数据库）；可访问表受 `tableWhitelist` 限制（7 张）。
- **日志只走 stderr**：`stdout` 是 stdio RPC 通道，往它打印会污染解析。
- 阶段文档默认落 runtime 自有 `specs/{feature_name}/`；**用户显式指定输出目录时以用户为准**
  （`output_dir` 参数），不再纠结目录属谁——默认行为才是"禁落 `.codeartsdoer/specs/`"这条约束所管的对象。
- HTTP 入口只有五个（详见 `SKILL.md「路由」`）：`start` / `run` / `run-stage` / `review` / `status`。
  `run` 与 `run-stage` 都可传 `stage` 指定执行阶段（跳步续跑，例：前面几步已完成，直接
  `{ "stage": "code" }` 跑编码）；传了就只跑这一步，跑完停在 `gate-code` 闸口等人决策。

## 相关文档

- `OPS.md` —— 部署、排障、防回退对照
- `.codeartsdoer/specs/sdd/` —— spec / design / research / tasks 账本
- `docs/agents/agent-declaration-spec.md` —— Agent 声明规范（含"技能内 agents 目录约定"章）

## 二次开发底座（迭代 runtime / uctoo 前必读）

本技能只管六步编排，**规范条款与脚手架不在本技能内复述**，一律以这两个源为准：

| 源 | 位置 | 承担什么 |
|---|---|---|
| `uctoo-dev-manual` | `skills/uctoo-dev-manual/` | 开发手册技能（渐进式六层）：内置工具用法、V4 API / 数据库 / 模块 / 权限 / 插件三轨 / 长程任务规范 |
| `docs/uctoo-v4/` | `docs/uctoo-v4/` | V4 规范文档：API 规范、数据库设计、模块开发、ORM、中间件、行级权限 |

配套的确定性代码生成工具（一律 `cjpm run --skip-build --name <包名> --run-args "<参数>"`）：

```
loaddbinfo → plugingen（优先做成插件，默认 L3 进程隔离轨 process）／crudgen（仅宿主公共基础设施）／crudweb（管理界面）
            下线走对称的 pluginuninstall，别手删 skills/{name}/（会留 DB 痕迹）
```

规矩落点见 `SKILL.md` 铁律 14；编码步与任务步分别以 `prompts/code.md` 与 `prompts/task.md` 为准。
