# RuntimeNativeInstaller 补充研究（五）：发布形式与消费形式

> **文档类型**：SDD research 补充章（第五份）
> **日期**：2026-10-07
> **触发**：用户提出三项追问 —— ① 仓颉原生安装器以什么形式发布？② 谁消费、怎么消费？③ PC 客户端（`apps/pc-client`）能否复用、如何集成？④ `apps/web-admin` 能否完全替代 `nestJs` 旧安装器？
> **性质**：**补充研究**，不修改前文 REQ/AC。本章发现的**新增缺口**需经用户确认后追加 REQ。
> **证据纪律**：本章所有数字与结论均来自**本机文件实测或源码行号取证**，脚本可复现；凡未取证的一律标为待确认，不写成事实。

---

## 零、结论摘要（先看这个）

| 问题 | 结论 | 依据 |
|---|---|---|
| **安装器怎么发布？** | **不新建发布渠道**，而是作为**构件挂进既有 runtime 发布管线**：产物放入 `release/agentskills-runtime-win-x64.tar.gz` 的 `release/bin/` 内，随 runtime 一同打出、一同上传到 AtomGit Release。**这一步是全部复用方案的枢纽** —— PC 客户端早已 bundle 这个 tar.gz（§4.1），安装器一旦进去，PC 端**零改动即自动获得** | §2.2 / §4.1 |
| 除此之外还要别的形态吗？ | 需要**两条补充轨道**：D2 独立 zip（给纯开发者二开场景，配合 DK-3 clone）、D3 免 Cinema：直接从 D1 分发。三条轨道**同一份二进制**，不重复编译 | §2.3 |
| **谁消费、怎么消费？** | 三类消费方、三种接口：**人**（HTTP 静态向导，契约不变）、**脚本/CI**（CLI 子命令 + `--json` + 退出码）、**宿主进程**（PC Electron，流式 stdout JSON 进度，**本章新增的能力，当前设计未覆盖**） | §3 |
| **PC 客户端能否复用？** | **能，且应该复用，但不是全盘替换**。PC 保留"壳"（NSIS/更新器/托盘/内嵌 PG 进程管理），把**数据正确性**相关环节（seed 导入、身份绑定、超管+主 agent 二元组、RBAC 补种、`.env` 生成、SSL）交给安装器 | §4.3 |
| PC 复用最紧迫的理由是什么？ | PC 当前导入的 `uctoov4InitData.sql`（2026-04-01）里，**本机超管 uuid `505cf909…` 出现 123 次**、本机超管角色 uuid 出现 2 次，而**主 agent uuid 出现 0 次**。也就是说：**现在每装出一台 PC 客户端，都得到一个"创建者全是 Patrick 本机账号"、且没有主 agent 账号的库** —— 这正是 Seed Identity Contract 要根治的问题，且是危害面最大的一处 | §4.2 |
| **能否完全替代 nestJs？** | **能替代其"安装引导"职责，但不能原地消失**。`nestJs/INSTALL_README.md:20-22` 说"安装完成后 NestJS 可以停止"，**这句话与实际不符**：`src/views/setup.vue` 是常驻的系统管理页（环境检测/配置管理/服务监控/日志查看四个 Tab + 重启/停止服务按钮），它通过 `/api/setup/*` 长期依赖 `:3000`。安装器自退役后若无人接手，这四个管理面板会一起失效 | §5.2 |
| 那怎么办？ | 三条路线：**M1** 安装器常驻管理（等价于换壳的 nestJs，**不推荐**）；**M2** runtime 原生承接 `/setup/*`（最干净，但触不触碰冻结的 `src/app/` 需用户拍板）；**M3** 安装期自退役 + 运维期按需拉起管理后端（**推荐**，最小改动、保留"零常驻"卖点） | §5.3 |

---

## 一、为什么"发布形式"这个问题值得单独研究

因为安装器**不是一个孤立产品**，它站在两条既有发布管线的交汇点上：

| 管线 | 产物 | 服务对象 |
|---|---|---|
| **runtime 发布管线** | `release/agentskills-runtime-win-x64.tar.gz` | PC 客户端、直接部署者、SDK 下载器 |
| **PC 客户端发布管线** | NSIS 安装包 + Portable 绿色版 | 终端用户 |

安装器如果自己另起一条发布管线，就会出现三份二进制、三个版本号、三次上传 —— 而**它的全部价值恰恰在于把这批二进制正确拼装起来**。所以结论必须反过来想：**安装器应该是"发布管线的产物"，而不是"新的产品线"**。

---

## 二、发布形式

### 2.1 现状取证：runtime 发布管线长什么样

**入口脚本** `apps/agentskills-runtime/build_and_release.ps1`（224 行，实测读取）：

| 步骤 | 行号 | 动作 |
|---|---|---|
| 版本号解析 | `:26-42` | 未传 `-Version` 时从 `cjpm.toml` 的 `version = "…"` 读取；取不到就 `exit 1` |
| 步骤 1 编译 | `:46-70` | `cjpm build`，失败抛错退出 |
| 步骤 2 打包 | `:74-102` | 优先执行 `target/release/bin/magic.scripts.package_release.exe`；不存在则回落 `cjpm run magic.scripts.package_release` |
| 步骤 3 验证 | `:106-127` | 调用 `verify_package.ps1`（**注意：该文件当前不在仓库根目录，脚本自己会打 WARN 跳过**） |
| 步骤 4 信息 | `:131-149` | 打印 `release/agentskills-runtime-win-x64.tar.gz` 的大小与 **SHA256** |
| 步骤 5 发布 | `:153-215` | `git tag -a v<Version>` → `git push origin <tag>` → **人工**到 AtomGit 创建 Release 并上传文件 |

**产物实测**（`ls -la release/`）：

```
-rw-r--r-- 1 patrick 197121 439483164 Oct  6 22:52 agentskills-runtime-win-x64.tar.gz
```

即 **419 MB**（注意：它与 PC 资源目录里那份 `Oct 8 23:40 / 398829380 B ≈ 380 MB` 是**两次不同导出**，目录里的是上一版，尚未同步 —— 这是一条现实的一致性隐患，见 §2.5）。

**包内结构**（`PACKAGE_RELEASE_GUIDE.md:36-60` 原文摘录）：

