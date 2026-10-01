---
name: cangjie-build-diagnose
description: "提供仓颉项目构建与运行故障诊断文档，包括cjc/cjpm编译报错诊断与修复/运行时异常定位与修复/CFFI与链接故障/编译器崩溃/SDK版本回归/问题复现与验证等"
---

请按需查询当前目录下的仓颉构建诊断文档：

[编译修复](./references/compile-fix.md)：cjc/cjpm 编译失败的诊断与修复，包括类型转换与 Option、语法/声明/表达式、函数/Lambda/重载、class/struct/interface、match 模式匹配、包/导入/可见性、宏展开、CFFI/链接/目标架构、cjpm 配置/依赖/构建上下文，以及编译器崩溃和 SDK 版本回归等。

[运行时异常](./references/runtime-exception.md)：运行时异常与执行故障的定位和修复，包括 Option 缺省、输入与状态契约、数值/Range/集合边界、异常传播、Future 生命周期、同步与并发、Resource/文件/流、CFFI/unsafe 原生故障，以及 Error、崩溃和平台边界等。
