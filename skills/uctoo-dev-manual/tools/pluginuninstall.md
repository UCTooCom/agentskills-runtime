# pluginuninstall 使用手册

## 概述

`pluginuninstall` 是 agentskills-runtime 的插件卸载工具，与 `plugingen` 对称的确定性卸载工具，实现三层卸载模型。

**源码位置**：`src/plugin/tools/pluginuninstall/pluginuninstall.cj`

## 用法

```bashcjpm run --skip-build --name magic.plugin.tools.pluginuninstall --run-args "--name <插件名> [--force]"```

## 选项

| 选项 | 说明 |
|------|------|
| `--name <插件名>` | 指定要卸载的插件名 |
| `--force` | 强制级联卸载（按依赖逆序先卸载所有依赖方插件） |
| `--help, -h` | 显示帮助信息 |

## 示例

```bash
# 卸载指定插件cjpm run --skip-build --name magic.plugin.tools.pluginuninstall --run-args "--name entity"
# 强制级联卸载（先卸载所有依赖方插件）cjpm run --skip-build --name magic.plugin.tools.pluginuninstall --run-args "--name entity --force"```

## 三层卸载模型

| 层 | 操作 | 说明 |
|----|------|------|
| 运行时层 | `PluginManager.deactivate(pluginName)` | 停用运行时实例 → 触发 `onDeactivate` → `onUnload` → 逆序执行 `PluginContext.onCleanup` 清理栈 |
| 静态资产层 | 删除 `skills/{name}/` 源目录 | 删除 build-sync 同步产物 → 删除编译产物 → 从 `config/plugins.yaml` 移除条目 → 从 `generated_anchors.cj` 移除反射锚点 |
| 数据库痕迹层 | 清理 `agent_skills` 表 | 清理 `permissions` 表菜单节点 → 清理 `i18` 表国际化键 |

## 卸载安全机制

- **依赖检查**：卸载前检查是否有其他插件依赖该插件（`@Plugin.dependencies` 中声明），有依赖则拒绝卸载并提示依赖方插件名，或提供 `--force` 级联卸载
- **活跃 run 检查**：卸载有活跃业务请求的插件前，等待 in-flight 请求完成或提供 `--force` 强制中断
- **卸载幂等性**：重复卸载同一插件不应报错或产生副作用

## 与 plugin_deactivate 的关系

- `plugin_deactivate`：运行时停用（可重新激活），属 Agent 工具
- `pluginuninstall`：完整卸载（文件资产一并清理，需重新 plugingen 生成），属 CLI 工具

两者职责正交，不可混用。