```
agentskills-runtime-win-x64.tar.gz
└── release/
    ├── bin/
    │   ├── magic.app.exe             # 主程序
    │   ├── agentskills-runtime.exe   # 入口程序
    │   ├── *.dll                     # 281 个
    │   ├── *.cjo                     # 283 个
    │   ├── .env                      # 配置文件（**注：打包时从本机 .env 复制**）
    │   ├── ssl/                      # server.crt / server.key
    │   └── logs/
    └── VERSION                       # AGENTSKILLS_RUNTIME_VERSION= 行
```

> **判读**：这个包已经是"解压即可运行"的形态（`release/bin/` 下 exe + DLL + CJO + `.env` + ssl 齐全），PC 端也正是按这个约定消费的（`runtime-integrator.ts:58` 校验 `runtimeHome/<plat>/release/bin/agentskills-runtime.exe`）。

### 2.2 建议：安装器作为发行包内的一个构件（D1 轨道，最高优先）

**做法**：`package_release.cj` 在复制 `bin/` 内容时，把 `installer/target/release/bin/ucInstaller.exe` 一并列进去，最终形态：

```
release/
├── bin/
│   ├── agentskills-runtime.exe
│   ├── magic.app.exe
│   ├── ucInstaller.exe          ← 【新增】
│   ├── libcrypto-3-x64.dll      ← 安装器与 runtime 共用同一批 DLL
│   ├── libssl-3-x64.dll
│   └── …（其余 DLL / CJO 不变）
├── assets/install/{install.html, install.js, install.css}   ← 【新增】向导静态资源
├── .env
├── ssl/
└── VERSION
```

**为什么这是关键一步**：

1. PC 客户端的 `electron-builder.json:58-62` 已经把整个 `runtime/*.tar.gz` 作为 `extraResources` 打包进安装包。**安装器放进 tar.gz，就等于免费发给每一台 PC 客户端**，无需 PC 端改一行配置。
2. 安装器所需的 DLL（`libcrypto-3-x64.dll` / `libssl-3-x64.dll` 等 stdx 运行时）**与 runtime 完全同源**，同目录放置即可复用，不必再单独 copying 一份（`design.md:1141` 已写明"所有 DLL 与 exe 同目录，避免 PATH 依赖"）。
3. **版本天然绑定**：安装器和 runtime 在同一份 `VERSION` 下发布，不会出现"安装器 v1.2 配 runtime v1.1"的错配 —— 这是自解压类安装包常见的事故来源。

**代价**：tar.gz 体积增加。安装器本体预计 **10~25 MB**（含静态资源与 stdx 依赖），相对 419 MB 的 runtime 包约 **+3%~6%**，可忽略。

### 2.3 三条分发轨道

| 轨道 | 形态 | 来源 | 目标消费方 | 说明 |
|---|---|---|---|---|
| **D1 随 runtime 发行包**（**主**） | `ucInstaller.exe` 位于 tar.gz 内 `release/bin/` | §2.2 | PC 客户端、直接部署者 | **零额外分发成本**；版本与 runtime 强绑定 |
| **D2 独立安装器包** | `ucInstaller-win-x64.zip`（exe + assets + DLL，约 15~30 MB） | 同一次编译，单独压缩 | **开发者**（二开场景，配合 DK-3 `git clone`） | 开发者往往已在 AtomGit Release 页面，顺手下载；不需要拖 419 MB 的 runtime |
| **D3 免分发（推荐给 PC）** | 不单独出包 —— PC 从 D1 的 tar.gz 里取 | D1 | PC 客户端 | 避免同一份二进制在安装包里存两份（400 MB 量级，重复一次就是实打实的容量浪费） |

> **同一份二进制三条轨道**：不做三次编译、不打三个版本号。唯一的版本号以 runtime `cjpm.toml` 为准。

### 2.4 版本与校验

- `VERSION` 文件已是既有契约：`AGENTSKILLS_RUNTIME_VERSION=<x.y.z>`（`runtime-integrator.ts:86-93` 与 `design.md:1259` 都按此行解析）。安装器**沿用同一行**，不新增字段。
- 安装器需支持 `ucInstaller.exe --version` 打印该版本号，便于 PC 侧做兼容性判断（避免出现"新 runtime / 旧安装器"组合时静默失败）。
- PC 侧在集成时应把 `ucInstaller.exe` 的实际路径写回 `runtime/<plat>/release/bin/`，使 `runtimeVersionDetector` 等既有模块无需改动即可发现它（**待确认 OQ-D2**：PC 是否愿意把安装器放在 runtime bin 目录内）。

### 2.5 顺带发现的现实隐患 N-1

`release/agentskills-runtime-win-x64.tar.gz`（**Oct 6 22:52 / 419 MB**）与 `apps/pc-client/resources/runtime/agentskills-runtime-win-x64.tar.gz`（**Oct 8 23:40 / 380 MB**）**不是同一份文件**（大小差 39 MB）。

照 `pc_desktop_client/design.md:2379` 的流程，这一步是**人工复制**：

```
cp apps/agentskills-runtime/release/agentskills-runtime-win-x64.tar.gz
   → apps/pc-client/resources/runtime/
```

**结论**：把安装器放进 tar.gz 之后，这条手工链路必须同步升级 —— 否则会出现"PC 安装包里是旧 runtime + 没有安装器"的典型不一致。建议在 D1 落地的同时把这条复制动作收进脚本（详见 OQ-D3）。

---

## 三、消费形式：三类消费方，三种接口

### 3.1 现状：当前设计只有一种接口

`design.md` §3 / §4.12 定义的形态是**单个自托管 HTTP 服务**：`ucInstaller.exe` 起在 `:3000`，自托管静态向导 `assets/install/`，"runtime 健康后自退役"。这是一个**给人用的接口**。

但三处消费场景里，只有一处需要 UI：

| 消费方 | 需要的形态 | 当前设计是否覆盖 |
|---|---|---|
| **① 终端用户**（浏览器向导） | HTTP + 静态页 | ✅ 已覆盖（17 端点契约） |
| **② 脚本 / CI / 自动化** | CLI 子命令 + `--json` + 退出码 | ⚠️ 部分：`design.md` §4.11 有 `--json` 与退出码，但**没有明确的一等 CLI 子命令清单**（`db export` 仅在 OQ-S4 中建议） |
| **③ PC Electron 宿主进程** | 子进程 + **流式进度** + 结构化结果 | ❌ **未覆盖** |

### 3.2 接口一：HTTP 静态向导（给人）

