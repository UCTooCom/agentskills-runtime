# Agent 开放标准

Agent 开放标准是一个简单、开放的格式，用于声明和管理 AI Agent 的元数据、行为规范和协作关系。

Agent 是包含 `AGENTS.md` 文件的目录或独立声明文件，定义了 Agent 的身份、能力、工具、模型、权限等元数据，以及行为指令和协作模式。声明一次，运行处处兼容。

## 核心特性

- **元数据声明**: 通过 YAML frontmatter 声明 Agent 的身份、类型、能力、工具、模型等属性
- **文件系统-数据库双向同步**: Agent 声明文件与数据库自动同步，支持声明式管理和运行时查询
- **多 Agent 协作**: 支持链式、并行、分层等协作模式，实现 Agent 集群
- **完整加载**: Agent 声明在加载时完整提供大模型全部信息，确保身份、行为指令和协作关系完整可用
- **权限集成**: 与 RBAC 权限体系深度集成，精细控制 Agent 的数据访问权限

## 标准文档

| 文档 | 说明 |
|------|------|
| [规范](specification.mdx) | AGENTS.md 格式的完整规范定义 |
| [什么是 Agent](what-are-agents.mdx) | Agent 的概念、工作原理和核心价值 |
| [集成 Agent](integrate-agents.mdx) | 如何将 Agent 标准集成到你的系统 |
| [文件系统-数据库同步](filesystem-database-sync.mdx) | 文件系统与数据库双向同步规范 |

## 与 Agent Skills 的关系

Agent 开放标准与 [Agent Skills 开放标准](https://agentskills.io) 互补：

- **Agent Skills** 定义了技能（Skill）的格式——Agent 可以做什么
- **Agent 开放标准** 定义了 Agent 本身的格式——Agent 是谁、如何组织、如何协作

两者共同构成完整的 AI Agent 生态标准体系。

## 许可证

本标准文档采用 [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/) 许可证。