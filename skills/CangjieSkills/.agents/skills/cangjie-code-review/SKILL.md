---
name: cangjie-code-review
description: "提供仓颉代码审查与优化文档，包括高性能编码与性能优化/OOM与RSS增长取证/堆增长与内存泄漏分析/资源释放与内存优化/基准测试/CPU热点/延迟与吞吐/问题修复与验证等"
---

请按需查询当前目录下的仓颉代码审查文档：

[性能优化](./references/performance-optimization.md)：高性能仓颉编码与可比测量，包括算法复杂度、集合访问模式、StringBuilder 与 Unicode、热点临时分配与复制、Lambda/闭包热路径、缓存与预计算、spawn/Future 与同步、I/O 批处理、CFFI 跨语言边界、class/struct 与 Any 数据表示、背压和协作取消，以及 cjprof 路由等。

[内存优化](./references/memory-optimization.md)：释放或 GC 后仍跨轮持续增长的内存问题，包括 OOM、仓颉堆与 RSS 趋势、缓存和集合无界增长、长期强引用、WeakRef、闭包/回调、Future/ThreadLocal，以及句柄和 CFFI 原生内存等。