契约不变（`research.md` §1.2 的 17 端点真值表）：端口 `:3000`、`GET /healthCheck` 严格返回 `success`、CORS `*`。

**新增约束（来自 PC 集成）**：必须支持 `--no-serve`（或等价开关），使安装器在宿主进程模式下**完全不起 HTTP 端口**。理由：PC 客户端已有自己的 UI（SetupView），若安装器同时开 `:3000` 并让用户用浏览器操作，会出现"两个安装向导打架"的最差体验；且 `:3000` 与新环境的 runtime 端口存在抢占风险。

### 3.3 接口二：CLI 子命令 + `--json`（给脚本/CI）

建议固化为一等接口（补齐当前缺口）：

```
ucInstaller.exe install   [--json] [--install-root <dir>] [--no-serve] [--auto-exit]
ucInstaller.exe devkit    install|verify  [--json] [--source-dir <dir>]
ucInstaller.exe seed      apply|verify|export  [--json] [--db <name>]
ucInstaller.exe db        export|import  [--json]
ucInstaller.exe --version
```

判据：任何子命令加 `--json` 后，**stdout 只输出一行 JSON**（已有契约：`design.md` §4.11），人读信息一律走 stderr；退出码表保持既有定义。

> **注意跨工程红线**：L3 插件进程的 stdout 是 stdio RPC 独占通道 —— 这条红线属于**插件**，不适用于独立 exe 安装器，但如果将来把导出命令做成 runtime 工具（`cjpm run --name …`），则必须遵守（这也是 OQ-S4 建议做成安装器子命令而非 runtime 工具的原因之一）。

### 3.4 接口三：流式机器契约（给 PC Electron）—— 本章新增

PC 集成需要的不是"跑完给个结果"，而是**实时进度**（解压 / 初始化 / 导入数据 / 建账号各占多少百分比）。当前设计里 `--json` 是**结束才输出一行**，满足不了。

建议契约（**新增能力，需用户确认后追加 REQ**）：

```
ucInstaller.exe install --install-root <dir> --no-serve --progress=ndjson
```

- stdout **每行一个 JSON 对象**（NDJSON，UTF-8，`\n` 结尾），形如：
  ```json
  {"ts":"2026-10-07T14:20:31Z","phase":"S4","phaseName":"初始化数据库","state":"running","percent":42,"message":"正在导入 permissions …"}
  {"ts":"…","phase":"S4","state":"ok","percent":100}
  {"ts":"…","state":"final","exitCode":0,"summary":{…}}
  ```
- **最后一行**为终结事件，含 `exitCode` 与摘要（复用 `--json` 的报告结构），宿主进程据此判定成败。
- **stdout 只允许这一种输出**；诊断日志走 stderr（与既有跨工程红线一致：`plugin` 进程 stdout 是协议通道）。
- `--progress=ndjson` 与 `--json` 互斥：前者流式，后者单行。

**为什么值得做**：这一条接口同时服务于三类宿主 —— PC Electron、未来的其它 GUI 外壳、（可选）远程运维 Agent。做一次，处处可用。

---

## 四、PC 客户端（`apps/pc-client`）能否复用？

### 4.1 现状取证：PC 已经自己做了一遍"runtime 环境准备"

规格 v2.5（`pc_desktop_client/design.md:9` 变更说明原文）：PC 端已自行实现了 runtime 的整体集成，第 (5)(6)(7)(8) 条尤其明确。抽取关键事实：

**打包形态**（`electron-builder.json` 实测）：

| 维度 | 值 |
|---|---|
| 目标 | Windows **`nsis` + `portable`**（`:71-83`）、macOS `dmg`、Linux `AppImage` |
| extraResources | `pgsql/bin`、`pgsql/lib`、`pgsql/share`、`sql`、`web-admin`、`openssl`、`defaults`、`tray-icon.png`、`runtime/*.tar.gz`（`:18-63`） |
| 更新源 | `"provider": "generic"` → `https://atomgit.com/UCToo/agentskills-runtime-pc/releases/download/${version}/`（`:100-104`） |
| 体积预估 | 安装包 ~600-800 MB，安装后 ~2 GB（`design.md:2414-2429`） |

**已有的五个安装相关模块**（`wc -l electron/modules/*.ts` 实测，共 4135 行）：

| 模块 | 行数 | 职责（依据源码） |
|---|---|---|
| `runtime-integrator.ts` | 212 | 解压 `agentskills-runtime-win-x64.tar.gz` → `%APPDATA%/agentskills/runtime/<plat>/release/`（`:99-160`）；无包时走 SDK 网络下载兜底（`:162-186`，`client.runtime.downloadRuntime()`）；`.env` 由 `.env.example` 复制（`:140-145`） |
| `pgsql.ts` | 526 | 内嵌 PostgreSQL 实例管理：**Step 6 导入 SQL**（`:178-200`） |
| `setup.ts` | 136 | 向导服务：**仅三步** —— `executeDatabaseStep`（内嵌/外部 PG，`:20-99`）、`executeAIStep`（provider+apiKey，`:101-118`）、`completeSetup`（生成 `.env`，`:120-132`） |
| `env-generator.ts` | 262 | `.env` 生成 |
| `dep-manager.ts` | 302 | 环境检测（Node / PostgreSQL / Redis 等） |
| `runtime.ts` | 358 | runtime 进程启停（`index.ts:215-235` 注册了 `runtime:start/stop/restart/status` IPC） |

** PC 端向导当前步数**（`src/views/setup/SetupView.vue:5-6,271-274`）：`totalSteps = 4`，依次为「欢迎 / **AI 配置** / **数据库** / 完成」。

> **判读**：PC 客户端**确实有安装能力**，而且做得不浅（连内嵌 PG 都有了）。但它做的是**"把 runtime 弄起来"**，与我们设计的安装器做的是**"把 runtime 的数据弄对"**——两者是**相邻而不重合**的两件事。

### 4.2 ⚠️ 关键发现 N-2：PC 当前装出来的库，创建者是本项目作者的本地账号

PC 导入的是 `apps/pc-client/resources/sql/uctoov4InitData.sql`（**715,793 B / 2026-04-01**）。实测：

