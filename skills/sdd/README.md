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
| `templates/` | 文档模板（实体复制，插件自完备，不依赖目录外文件） |
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
- 阶段文档落 runtime 自有 `specs/{feature_name}/`，禁落 `.codeartsdoer/specs/`。

## 相关文档

- `OPS.md` —— 部署、排障、防回退对照
- `.codeartsdoer/specs/sdd/` —— spec / design / research / tasks 账本
- `docs/agents/agent-declaration-spec.md` —— Agent 声明规范（含"技能内 agents 目录约定"章）
