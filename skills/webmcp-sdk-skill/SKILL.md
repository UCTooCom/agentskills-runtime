---
name: webmcp-sdk-skill
description: 指导如何使用 WebMCP SDK库去开发WebAgent的技能包，将前端应用快速智能化。它包含 TinyRemoter，WebMcpServer，WebMcpClient，createRemoter， AI-Extension插件开发的文档及指南。
license: MIT
metadata:
  author: opentiny
  version: '1.0.0'
---

# WebMCP SDK 使用助手

**WebMCP-SDK** 是一套前端智能应用开发工具包，曾用名称`NEXT-SDKs`也是同一个库。 它旨在简化 WebAgent 的集成与使用，内置了 Vue 版本的`TinyRemoter`组件和 WebMcpServer，WebMcpClient 等重要的类。

## 安装方式

用户使用 WebMCP-SDK 库，需要安装 `@opentiny/next-sdk` 的 npm 包。
用户使用 TinyRemoter 组件，需要安装 `@opentiny/next-remoter` 的 npm 包。

## 使用方法

根据任务类型，查阅对应的规则文档并严格遵循规范：

| 规则文档                                                      | 适用场景                                                    |
| ------------------------------------------------------------- | ----------------------------------------------------------- |
| [快速开始](rules/index.md)                                    | WebMCP-SDK 库和 TinyRemoter 的入门指南                      |
| [接入三方 AI 应用](rules/mcp-host.md)                         | 如何在各类 IDE 开发软件中，配置 mcpservers                  |
| [Electron 应用接入](rules/electron.md)                        | 如何在 Electron 工程中接入 WebMCP-SDK                       |
| [uni-app 应用接入](rules/uni-app.md)                          | 如何在 uni-app 工程中接入 WebMCP-SDK                        |
| [本地连接](rules/connect-local.md)                            | 如何支持 iframe 方式接入 WebMCP-SDK 库                      |
| [WebAgent 私有化部署](rules/web-agent-private-deployment.md)  | WebAgent 私有化部署用户指导书                               |
| [总览](rules/webmcp-webskills.md)                             | WebMCP + WebSkills：企业级智能化页面操控方案                |
| [Vue 工程最佳实践](rules/vue-webmcp-best-practice.md)         | Vue 工程的 WebMCP + WebSkills：企业级智能化页面操控方案     |
| [Angular 工程最佳实践](rules/angular-webmcp-best-practice.md) | Angular 工程的 WebMCP + WebSkills：企业级智能化页面操控方案 |
| [React 工程最佳实践](rules/react-webmcp-best-practice.md)     | React 工程的 WebMCP + WebSkills：企业级智能化页面操控方案   |
| [WebMcpClient 类](rules/api-client.md)                        | WebMcpClient 的完整文档                                     |
| [WebMcpServer 类](rules/api-server.md)                        | WebMcpServer 的完整文档                                     |
| [AgentModelProvider 类](rules/api-agentModelProvider.md)      | AgentModelProvider 的完整文档                               |
| [createRemoter 函数](rules/api-createRemoter.md)              | createRemoter 的完整文档                                    |
| [工具函数](rules/api-tools.md)                                | WebMCP-SDK 库中导出的重要函数的完整文档                     |
| [TinyRemoter 文档](rules/tiny-robot-remoter.md)               | TinyRemoter 的完整文档                                      |
| [Skills 技能配置指南](rules/tiny-remoter-skills.md)           | WebSkills 的规范以及如何配置给 TinyRemoter 使用             |
| [Custom llm 自定义大模型](rules/custom-llm.md)                | TinyRemoter 的 llmConfig 和 agentRoot 自定义配置的文档      |
| [自定义 AI 对话框组件](rules/use-next-agent.md)               | useNextAgent 的使用文档，以及如何接入其它厂商的 UI          |
| [技术架构](rules/ai-extension-architecture.md)                | AI-Extension 浏览器插件技术架构文档                         |
| [MCP Servers 工具开发指南](rules/ai-extension-next-wxt.md)    | AI-Extension 中的 mcp-servers 开发指南                      |
| [Skills 技能开发指南](rules/ai-extension-skills.md)           | AI-Extension 中的 Skills 技能开发指南                       |
| [AI Extension 插件安装指南](rules/ai-extension-install.md)    | AI Extension 扩展插件安装指南                               |
| [配置大模型](rules/ai-extension-model-config.md)              | AI Extension 中，如何自定义 AI 大模型配置指南               |