| 项 | 实测值 |
|---|---|
| `CREATE TABLE` 数 | **0**（**纯数据文件，不含表结构**） |
| `INSERT INTO` 数 | 2,514 |
| 本机超管 uuid `505cf909-5e0e-4dde-b215-74274d2cc548` 出现次数 | **123** |
| 本机超管角色 uuid `2338cf7b-82b7-4cf6-b1ae-6a3ca79d683d` | 2 |
| permissions 根 uuid `386b8b46-de88-4caf-b6e3-11f747c85cc0` | 887 |
| 哨兵账号 `00000000-…-0002` / `-0001` | 676 / 279 |
| **主 agent uuid `8803ed58-e72e-4757-9f1e-2852a940e751`** | **0** |
| 文件年龄 | 2026-04-01，比 `sql/public20261007.sql` 早 **6 个月** |

三条推论：

1. **每台安装了 PC 客户端的机器，其数据库里 123 处"创建者"都指向同一个 Patrick 本机账号的 uuid。** 这与 `research-seed-identity.md` §1.3 在 runtime 侧发现的情况如出一辙，但危害面更大 —— 那是开发者环境，这是一键安装的终端用户环境。
2. **`8803ed58…` 出现 0 次 ⇒ PC 装出来的环境没有主 agent 账号。** 而 `AipIdentityService.cj` / `AgentAuthService.cj:39-88` 要求 `user_type='agent'` 且 `agents.status=1` 才能自动登录。**也就是说，PC 安装完成后的首次登录，走的是一条没有 fallback 的路径**（待 PC 侧实测确认，见 OQ-D4）。
3. **这个文件在本仓库有两份完全相同 copy**（`apps/agentskills-runtime/sql/` 与 `apps/pc-client/resources/sql/`，同样 715,793 B / Apr 1），是同一个手工复制问题的又一个例子。

> 这就是"能否复用"的最强答案：**PC 复用安装器不是锦上添花，是修一个正在被分发出去的缺陷。**

### 4.3 建议方案：分层替换，不是全盘替换

| 环节 | 谁做 | 理由 |
|---|---|---|
| NSIS / Portable / dmg / AppImage **打包外壳** | **PC 保留** | electron-builder 是成熟方案，与外壳强耦合；换成别的等于重做安装包 |
| **electron-updater 增量更新** | **PC 保留** | 更新是外壳职责，与安装引导无关 |
| **内嵌 PostgreSQL 实例管理**（`pgsql.ts`） | **PC 保留** | 这是 PC 独有的"开箱即用"卖点；安装器需要的是"拿到可用连接串"，不该去抢进程管理 |
| **托盘 / 窗口 / 崩溃恢复 / 健康轮询**（`tray.ts` / `runtime-crash.ts` / `runtime-health.ts`） | **PC 保留** | 纯 PC 交互 |
| **tar.gz 解压与版本检测**（`runtime-integrator.ts`） | **PC 保留**（但增加一步"把安装器路径告诉安装器"） | PC 已实现且稳定；重做无收益 |
| **依赖检测**（Node/Redis 等） | **交给安装器**（统一一份），PC 的 `dep-manager.ts` 降级为"调用安装器 API 渲染结果" | 避免两套检测规则对不上；这也是 `research.md` 17 端点的既有职责 |
| **`.env` 生成**（`env-generator.ts`） | **交给安装器**（`design.md` §4.8.3 已有行级 in-place 更新实现） | 消重：同一份语义当前存在两份实现（PC 的 `env-generator.ts` 与安装器的 `.env` 写入），规则容易对不上 |
| **SSL/证书** | **交给安装器** | 同属 `setup.controller.ts` 17 端点职责 |
| **数据库结构 + seed 导入（身份绑定）** | **交给安装器**（替换 `pgsql.ts:178-200` 的 `psql -f uctoov4InitData.sql`） | **这是 N-2 的直接修复点** |
| **超管 + 主 agent 二元组建立与 RBAC 补种** | **交给安装器**（A1~A6） | PC **当前完全没做**（`setup.ts` 只有数据库 + AI 两步），是 N-2 第二条缺陷 |

一句话：**外壳不动，数据全交给安装器。**

### 4.4 集成形态：子进程 + NDJSON 进度 + IPC

```
                          SetupView.vue（渲染进程）
                                 ▲  IPC 'setup:installProgress'
                                 │
                          ipcMain handler（electron/modules/setup 扩展）
                                 ▲  child_process.spawn 读 stdout NDJSON
                                 │
              ┌──────────────────────────────────────────┐
              │ ucInstaller.exe install                  │
              │   --install-root %APPDATA%/agentskills/… │
              │   --no-serve --progress=ndjson           │
              └──────────────────────────────────────────┘
                                 │
                        直接操作 PostgreSQL（外部或 PC 内嵌实例）
```

配套改动点（PC 侧）：

1. `SetupView.vue` 的第 3 步「数据库」替换为 **4 步：数据库 → Seed 数据 → 账号建立 → 完成**（`totalSteps` 由 4 改为 5，含现有欢迎步）。
2. `electron/modules/setup.ts` 增加 `install()`：spawn 安装器，逐行解析 stdout，把 `{percent, message}` 转发给渲染进程；最后一行的 `exitCode` 决定成败。
3. **安装器绝不起 HTTP**（`--no-serve`），避免出现两套 UI；`webadmin-server.ts`（199 行）继续由 PC 自己负责。
4. PC 侧必须提供 `--install-root`，且**必须等于 `%APPDATA%/agentskills/runtime/<plat>/release/` 的父级**，否则会出现"runtime 在 A 处、数据在 B 处"（防回退条款，见下）。

### 4.5 体积与时序影响预估

- **体积**：若走 D3（从 tar.gz 内取安装器），PC 安装包**不增加额外二进制体积**（仅 tar.gz 内多 10~25 MB，经 maximum 压缩后增量更小）。
- **首次启动耗时**：当前 PC 冷启动目标 ≤60 s（`design.md:2434` 版本策略附近）。增加 seed 导入后需实测；考虑到 PC 是**本地 PG 且导入的 seed ≈0.87 MB**（`research-seed-export.md` §3），预计增量在**秒级**，不构成瓶颈。**需实测确认（OQ-D5）。**

---

## 五、能否完全替代 `apps/web-admin/nestJs`？

### 5.1 现状取证

**待替代对象**（`apps/web-admin/nestJs/src/setup/setup.controller.ts` 实测 17 端点，与 `research.md` §1.2 真值表一致）：

