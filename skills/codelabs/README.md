# codelabs 插件（L3 进程隔离轨）

独立 cjpm executable 工程，对标 DeepSeek Harness Cordis 的进程隔离插件轨。

## 编译

```bash
cd ./skills/codelabs
cjpm build
```

产物：`target/release/skill_codelabs.exe`

## 登记到宿主

在宿主 `config/plugins.yaml` 追加：

```yaml
plugins:
  - name: codelabs
    mode: process
    command: ./skills/codelabs/target/release/skill_codelabs.exe
    enabled: true
    autoRestart: true
```

## 约束

- 依赖仅 `ystyle::cordis_plugin` + `jsonvalue`（+仓颉标准库）——零 magic 包依赖
- 禁用 `@Plugin` 宏：用显式 API `PluginRuntime.run(...)`
- 数据访问一律经 `host.db` 服务代理（不直连数据库）
- 独立 `cjpm build` 产出可执行文件，放置 + plugins.yaml 登记即生效
