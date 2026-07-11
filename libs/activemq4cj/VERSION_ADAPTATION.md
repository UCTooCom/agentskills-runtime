# 版本适配变更日志 - activemq4cj

## 上游信息
- 上游仓库：gitcode.com/Cangjie-TPC/activemq4cj
- 上游分支：main
- 上游版本：1.0.0
- 适配目标：仓颉 SDK 1.0.4

## 变更记录

### 1. cjpm.toml
- **变更内容**：cjc-version 从 "1.0.0" 更新为 "1.0.4"；hyperion 依赖从 git 远程方式改为 path 本地依赖（`hyperion = { path = "../hyperion" }`）；stdx 路径从 CANGJIE_STDX_PATH 环境变量改为相对路径；compile-option 设为 "-Woff all" 抑制警告
- **适配原因**：适配仓颉 SDK 1.0.4 版本，采用本地 libs 依赖方式
- **变更日期**：2026-07-10

### 2. 源码适配
- **变更内容**：无需修改。activemq4cj 源码在仓颉 SDK 1.0.4 下编译直接通过，无编译错误（仅有 unused variable 警告，已通过 -Woff all 抑制）
- **适配原因**：activemq4cj 源码兼容仓颉 SDK 1.0.0 和 1.0.4
- **变更日期**：2026-07-10