```
GET  /setup/check-environment      POST /setup/save-config        GET  /setup/load-config
POST /setup/test-config            GET  /setup/service-status     GET  /setup/logs
POST /setup/create-admin           POST /setup/start-runtime      POST /setup/stop-runtime
POST /setup/restart-runtime        GET  /setup/check-runtime      POST /setup/install-runtime
GET  /setup/read-runtime-env       POST /setup/save-runtime-env   POST /setup/generate-ssl
POST /setup/save-ssl               POST /setup/create-admin（重复注册）
```

同进程还有另外 10 个 Controller（`grep -rn "@Controller("`）：`application` / `auth` / `employee` / `healthCheck` / `i18` / `lang` / `menu` / `mock` / `permission` / `role` / `user` —— **其中只有 `healthCheck` 在安装器替代范围内**，其余是 mock/演示数据服务，随 nestJs 一并退役或被 runtime 自身 API 取代（待确认，OQ-D6）。

**启动脚本** `apps/web-admin/start-installer.bat`（134 行实测）：4 步 —— 检查 Node（`:10-19`）→ 检查 pnpm（`:22-32`）→ 起 nestJs（`:37-47`）→ 起 web 前端（`:52-62`）→ 轮询 `:3000` 与 `:3031` 双端口（`:64-113`）→ 打开 `http://localhost:3031/install.html`（`:120`）。

`design.md` §4.12.2 已给出改造后的单端口 bat 脚本，这里不再重复。

### 5.2 ⚠️ 关键发现 N-3：运维期依赖 —— nestJs 说"可以停"，但它其实停不了

`nestJs/INSTALL_README.md:20-22` 原文：

> 当 agentskills-runtime 安装完成并正常运行后，NestJS 后端服务器可以停止。后续的系统管理和监控功能将由 agentskills-runtime 主服务提供。

**但这条与代码不符。** 实测：

- `apps/web-admin/src/views/setup.vue` 是**常驻管理页**（非安装向导），四个 Tab：
  - 环境检测 → `EnvironmentCheck.vue:44` `fetch('/api/setup/check-environment')`
  - 配置管理 → `ConfigManagement.vue:60` `fetch('/api/setup/load-config')`（页内还有 StepFun / SophNet API Key 表单）
  - 服务监控 → `ServiceMonitor.vue:45` `fetch('/api/setup/service-status')`
  - 日志查看 → `LogViewer.vue:50` `fetch('/api/setup/logs')`
- 页面顶部还有**「重启服务」「停止服务」按钮**（`setup.vue:9-16`）。
- `farm.config.ts:48-58` 的 dev proxy：`/api` → `http://localhost:3000`，仅排除 `^/api/v1/uctoo`（那个走 `https://javatoarktsapi.uctoo.com`，即本机 hosts 映射的本地 runtime）。
- **构建产物里确实带这个页面**：`dist/assets/EnvironmentCheck-BsCEr4l2.js` 存在 ⇒ 它会被部署到生产，不是开发期残留。

**推论（这是"能否完全替代"的真正答案）**：

> **可以替代 nestJs 的"安装引导"职责，但不能简单地"替代完就让它消失"。**
> 一旦 ucInstaller 自退役，`:3000` 无人监听，`setup.vue` 的四个管理面板会同时失灵 —— 用户会发现"装完之后管理页用不了了"。这不是猜测，是 `/api/setup/*` 代理目标 3000 端口的直接后果。

换句话说，**"安装器自退役"（REQ-9：runtime `/api/v1/health` 连续 N 次 200 即自行退出）与"管理面板长期可用"之间存在未解决的冲突**，此前几轮文档都没触到这一层。

### 5.3 三条路线对比

| 路线 | 做法 | 优点 | 缺点 | 评价 |
|---|---|---|---|---|
| **M1 安装器常驻管理** | 不自退役，长期监听 `:3000` 提供 `/setup/*` | 管理页零改动；端点契约 1:1 对齐 | 换了个语言实现的 nestJs —— **退化正是本工程要消除的东西**；常驻进程、常驻端口、"安装包 frontend" 全回来了 | **不推荐** |
| **M2 runtime 原生承接**（**已拍板立项，冻结区显式豁免**） | 在 `src/app/` 补齐**日志读取**与**环境检测**两个端点；状态/配置两项**复用既有** `/api/v1/health` 与 `/api/v1/uctoo/config/*` | 最干净；运维能力归位到"系统本身"，符合 `INSTALL_README` 原本意图 | 触碰**冻结区 `src/app/`**（SDD 铁律：crudgen 公共基础设施"只减不增"）—— **用户已授权本项豁免**，但豁免范围**仅限这两个端点** | **立项**，与 M3 分工（见 §5.3.1） |
| **M3 安装期自退役 + 运维期按需拉起** | 安装完自退役；`setup.vue` 检测到 `:3000` 不可用时，提示「启动管理后端」由用户/安装器按需拉起（`ucInstaller.exe serve --manage`），用毕即退 | **最小改动**；保留"零常驻"卖点；且**启停能力只能外置**（进程不能自举，见 §5.3.1） | 运维时要多一步手动拉起（可用快捷按钮封装，对用户近似透明） | **立项**，承接 M2 做不了的启停 |

**M3 的实施要点**：

1. 安装器新增子命令 `ucInstaller.exe serve --manage [--port 3000]`（或沿用现有 `--auto-exit` 的反面），仅挂载 `/setup/*` 运维端点，**不做安装流程**（此时系统已安装完毕）。
2. `setup.vue` 增加一个"后端未连接"态：请求失败时展示提示 + 「启动管理后端」按钮。这是一处**跨工程前端改动**（`apps/web-admin`），需与 T052 占位符呈现层改动合并推进。
3. `install.html` 安装向导本身不受影响 —— 它只在安装期使用，自退役前已跑完。
4. **注意 `farm.config.ts` 的 dev proxy**：开发期 `/api/setup/*` → `:3000`，M3 下开发者需先拉起管理后端才能用管理面板（行为与现在一致，不回归）。

### 5.3.1 用户直觉核验：运维能力在 runtime 里其实已经有了大半

用户提出一个方向性判断：**"runtime 中可能本来就有这些功能"**（并指向 `sdk/javascript`）。核验结论 —— **指向的目录不对，但方向判断成立**。

