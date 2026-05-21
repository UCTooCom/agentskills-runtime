《为什么完美的AI Agent不存在？Claude Code源码背后的五大设计哲学与妥协》
小纪有话说：


当AI编程工具进化为能自主执行任务的智能体，架构层面的设计选择不再只关乎性能，更关乎安全、可控性与可持续性。MBZUAI VILA Lab联合UCL以Anthropic的Claude Code源码为案例，系统分析了生产级AI智能体的设计空间。
《Dive into Claude Code: The Design Space of Today'sand Future Al Agent Systems》
Jiacheng Liu1, Xiaohan Zhao1, Xinyi Shang1.2, Zhigiang Shen1,tIVILA Lab, Mohamed bin Zayed University of Artificial Intelligence, 2UniversityCollege LndonifCorresponding author
这篇文章在X上也引起了广泛的关注和讨论：
来自MBZUAI VILA Lab的研究团队发布了一项新研究，以Anthropic的Claude Code源码为案例，对生产级AI智能体（Agent）的架构设计空间做了系统分析。论文尝试探讨一个问题：构建一个生产级AI智能体，需要回答哪些设计问题？


Claude Code是当前一代AI编程工具的代表：在终端里输入一句“帮我修复auth.test.ts里失败的测试”，它会自己收集上下文、规划步骤、调用工具、执行命令、检查结果，反复迭代直到认为任务完成[7]。围绕它的源码解读文章已经有不少，但多数聚焦在“怎么实现”的层面。


这篇论文的切入点不同：


它不满足于描述实现细节，而是尝试从源码和官方文档中反推出驱动整个架构的设计哲学与设计原则，分析权限、上下文管理、可扩展性、子智能体等关键子系统的设计选择。同时通过与近期备受关注的开源智能体系统OpenClaw的对比，展示同样的设计问题在不同部署场景下可能导向不同的答案。

Part 1
研究方法


论文的分析基于以下几类信息来源：Claude Code v2.1.88的TypeScript源码、Anthropic官方发布的博客和产品文档，以及社区的逆向工程分析报告。
观察一：五条设计哲学塑造了架构，但它们之间存在矛盾
论文没有上来就讲技术细节，而是先追问了一个更底层的问题：这个系统为什么要设计成这样？通过综合Anthropic官方文档、源码和相关资料，论文总结出五条驱动架构，以人类价值观为导向的设计哲学：
1.人类决策权威：人类要能随时看到、批准或否决智能体的操作
2.安全、隐私与数据保护：即使人类不注意，系统也要能自己保护用户及其代码和数据
3.可靠执行：智能体做的事要和人类想的一致，长时间运行也不能走偏
4.能力放大：系统要让人类能做到以前做不到的事
5.上下文适应性：系统要能适应用户的具体项目、工具、习惯，并随使用时间逐步改善
在此基础上，论文从官方文档和社区分析中总结出十三条设计原则（Design Principles），例如“拒绝优先（Deny-First）”“渐进式信任（Graduated Trust）”“纵深防御（Defense in Depth）”“最小脚手架、最大操作Harness（Minimal Scaffolding, Maximal Operational Harness）”等。
但论文发现，这些设计哲学之间存在部分矛盾。例如：
•	人类决策权威vs.安全
根据Anthropic的分析[1]，用户批准了约93%的权限弹窗，频繁的审批点击导致用户对授权内容的注意力下降。因此安全不能完全依赖人类审批，系统需要有自己的防护机制。
•	安全vs.能力
严格的安全检查会带来性能代价。安全研究机构Adversa.ai [2]发现，当一条命令包含50个以上子命令时，如果逐条做拒绝规则检查会导致界面冻结。于是系统选择保持响应速度，退化为单条审批，放弃了逐条检查。这说明在性能压力下，多层安全防御可能被迫让位于可用性。
•	可扩展性vs.安全
丰富的扩展能力会扩大攻击面。Check Point Research的安全研究[3]发现，Hooks和MCP扩展在信任对话弹出之前就会加载，这个时序窗口被已披露的安全漏洞（CVE-2025-59536、CVE-2026-21852）所利用。扩展性越强，提前加载的代码越多，可被攻击的窗口也就越大（这些漏洞已在披露后数周内修复）。
这些矛盾更像是同时追求多条设计哲学所带来的取舍，而非设计缺陷；类似的权衡在其他智能体系统中也可能出现。
观察二：“最小脚手架、最大操作Harness”
  △ 图1：Claude Code的高层系统结构
