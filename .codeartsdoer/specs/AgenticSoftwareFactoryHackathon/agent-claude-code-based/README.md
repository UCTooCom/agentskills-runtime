# sdd 目录中才是本次参赛的提交作品

# Agentic Software Factory Hackathon 参赛说明
1. 本sdd技能即是对应本次黑客松的课题：如何可复用的高质量开发软件。本sdd技能实现了多agent协作的规范驱动开发流程，子agent定义在agents目录。本sdd技能只支持运行在https://atomgit.com/UCToo/agentskills-runtime 智能体开源项目基础设施中，主agent定义在agentskills-runtime根目录。在业界首创文件系统的AGENTS.md及子agent定义自动与agents数据库表双向数据同步。agentskills-runtime在业界首创实现了“一切皆技能”的插件系统，为数字系统赋能原生智能特性。支持技能可商业化闭源发布实现技能市场盈利模式闭环。这是一个可以发表nature级别论文的成果，能够推动智能体生态商业化历史进程的原创创新。在sdd/src 目录中可以看到支持了仓颉静态编程语言，在sdd/target目录中可以看到仓颉技能插件可以采用二进制闭源发布，可以有效保护技能中的SOP资产。
2. 本sdd运行生成了本次黑客松赛题的AgenticSoftwareFactoryHackathon规范驱动开发工程目录，由于时间有限，作者从2026.09.29才开始开发本次参赛的两个课题项目。因此目前只使用sdd由agent对赛题进行了需求分析，创建了规范驱动开发文档以及使用plugingen插件生成工具，从数据库结构确定性生成了github和sheets两个L3技能插件，两个插件所包含的数据库表的全部crud各层代码，以及在web项目中生成了对这些数据库表的crud管理界面，还未进行全面测试以及二次定制开发。在https://atomgit.com/UCToo/agentskills-runtime 和https://atomgit.com/UCToo/web-admin 的AgenticSoftwareFactoryHackathon分支可获取完整代码。在agentskills-runtime/log目录中有完整开发和运行日志记录。agentskills-runtime中内置了crudgen、crudweb、plugingen等从数据库结构确定性生成大量基建代码的工具，因此大量代码并不需要大模型推理生成，很省token。
3. 由于agentskills-runtime采用的是仓颉编程语言全栈国产自研技术栈，因此上传的sdd技能在arc-bench平台上是跑不起来的。agentskills-runtime已经在2026.10.01更新的v0.0.29版本中添加了对arc-bench平台大模型通道的支持。
4. agentskills-runtime开源项目以及配套的Web管理端开源项目 https://atomgit.com/UCToo/web-admin 中已包含大量可复用开源基础设施，可用于完成本次赛事的赛题开发，sdd所创建的工程文档中已列明。
5. 2026.09.11工信部印发《“人工智能+软件”专项行动实施方案》，（七）夯实智能体软件技术基础。AgentSkills-runtime正与此符合。（九）建设智能体软件应用市场。正是作者2026.02发表文章《深度解析agent skill标准》公开提案的建议。本开源项目政策命中率100%。本项目已支持智能体互联国标，是建设智能体互联网骨干网络及核心节点的最佳开源基础设施。参考文章 
https://mp.weixin.qq.com/s/qFae5uqJsOAEkn1LN12tuA
6. 本开源项目入选第一批CCF&中国光华科技基金会青年开源专项基金种子计划支持，在2026.08CCF开源大会获得颁奖(国家级)。作者受邀参加2026.04.24仓颉伙伴发展与开发者交流大会，做了《仓颉智能体框架设计哲学》主题演讲。作者受邀作为主题演讲嘉宾参加WAIC 2026世界人工智能大会，介绍采用仓颉编程语言的全国产智能体开源项目。发布继Harness之后的智能体新范式——AI驱动开发框架。智能体领域的“韬定律”，国产技术定义新一代技术话语权。响应WAIC2026开幕式主席主旨演讲，“中国在人工智能领域始终致力于做国际公共产品的提供者”号召，为世界提供更好的中国方案。

# ARC-Bench Agent Starter

This reference agent initializes a starter application, then asks Claude Code to implement one
direct child subtree of `ROOT` at a time.

## What to Edit

- `main.py`: the Claude Code agent entrypoint.
- `template/`: the starter application. Its contents are copied directly into the output directory.

## Entrypoint Contract

ARC-Bench runs your agent like this:

```bash
python3 main.py /path/to/requirements --output-dir /path/to/output --type web
```

The input directory must contain `requirements.yaml` with `id: ROOT`. The agent copies the
contents of `template/` into `--output-dir`, then sends each direct ROOT-child subtree to Claude
Code in sequence. Claude Code modifies the same output directory for every module.

The bundled `skills/` directory is copied to `.claude/skills/` in the output project. Claude Code
is told where to find the skills and can use their scripts for runtime progress, traceability, and
git checkpoints when those actions are useful.

## Model Variables

The runner injects:

- `OPENAI_API_KEY`
- `OPENAI_BASE_URL`
- `MODEL`

See `examples/model_calling.py` for Chat Completions and Responses examples.