先说目录：`sdk/javascript/src/` 与 `sdk/javascript/dist/` **均为空目录**（该 SDK 当前只剩 `package.json`、`node_modules/` 与一份 `runtime/` 副本），启停能力并不在那里；`sdk/` 根目录的四份文档（`API_INTEGRATION_SPEC.md` / `SDK_REQUIREMENTS.md` / `README.md` / `MIGRATION_GUIDE.md`）也**没有任何启停相关描述**。

但**直觉是对的**：把 `setup.vue` 四个面板逐项对到 runtime 宿主源码，大半已经存在：

| `setup.vue` 面板 | nestJs 端点 | runtime 现状 | 证据 |
|---|---|---|---|
| **服务监控** | `/api/setup/service-status` | ✅ **已具备** | `/api/v1/health`（`main.cj:698-717`）返回 `{status, version, scheduler:{running,totalTasks,activeTasks,runningTasks}, chatModel:{available,error}}` —— 比 nestJs 的 `tasklist` 扫描更准（那是看进程名，这是看引擎内部状态） |
| **配置管理** | `/api/setup/load-config` `save-config` | ✅ **已具备** | crudgen 生成的 `ConfigRoute`：`/api/v1/uctoo/config/{add,edit,del,:id,…/…,export}`（`ConfigRoute.cj:27-39`） |
| **系统信息** | — | ✅ **已具备** | `/api/v1/info`（`main.cj:718-720`）返回 `{name,version,language}` |
| **大模型健康** | — | ✅ **已具备** | `/api/v1/ai/health` |
| **环境检测** | `/api/setup/check-environment` | ❌ **缺失** | 无 PG / git / 磁盘 / 端口检测端点。安装器有这套检测，但那是安装期；运维期 runtime 侧没有 |
| **日志查看** | `/api/setup/logs` | ❌ **缺失** | 进程日志落在 `logs/agentskills-runtime.log`（`main.cj:1094`）与 `logs/startup-trace.txt`（`main.cj:44`），**但没有任何读取端点** |
| **启停 / 重启** | `start-runtime` `stop-runtime` `restart-runtime` | ❌ **原理上不可能** | 见下 |

**所以 M2 真正要补的只有两项**：日志读取端点 + 环境检测端点。用户已授权「必需在 M2 承接的功能可不受冻结区限制补充加入 runtime 宿主」—— 冻结区约束（`src/app/` 只减不增）在此处**显式豁免**，但豁免范围就限于这两项，不得借机扩张。

#### 关键架构事实：启停不能自举（这不是设计选择，是物理约束）

`setup.service.ts:554-602` 的实证：

- `startRuntime()` = `spawn(runtimeInfo.path!, [], …)`（`setup.service.ts:567-568`）
- `stopRuntime()` = `execAsync('taskkill /F /IM node.exe')`（`setup.service.ts:598`）

两者都是**进程级管控** —— 管控者必须活在**被管控进程之外**。runtime 不可能"停掉自己、再把自己拉起来"：进程一旦退出，执行体就没了，没有任何代码能执行"启动"这个动作。

因此 **`start/stop/restart` 是唯一无法由 M2 承接的能力**，与冻结区、与语言、与工作量全都无关。这一项必须有个外置管控者：

| 宿主 | 外置管控者现状 | 是否需要 nestJs |
|---|---|---|
| **PC 客户端** | `runtime.ts:317 isRunning()` —— PC 自己就是管控者 | **不需要** ✅ |
| **web-admin 生产态** | 无人（dev 期由 `farm.config.ts` 代理到 `:3000`） | 需要替代者 |
| **合理替代者** | **安装器** —— 它本来就是 spawn runtime 的父进程，天然具备管控位 | ⇒ 即 M3 的 `serve --manage` |

**结论修正**：M2 与 M3 不是二选一，是**分工** —— M2 承接「状态/配置/日志/环境」这些 runtime 能自述的（**补 2 个端点**），M3 承接「启停」这个必须外置的（**安装器 serve --manage**）。两者合起来才能让 nestJs 完全退役。

### 5.3.2 顺带取证：N-4 —— nestJs 的实现已经与 runtime 失配

在核对启停实现时发现两条**现存 bug**，进一步说明 nestJs 退役不只是"换个语言"：

1. **`stopRuntime()` 杀错目标且会自杀**（`setup.service.ts:598`）：执行 `taskkill /F /IM node.exe`
   - ① **杀不到 runtime** —— runtime 是仓颉原生 `magic.app.exe`，镜像名不是 `node.exe`；点"停止服务"实际什么也没停掉。
   - ② **会误杀同机所有 node 进程**，包括 nestJs 自身（即自杀）、以及开发者机器上任何其它 node 应用。
2. **`checkEnvironment()` 把 Node.js >= 18 列为必需项**（`setup.service.ts:25-60`）：仓颉 runtime **根本不依赖 node**。这是 nestJs 时代"runtime 是个 node 应用"的假设残留。

> 顺带印证：nestJs 的 `getServiceStatus()` 用 `tasklist /FI "IMAGENAME eq node.exe"` 判断 runtime 是否运行（`setup.service.ts:340-351`）—— 同样匹配不到 `magic.app.exe`，**服务监控面板显示的"运行中"状态本身就是错的**。

### 5.3.3 OQ-D7 复核：已实现的部分确实有 bug（N-5）

用户拍板 M2 时特别要求**"需要复核，可能已经实现了，但也许有 bug"**。复核结果 —— **确实有**：

| 项 | 复核结论 | 证据 |
|---|---|---|
| 服务监控（`/api/v1/health`） | ⚠️ **已实现，但有 bug** | 见下 **N-5** |
| 配置管理（`/api/v1/uctoo/config/*`） | ✅ 已实现；⚠️ 敏感值明文返回（已知问题，OQ-C2 已移交 runtime） | `ConfigRoute.cj:27-39` |
| 系统信息（`/api/v1/info`） | ✅ 已实现 | `main.cj:718-720` |
| 大模型健康（`/api/v1/ai/health`） | ✅ 已实现 | 路由表实测 |
| 日志读取 | ❌ 未实现 | — |
| 环境检测 | ❌ 未实现 | 源码零命中 |

#### N-5：`/api/v1/health` 的 `chatModel.available` 恒为真

`main.cj:706-713` 的判据是"`_chatModel` 是否为 None"：

```cj
var chatModelJson = "\"chatModel\":{\"available\":true}"
if (_chatModel.isNone()) {
    chatModelJson = "\"chatModel\":{\"available\":false,\"error\":\"${safeErrMsg}\"}"
}
```