系统由七个功能组件构成：用户、接口层、智能体循环、权限系统、工具、状态与持久化、执行环境。
这里的“脚手架”（Scaffolding）是指约束和引导模型决策的规划框架，“操作Harness”则是围绕模型运行的基础设施。对源码的分析显示，Claude Code的绝大部分代码是确定性基础设施（权限检查、工具路由、上下文管理、错误恢复），AI决策逻辑只占约1.6%。核心的智能体循环（Agentic Loop）是一个持续迭代的过程：调用模型、获取工具调用请求、执行、返回结果，直到模型停止请求。
在智能体工程领域，存在不同的设计取向。一些框架（如LangGraph [8]）将决策逻辑编码为显式的状态图，而Claude Code选择了另一条路：不硬性规定模型的决策路径，而是给模型较大的决策自由度，同时用确定性代码保障安全执行。
论文的分析指出，随着前沿模型在编码能力上趋同，围绕模型的操作Harness的质量可能成为产品差异化的重要因素。
•	用户请求执行流程
  △ 图2：智能体循环的多轮迭代过程。
用户输入经过上下文装配进入循环：模型产出工具调用请求，由权限系统判定，允许则执行，拒绝则把反馈返回模型重试；遇到上下文压力时会触发压缩。循环持续直到模型不再请求工具，输出最终回复给用户；用户继续对话则再次进入新一轮循环。
上面两节讨论了“为什么这样设计”，接下来看“具体怎么运行”。论文用一个“运行示例”串起各个架构层级：假设输入“帮我修复auth.test.ts里失败的测试”，系统会先组织上下文（加载CLAUDE.md项目指令、对话历史、工具定义、git状态等），然后在每轮模型调用前执行上下文压缩管道。在调用模型之前，权限系统已经通过工具预过滤移除了被禁止的工具。模型在可见的工具范围内决定要调用哪些工具后，权限系统再次判断具体操作是否允许执行。通过后工具执行，结果喂回模型，进入下一轮循环。子智能体委派也是通过Agent工具在这个循环中触发的。
这个循环涉及以下几个重要的架构层面：

1. 权限机制
  △ 图3：权限系统的决策结构。
每次工具调用都要经过权限系统的判定，系统内置多层安全机制，最终结果分为三种：允许则放行执行，拒绝则直接返回，询问则交由用户或自动分类器裁决。
系统设计了七层独立的安全机制，包括工具预过滤、拒绝优先规则、权限模式、ML分类器（Auto-Mode Classifier）、沙箱隔离、恢复会话时不继承旧权限，以及Hooks拦截。并非每次操作都会触发全部七层。例如，ML分类器仅在auto mode开启时生效，沙箱仅针对Shell命令且需全局启用，Hooks拦截则取决于用户是否配置了相应的Hook。但在适用的层上，任何一层都可以单独否决操作（不过论文也指出，在性能压力下这些层可能共享失败模式）。
2. 上下文管理

随着对话推进，上下文窗口（Context Window）里的内容不断膨胀。为了不超出token预算，系统设计了五层上下文压缩（Context Compaction）：预算裁剪（始终生效）、历史修剪（Snip）、微压缩（Microcompact）、上下文折叠（Context Collapse）、自动摘要（Auto-Compact，默认开启）。其中历史修剪和上下文折叠受feature flag控制，不一定在所有版本中都启用。这五层在每轮模型调用前顺序评估，各层独立判断是否需要触发，从轻量裁剪到模型生成摘要，压缩力度逐层递增。
3. 可扩展性

模型能用的工具不只是内置的那些。Claude Code提供了四种主要的扩展机制：MCP服务器负责接入外部工具和资源，技能（Skills）负责注入领域指令，Hooks提供覆盖工具调用、会话生命周期、上下文管理等多个维度的事件拦截点，插件（Plugin）则是一个打包分发格式，可以将上述机制以及命令、智能体定义等多种组件捆绑为可安装的扩展包。不同机制对上下文窗口的消耗不同，开发者可以根据场景选择合适的扩展方式。
4. 子智能体的委派与编排