但 T010 之后（`main.cj:239` 与 `:448`）`_chatModel` 的赋值变成了：

```cj
// T010：不再启动期建实例、也不因模型创建失败跳过路由注册。
// 改用 LazyChatModel —— 构造永不抛错，真实 ChatModel 在请求边界按 ChannelRegistry 解析
_chatModel = Some(LazyChatModel(modelName))
```

而 `LazyChatModel.init(modelName)` 只做一件事 —— 把模型名字符串存下来（`src/model/lazy_chat_model.cj:27-29`）；
真实实例要到**请求边界**才由 `resolve()` → `ModelManager.createChatModel(modelName)` 解析。

> **于是 `_chatModel` 永远是 `Some` ⇒ `available` 永远是 `true`。**

**后果**：即便通道注册表为空、所有 provider 密钥失效或余额耗尽、乃至 `createChatModel` 在请求时抛错，
运维面板的"大模型配置是否正确"**依然显示正常**——这个面板目前提供的是**假信息**。
这比"没实现"更糟：没实现会报错，假绿灯会让人以为没问题。

**根因不是代码写错，而是语义没跟着改**：`_chatModel` 的含义已从"真实实例"变成"惰性解析器"，
但 health 的判据仍停留在旧语义（`isNone()` = 实例没建出来）。

**正确判据**应探测**通道的实际可用性**（按注册表解析默认通道是否成功 / 探针健康态），
而不是"有没有拿到一个 lazy 壳子"。

> **取证说明**：本条为源码静态判读。实测时 runtime 未在监听（`curl https://javatoarktsapi.uctoo.com/api/v1/health` 返回空），
> 建议在 M-8 验收环节补一次实测确认。

### 5.3.4 N-6：环境探测不要另起炉灶 —— 接既有需求 `system-env-capability`

用户指出：环境探测此前已立需求，见 `.codeartsdoer/specs/system-env-capability/spec.md`
（2026-09-16，状态"设计稿，待资源到位后实现"），且"这个技能也是提供给大模型更好的了解当前运行环境从而更好工作的技能"。

复核该文档后确认：**它与运维面板的"环境检测"是两个消费者、同一类探测能力**：

| | `system-env-capability` | 运维面板环境检测 |
|---|---|---|
| **消费者** | 大模型 / 主 Agent | 人（运维界面） |
| **产物** | `./runtime/capabilities.json` + 注入系统提示词 | HTTP 端点返回 |
| **探测内容** | OS/架构、shell（bash/pwsh/node/python）、浏览器自动化、LLM 能力（`vision` 等）、必需环境变量缺失、已装工具与技能 | 数据库连通性、版本管理工具、磁盘空间、端口占用 |
| **交集** | shell / 工具链 / 环境变量 / 端口可达性 | 同上 |
| **当前状态** | 设计稿，**未实现**（`src/` 与 `skills/` 源码零命中） | 未实现 |

**结论：T055 不应另写一套探测。** 正确做法是**实现 `system-env-capability` 的采集器作为唯一探测层**，
运维端点复用同一采集结果对外暴露。这与该规格 §4「复用 `Config.modelCapabilities`，避免两套真相」的精神一致 ——
只不过这里的"两套真相"是**两套探测实现**。

T055 的落地范围据此调整为：

1. 实现 `system-env-capability` 采集器（按其 spec §3 探测项，含 LLM 能力与环境变量缺失项）；
2. 运维端点**复用**该采集结果，只补充运维特有的项（数据库连通性、磁盘、端口占用）；
3. 采集本身失败时返回"部分能力未知"，**绝不阻断启动**（该 spec §5 降级要求）。

### 5.4 迁移步骤（含回滚）

```
阶段 1（可并行）：D1 发布集成 + CLI 子命令固化 + start-installer.bat 改造为单端口
         → 此时 ucInstaller 与 nestJs 并存，bat 仍指向 ucInstaller
         → 回滚：把 bat 改回即可
阶段 2：17 端点逐条 curl 比对通过（research.md §1.2 真值表为准）
阶段 3：M2 补端点（runtime 侧：日志读取 + 环境检测；复用既有 /api/v1/health 与 config 路由）
         + M3 运维端点（installer serve --manage，承接启停）+ setup.vue 未连接提示
阶段 4：nestJs 退役 —— 目录不删，标记 DEPRECATED 并写 README 指向安装器（保留回滚能力）
         → 评审期后（建议至少一个 release）再考虑删除
```

> **退役判据**（建议写入 tasks）：① 17 端点逐条响应 JSON 等价；② `start-installer.bat` 单端口验收通过；③ 新环境一次装完能登录、菜单非空、主 agent 自动登录成功；④ `setup.vue` 四个面板在「M2 自述 + M3 启停」组合下全部可用（含 N-4：服务监控显示的状态须与 `magic.app.exe` 实际存活一致）。

---

## 六、风险与待确认项

| # | 项 | 现存证据 | 建议 |
|---|---|---|---|
| **OQ-D1** | **NDJSON 流式进度接口是否纳入本工程**（ §3.4） | 当前设计只有"结束输出一行 JSON"，PC 集成需要实时进度 | **建议纳入**。理由：一条接口同时服务 PC Electron、未来 GUI 外壳与远程运维；不做则 PC 只能做"盲等"，体验不可接受 |
| **OQ-D2** | PC 是否接受把安装器放在 `runtime/<plat>/release/bin/` 内 | PC 的既有版本探测围绕该目录（`runtime-integrator.ts:58`） | **建议接受**，这样 PC 侧的既有模块零改动。也可退一步放同级 `installer/` 子目录（需 PC 改一处路径常量） |
| **OQ-D3** | tar.gz → PC resources 的**手工复制**收在哪里 | `pc_desktop_client/design.md:2379` 明确是手工 `cp`；实测两份副本已不同步（N-1） | **建议**：安装器提供 `db export` / 发布脚本后，把这条 `cp` 收进一个共享脚本，并在两侧都加 SHA256 校验 |
| **OQ-D4** | PC 安装完成后首次登录，主 agent 自动登录是否真的失败（`8803ed58…` 出现 0 次） | 静态取证如此，**未做运行时实测** | **建议由 PC 侧实测确认**；若确认失败，则 PC 复用安装器的优先级从"应该"升为"必须" |
| **OQ-D5** | PC 冷启动 ≤60 s 目标是否仍成立 | seed ≈0.87 MB、本地 PG，预估增量秒级 | **建议实测**，不推翻现有指标 |
| **OQ-D6** | nestJs 退役范围内是否包含另外 10 个 Controller（`auth`/`user`/`role`/`menu`/`i18`/`permission`/`application`/`employee`/`mock`） | 它们不在 17 端点表内；`INSTALL_README` 未说明 | **建议**：本工程只替换 `setup` + `healthCheck`；其余 Controller 的取舍作为**独立议题**（大概率已被 runtime 自身 API 覆盖，但需另行核验） |
| **OQ-D7** | M2（runtime 原生承接 `/setup/*`）是否值得作为**后续工程**立项 | 触及冻结区 `src/app/` | **建议**：本工程走 M3；M2 单独立项评估，不在本期范围 |