模型可以通过调用Agent工具派出子智能体（Subagent）去完成子任务。系统内置了多种子智能体类型（如专注探索的Explore、专注规划的Plan等），也支持用户自定义。子智能体默认在独立的上下文窗口中工作，隔离模式包括进程内隔离（默认，共享文件系统但上下文独立）、git worktree隔离（获得独立的文件系统副本）等。完成后只把最终回复返回给父智能体。在Agent teams场景中，系统通过文件锁机制来协调多个智能体之间的任务分配。
观察三：与OpenClaw的对比：同样的设计问题，不同的解答
论文不只分析了Claude Code，还和近期在开源社区迅速走红的智能体系统OpenClaw[6]做了六个维度的对比。OpenClaw是一个个人助手网关，支持WhatsApp、Telegram、Slack等多种平台接入。两个系统面对同一组设计问题，给出了显著不同的答案：
•	Claude Code对每次工具调用做逐操作安全评估，OpenClaw做边界级访问控制
•	Claude Code的智能体循环是系统的中心，OpenClaw的智能体循环只是网关里的一个组件
•	Claude Code的扩展修改的是单个上下文窗口，OpenClaw的插件扩展的是整个网关的能力面
•	两者还能组合使用：OpenClaw可以通过ACP（Agent Client Protocol，智能体客户端协议）把Claude Code作为外部编程Harness接入。这说明智能体的设计空间不是简单的非此即彼，而是一个可以分层组合的结构，网关级系统和任务级Harness可以叠加使用。
观察四：对长期生产力与代码质量的潜在影响
除了架构层面的分析，论文还从另一个角度审视了智能体系统：AI智能体带来的生产力提升是否如感知中那样真实？是否会在代码质量和长期可维护性上付出代价？
论文在讨论中引用了多项针对同类AI编程工具的研究：
•	一项对16名资深开发者、246个任务的随机对照实验[4]发现，使用AI工具的组实际完成速度慢了19%，但自我感知却快了20%
•	对807个代码仓库的因果分析[5]发现，使用Cursor后代码复杂度上升了40.7%

论文指出，未来的智能体系统可以将这个“可持续性缺口”纳入系统设计的考量，而不只是作为事后评估的指标。

Part 2
六个开放的未来方向


论文梳理了六个有待进一步研究的方向：
1.静默失败与可观测性、评估之间的差距：智能体的主要失败模式不是崩溃，而是在无人察觉的情况下产出错误结果。如何弥合可观测性和实际评估之间的差距？
2.记忆持久化与人机长期协作：如何让智能体与用户之间的工作关系有效、稳定地跨越多次对话持续积累？
3.Harness边界的演化：智能体在哪里运行、何时行动、操作什么对象、与谁协作，这四个维度都在快速扩展。
4.时间跨度的扩展：智能体能否从单次对话级别扩展到持续数天乃至数周的科研级任务？
5.治理与监管：随着EU AI Act等法规生效，智能体架构需要提供哪些审计与透明度接口？
6.对人类长期能力的影响：上述可持续性问题能否从事后评估指标提升为系统设计目标？

Part3
对AI开发者和研究者的启示


第一，论文提供了一种从设计哲学出发分析智能体架构的视角，将具体的实现选择追溯到背后的设计哲学和设计原则，而不是停留在“怎么实现的”层面。
第二，论文展示了智能体设计中多种价值之间的权衡：安全与效率、人类控制与自动化、可扩展性与安全性之间往往存在取舍，理解这些权衡有助于做出更清醒的架构决策。
第三，论文指出了当前智能体系统尚未解决好的几类问题，如跨会话记忆、静默失败检测、治理合规等，为未来的研究和开发提供了方向。
第四，论文还关注了一个技术之外的问题：智能体带来的短期效率提升是否真实？是否会在代码质量和长期可维护性上付出代价？

*相关链接：GitHub项目主页https://github.com/VILA-Lab/Dive-into-Claude-Code；论文下载https://arxiv.org/abs/2604.14228；代码与数据https://github.com/VILA-Lab/Dive-into-Claude-Code
References：[1] Anthropic. Claude Code Auto Mode: A Safer Way to Skip Permissions. https://www.anthropic.com/engineering/claude-code-auto-mode
[2] Adversa.ai. Critical Claude Code Vulnerability: Deny Rules Silently Bypassed Because Security Checks Cost Too Many Tokens. https://adversa.ai/blog/claude-code-security-bypass-deny-rules-disabled/
[3] Donenfeld, A. & Vanunu, O. Caught in the Hook: RCE and API Token Exfiltration Through Claude Code Project Files. Check Point Research. https://research.checkpoint.com/2026/rce-and-api-token-exfiltration-through-claude-code-project-files-cve-2025-59536/
[4] Becker, J. et al. Measuring the Impact of Early-2025 AI on Experienced Open-Source Developer Productivity. arXiv:2507.09089. https://arxiv.org/abs/2507.09089
[5] He, H. et al. Speed at the Cost of Quality: How Cursor AI Increases Short-Term Velocity and Long-Term Complexity in Open-Source Projects. arXiv:2511.04427. https://arxiv.org/abs/2511.04427
[6] Steinberger, P. & OpenClaw Contributors. OpenClaw: Personal AI Assistant. https://github.com/openclaw/openclaw
[7] Anthropic. How Claude Code Works. https://code.claude.com/docs/en/how-claude-code-works
[8] LangChain, Inc. LangGraph: Build Resilient Language Agents as Graphs. https://github.com/langchain-ai/langgraph
*头图及封面图来源于ivy