### 新增约束候选（待确认后转为 REQ）

| 编号 | 约束 |
|---|---|
| **C-D1** | 安装器必须提供 `--no-serve`：完全不监听端口，仅通过 CLI/stdout 交互 |
| **C-D2** | `--progress=ndjson` 时 stdout 每行一个 JSON 事件，最后一行含 `exitCode`；诊断信息一律 stderr |
| **C-D3** | 安装器必须支持 `--version` 输出与 runtime `VERSION` 一致的版本号 |
| **C-D4** | `install --install-root` 指定的目录必须与 host 进程认为的 runtime 目录一致或为其父级；安装器需校验并拒绝错配 |
| **C-D5** | 安装完成自退役后，安装器必须仍能以 `serve --manage` 提供运维端点；两者路由同源，不重复实现 |

---

## 七、本章关键结论清单

1. 发布走**三条轨道、同一份二进制**：主轨道是把 `ucInstaller.exe` 放进既有的 `agentskills-runtime-win-x64.tar.gz`（§2.2）。这一决定的最大收益是 **PC 客户端零改动即自动获得安装器**。
2. 消费需**三种接口**，其中 NDJSON 流式接口当前设计缺失（§3.4）。
3. PC 客户端**可以复用**，方案是"**外壳不动、数据全交**"（§4.3）。驱动力不是架构洁癖，而是 **N-2：当前每台装出来的 PC 客户端都带着 123 处作者本机超管 uuid 且缺主 agent 账号**。
4. **不能完全替代 nestJs 后就消失**（§5.2）：`setup.vue` 是常驻管理页，长期依赖 `/api/setup/*`。推荐 **M3**（安装期自退役 + 运维期按需拉起），M2 作为后续独立议题。
5. 顺带发现 **N-1**：runtime ↔ PC 的 tar.gz 复制是手工步骤，当前两份副本已不同步（419 MB vs 380 MB）。

---

## 附录：本章引用的证据文件

| 用途 | 文件 | 关键位置 |
|---|---|---|
| 发布管线 | `apps/agentskills-runtime/build_and_release.ps1` | `:46-70` 编译 / `:74-102` 打包 / `:131-149` SHA256 / `:153-215` tag+人工上传 |
| 发布包结构 | `apps/agentskills-runtime/PACKAGE_RELEASE_GUIDE.md` | `:36-60` `release/bin/` 布局（281 DLL / 283 CJO / `.env` / ssl / logs） |
| 发布产物（实测） | `apps/agentskills-runtime/release/agentskills-runtime-win-x64.tar.gz` | 439,483,164 B / Oct 6 22:52 |
| PC 打包配置 | `apps/pc-client/electron-builder.json` | `:71-83` win nsis+portable / `:18-63` extraResources / `:100-104` publish |
| PC runtime 集成 | `…/electron/modules/runtime-integrator.ts` | `:99-160` 解压 / `:162-186` SDK 下载兜底 / `:58` 就绪判据 |
| PC 向导服务 | `…/electron/modules/setup.ts` | `:20-99` database / `:101-118` AI / `:120-132` completeSetup |
| PC 数据库初始化 | `…/electron/modules/pgsql.ts` | `:178-200` `psql -f uctoov4InitData.sql` |
| PC 向导 UI | `…/src/views/setup/SetupView.vue` | `:5-6` totalSteps=4 / `:271-274` 四步标签 |
| PC 内置种子数据（**病灶**） | `…/resources/sql/uctoov4InitData.sql` | 715,793 B / Apr 1 2026；0 CREATE TABLE；`505cf909…` ×123；`8803ed58…` ×0 |
| PC 设计（v2.5） | `.codeartsdoer/specs/pc_desktop_client/design.md` | `:9` v2.5 变更说明 / `:2366-2440` 构建与发布 / `:2379` 手工 cp |
| 旧安装器端点 | `apps/web-admin/nestJs/src/setup/setup.controller.ts` | 17 个映射（含重复注册的 `create-admin`） |
| 旧安装器退场声明 | `apps/web-admin/nestJs/INSTALL_README.md` | `:20-22` "NestJS 后端服务器可以停止"（**与实际不符**） |
| 启动脚本 | `apps/web-admin/start-installer.bat` | `:10-19` Node / `:22-32` pnpm / `:64-113` 双端口轮询 / `:120` 打开 install.html |
| dev proxy | `apps/web-admin/farm.config.ts` | `:48-58` `/api` → `:3000`，排除 `/api/v1/uctoo` |
| **常驻管理页（**关键**）** | `apps/web-admin/src/views/setup.vue` | `:9-16` 重启/停止按钮 / `:24,29,34,39` 四组件 |
| 管理页子组件 | `src/views/components/{EnvironmentCheck,ConfigManagement,ServiceMonitor,LogViewer}.vue` | `:44` / `:60` / `:45` / `:50` 各自 fetch `/api/setup/*` |
| 产物已含管理页 | `apps/web-admin/dist/assets/EnvironmentCheck-BsCEr4l2.js` | 存在 ⇒ 非开发期残留 |
| 既有安装器设计 | `specs/RuntimeNativeInstaller/design.md` | §4.11 `--json` 契约 / §4.12 出包布局与 DLL 摆放 / `:1141` DLL 同目录 |
| 既有端点真值表 | `specs/RuntimeNativeInstaller/research.md` | §1.2 17 端点 |
| Seed 实测账 | `specs/RuntimeNativeInstaller/research-seed-export.md` | §3 分层体量 ≈0.87 MB |
| 身份契约 | `specs/RuntimeNativeInstaller/research-seed-identity.md` | §1.3 悬空与 RBAC 三表零行 |
