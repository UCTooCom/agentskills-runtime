# 需求规格：PC 客户端首次运行引导（PcFirstRunBootstrap）

> 阶段：spec
> 工程：`specs/PcFirstRunBootstrap`
> 上游：`research.md`（草稿）
> 日期：2026-10-21 · 版本 v0.1 · 状态：草稿

---

## 1. 组件定位

### 1.1 核心职责

本组件负责编排 PC 客户端安装后的自动初始化（管理员创建 + seed 导入）、首次打开的自动启停（数据库 + runtime）、首次欢迎页面展示管理员账号、以及重装时的数据保留/覆盖选择，实现 PC 客户端"安装即用、开箱可操作"。

### 1.2 核心输入

1. **NSIS 安装事件**：安装/覆盖安装/卸载触发，含安装目录选择。
2. **`ucInstaller.exe` 的 NDJSON 事件流**：`install --json --progress=ndjson` 输出的 S0~S8 各阶段进度与结果（含管理员账号信息）。
3. **用户重装选择**：覆盖安装 / 保留已有数据（NSIS 自定义页面单选）。
4. **PC 客户端启动事件**：Electron `app.whenReady()` 触发。
5. **`default-config.json`**：runtime.autoStart / pgsql.embedded.autoStart 配置。
6. **`first-run-credentials.json`**：首次安装产出的管理员凭据标记文件。

### 1.3 核心输出

1. **数据库副作用**：`uctoo_user` 表写入一行管理员记录（bcrypt cost 10）；seed 数据导入既有表。
2. **标记文件**：`first-run-credentials.json`（含管理员 email/username/密码，首次展示后可删除）。
3. **进程副作用**：runtime 进程启动（`serve --manage`）；内嵌 PostgreSQL 启动。
4. **用户界面**：NSIS 安装进度页 → 首次欢迎页面（管理员账号展示）。
5. **日志**：安装初始化日志、启停日志（经 installer NDJSON 流）。

### 1.4 职责边界

- **不重新实现 installer 的能力**：管理员创建、seed 导入、DB 初始化、.env 生成全部委托 `ucInstaller.exe`，本组件只做编排与桥接。
- **不修改 installer 源码**：复用 installer 已有 CLI 命令（`install` / `serve --manage` / `seed apply`），不改动仓颉代码。
- **不管理 web-admin 业务功能**：欢迎页面仅展示管理员账号，不实现登录、技能管理等业务功能。
- **不处理 runtime 升级**：runtime 版本升级是 `PcClientInstallerIntegration` 的职责，本工程仅管首次安装/重装的初始化与启停。
- **不新建数据库表或列**：管理员写入既有 `uctoo_user` 表，seed 导入既有表（SDD 铁律 9）。

---

## 2. 领域术语

**首次安装（First Install）**
: 目标安装目录下不存在数据目录（`<安装目录>/data/` 或 PG dataDir），判定为首次安装，需执行完整初始化。

**覆盖安装（Overwrite Install）**
: 重装时用户选择"覆盖已有数据"，等价于首次安装——执行完整初始化（创建新管理员 + seed 导入）。

**保留数据安装（Preserve Data Install）**
: 重装时用户选择"保留已有数据"，仅更新程序文件，不执行初始化，不创建新管理员，不导入 seed。

**管理员凭据标记文件（First-Run Credentials Marker）**
: `first-run-credentials.json`，由 NSIS 安装后钩子写入，含管理员 email/username/明文密码，供 PC 首次启动时展示。展示并经用户确认后删除。

**自动启停（Auto Start/Stop）**
: PC 客户端启动时自动调 `ucInstaller.exe serve --manage` 启动 runtime + 内嵌 PostgreSQL；退出时自动停止。

**installer 桥接（Installer Bridge）**
: PC Electron 主进程通过子进程调用 `ucInstaller.exe` 的通道，复用 `PcClientInstallerIntegration` Phase 3 已落盘的 `installer-bridge.ts`。

---

## 3. 角色与边界

### 3.1 核心角色

- **终端用户**：双击安装包安装、打开 PC 客户端、在欢迎页面记录管理员账号。
- **NSIS 安装器**：执行文件解压、检测首次/重装、调 `ucInstaller.exe install`、写标记文件。

### 3.2 外部系统

- **`ucInstaller.exe`**：仓颉原生安装器，接收 `install` / `serve --manage` 命令，输出 NDJSON 事件流。
- **内嵌 PostgreSQL**：由 installer S4 初始化、`serve --manage` 启停。
- **runtime 进程**：由 `serve --manage` 启停，PC 通过 IPC 监控状态。
- **`default-config.json`**：PC 默认配置，含 autoStart 标志。

### 3.3 交互上下文

```
用户 ──安装──► NSIS ──install──► ucInstaller.exe ──初始化──► PostgreSQL
                   │                    │
                   │                    ├──创建管理员──► uctoo_user
                   │                    └──seed导入──► 既有表
                   │
                   └──写标记文件──► first-run-credentials.json

用户 ──打开──► Electron ──serve --manage──► ucInstaller.exe ──启停──► runtime + PG
                   │
                   ├──读标记文件──► 欢迎页面 ──展示──► 用户
                   └──加载首页──► web-admin
```

---

## 4. DFX 约束

### 4.1 性能

1. **安装后初始化耗时**：`ucInstaller.exe install` 执行 S0~S8 上限 **5 分钟**（含 DB 初始化 + seed 导入）。
   - 验收条件：WHEN 执行安装后初始化，THEN THE SYSTEM SHALL 在 5 分钟内完成，且通过 NDJSON 流实时报告进度。

2. **PC 冷启动时间**：从双击到首页可交互上限 **30 秒**（含 runtime + PG 启动）。
   - 验收条件：WHEN 用户打开 PC 客户端，THEN THE SYSTEM SHALL 在 30 秒内首页可交互。

3. **自动启停响应**：`serve --manage` 启动 runtime 上限 **15 秒**。
   - 验收条件：WHEN PC 调 `serve --manage`，THEN THE SYSTEM SHALL 在 15 秒内 runtime 进程就绪。

### 4.2 可靠性

1. **初始化失败可回滚**：安装后初始化失败时，installer `rollback` 可恢复到安装前状态。
   - 验收条件：IF `ucInstaller.exe install` 返回非 0 退出码，THEN THE SYSTEM SHALL 提示失败原因并支持回滚。

2. **自动启停失败不阻塞首页**：runtime/PG 启动失败时，web-admin 首页仍可加载（业务数据为空）。
   - 验收条件：IF `serve --manage` 启动失败，THEN THE SYSTEM SHALL 在导航栏显示服务异常状态，但不阻塞首页加载。

3. **标记文件原子写入**：`first-run-credentials.json` 写入失败不导致安装失败。
   - 验收条件：IF 标记文件写入失败，THEN THE SYSTEM SHALL 记录日志并继续安装，PC 首次启动时跳过欢迎页。

### 4.3 安全性

1. **管理员密码不落盘明文**：标记文件中的明文密码仅在首次展示前存在，展示并经用户确认后删除。
   - 验收条件：WHEN 用户在欢迎页面点击"已记录"，THEN THE SYSTEM SHALL 删除 `first-run-credentials.json`。

2. **标记文件权限**：`first-run-credentials.json` 写入用户目录，仅当前用户可读。
   - 验收条件：WHEN 创建标记文件，THEN THE SYSTEM SHALL 设置文件权限为当前用户仅可读。

3. **管理员密码随机性**：随机密码长度 ≥ 16 字符，含大小写字母 + 数字 + 特殊字符。
   - 验收条件：WHEN 生成管理员密码，THEN THE SYSTEM SHALL 产出 ≥ 16 字符的随机字符串。

### 4.4 可维护性

1. **安装初始化日志**：`ucInstaller.exe install` 的 NDJSON 流写入日志文件，可回放。
   - 验收条件：WHEN 执行安装后初始化，THEN THE SYSTEM SHALL 将 NDJSON 事件流写入 `<安装目录>/logs/install-init.log`。

2. **启停日志**：`serve --manage` 的输出写入日志文件。
   - 验收条件：WHEN 执行自动启停，THEN THE SYSTEM SHALL 将输出写入 `<安装目录>/logs/serve-manage.log`。

### 4.5 兼容性

1. **保留数据兼容**：保留数据安装时，不破坏既有数据库数据。
   - 验收条件：WHEN 用户选择保留数据安装，THEN THE SYSTEM SHALL 不执行任何 DDL 或 DML，仅更新程序文件。

2. **标记文件向后兼容**：PC 启动时标记文件不存在视为非首次安装，正常加载。
   - 验收条件：IF `first-run-credentials.json` 不存在，THEN THE SYSTEM SHALL 跳过欢迎页直接加载首页。

---

## 5. 核心能力

### 5.1 安装后自动初始化

#### 5.1.1 业务规则

1. **首次安装自动初始化**：NSIS 安装器检测到首次安装（目标目录无数据目录）时，必须自动执行 `ucInstaller.exe install` 完成初始化。
   - 验收条件：[首次安装] → [自动执行 install，创建管理员 + 导入 seed]

2. **管理员账号自动生成**：初始化时自动生成管理员账号，email 为 `<随机字符串>@uctoo.com`，name 和 username 为 `admin`，密码为随机字符串。
   - 验收条件：[初始化完成] → [uctoo_user 表存在一行，email 匹配 `*@uctoo.com`，name=username=admin，password 为 bcrypt 哈希]

3. **seed 自动导入**：初始化时以创建的管理员账号为身份，自动导入 seed 数据并完成 RBAC 权限骨架与身份重绑定。
   - 验收条件：[初始化完成] → [seed 主体数据已导入，权限骨架已补种，身份已重绑定到管理员账号]

4. **初始化进度展示**：安装后初始化通过 NDJSON 流实时报告进度，NSIS 安装页面显示进度条。
   - 验收条件：[初始化执行中] → [NSIS 安装页面显示 S0~S8 各阶段进度]

5. **管理员凭据写入标记文件**：初始化完成后，管理员 email/username/明文密码写入 `first-run-credentials.json`。
   - 验收条件：[初始化成功] → [标记文件存在且含管理员 email/username/password]

6. **禁止项**：禁止在标记文件中存储 bcrypt 哈希而非明文密码（欢迎页需展示明文供用户记录）。
   - 验收条件：[标记文件内容] → [password 字段为明文，非哈希]

#### 5.1.2 交互流程

```
用户双击 Installer.exe
  → NSIS 解压文件
  → NSIS 检测首次/重装
  → if 首次:
    → 生成随机管理员 email + 密码
    → 执行 ucInstaller.exe install --json --progress=ndjson --admin-email=<随机>@uctoo.com --admin-password=<随机>
    → 解析 NDJSON 流，更新 NSIS 进度条
    → install 成功 → 提取管理员信息 → 写 first-run-credentials.json
    → install 失败 → 提示错误 + 支持回滚
  → 创建桌面快捷方式
  → 安装完成
```

#### 5.1.3 异常场景

1. **ucInstaller.exe 未找到**
   - 触发条件：`release/bin/ucInstaller.exe` 不存在
   - 系统行为：NSIS 报错并中止安装
   - 用户感知：错误提示"安装器组件缺失，请联系开发者"

2. **初始化超时**
   - 触发条件：`ucInstaller.exe install` 超过 5 分钟未完成
   - 系统行为：NSIS 终止子进程，提示超时
   - 用户感知：错误提示"初始化超时，可选择回滚或重试"

3. **数据库已存在数据**
   - 触发条件：首次安装检测到 `uctoo_user` 表已有数据
   - 系统行为：跳过管理员创建，仅补导 seed
   - 用户感知：日志记录"检测到已有数据，跳过管理员创建"

### 5.2 打开即用：自动启停

#### 5.2.1 业务规则

1. **runtime 自动启动**：PC 客户端启动时，若 `runtime.autoStart` 为 true，必须自动调 `ucInstaller.exe serve --manage` 启动 runtime。
   - 验收条件：[PC 启动 + autoStart=true] → [runtime 进程启动并就绪]

2. **数据库自动启动**：PC 客户端启动时，若 `pgsql.embedded.autoStart` 为 true，必须自动启动内嵌 PostgreSQL（经 `serve --manage` 统一管控）。
   - 验收条件：[PC 启动 + pgsql.autoStart=true] → [PostgreSQL 进程启动并可连接]

3. **web-admin 自动启动**：PC 客户端启动时，若 `webadmin.autoStart` 为 true，必须自动启动 web-admin HTTP 服务。
   - 验收条件：[PC 启动 + webadmin.autoStart=true] → [web-admin 端口可访问]

4. **退出时自动停止**：PC 客户端正常退出时，必须停止 runtime 和 PostgreSQL 进程。
   - 验收条件：[PC 退出] → [runtime + PG 进程终止]

5. **禁止项**：禁止 PC 自行直接启动 runtime 二进制（必须经 `serve --manage` 管控，R-39 约束）。
   - 验收条件：[启停调用] → [经 ucInstaller.exe serve --manage，非直接 spawn runtime]

#### 5.2.2 交互流程

```
用户打开 PC 客户端
  → Electron app.whenReady()
  → 读取 default-config.json
  → if runtime.autoStart:
    → spawn ucInstaller.exe serve --manage
    → 监听 NDJSON 事件 → 更新服务状态
  → if webadmin.autoStart:
    → 启动 web-admin HTTP 服务
  → 检测 first-run-credentials.json
    → 存在 → 显示欢迎页面
    → 不存在 → 加载首页
```

#### 5.2.3 异常场景

1. **serve --manage 启动失败**
   - 触发条件：`ucInstaller.exe serve --manage` 返回非 0
   - 系统行为：记录日志，导航栏显示服务异常，不阻塞首页
   - 用户感知：导航栏"Runtime"旁显示红点 + "服务未启动"提示

2. **端口冲突**
   - 触发条件：runtime port 8080 或 PG port 5432 被占用
   - 系统行为：`serve --manage` 报错，PC 提示端口冲突
   - 用户感知：错误提示"端口 8080/5432 被占用，请释放后重启"

3. **runtime 进程崩溃**
   - 触发条件：runtime 进程异常退出
   - 系统行为：PC 监听进程退出事件，显示崩溃状态，提供"重启服务"按钮
   - 用户感知：导航栏显示崩溃状态 + 重启入口

### 5.3 首次欢迎页面

#### 5.3.1 业务规则

1. **首次安装显示欢迎页**：PC 首次启动时检测到 `first-run-credentials.json` 存在，必须显示欢迎页面。
   - 验收条件：[首次启动 + 标记文件存在] → [显示欢迎页面]

2. **欢迎页展示管理员账号**：欢迎页面必须展示管理员的 email、username、明文密码，并提示用户记录。
   - 验收条件：[欢迎页面渲染] → [显示 email + username + password + "请妥善保管"提示]

3. **确认后删除标记文件**：用户在欢迎页面点击"已记录并理解"后，必须删除 `first-run-credentials.json`。
   - 验收条件：[用户点击确认] → [标记文件删除，下次启动不再显示欢迎页]

4. **密码可复制**：欢迎页面的密码字段支持一键复制。
   - 验收条件：[用户点击复制] → [密码复制到剪贴板]

5. **禁止项**：禁止在非首次启动时显示欢迎页面（标记文件不存在则跳过）。
   - 验收条件：[非首次启动 + 标记文件不存在] → [直接加载首页，不显示欢迎页]

#### 5.3.2 交互流程

```
PC 启动 → 检测 first-run-credentials.json
  → 存在 → 读取 {email, username, password}
    → 渲染 Welcome.vue
    → 显示 email / username / password
    → 用户点击"已记录并理解"
    → 删除 first-run-credentials.json
    → 跳转首页
  → 不存在 → 直接加载首页
```

#### 5.3.3 异常场景

1. **标记文件损坏**
   - 触发条件：`first-run-credentials.json` JSON 解析失败
   - 系统行为：记录日志，删除损坏文件，跳过欢迎页
   - 用户感知：日志记录"标记文件损坏，跳过欢迎页"，正常加载首页

2. **标记文件删除失败**
   - 触发条件：用户确认后删除标记文件失败（权限等）
   - 系统行为：记录日志，提示用户手动删除
   - 用户感知：提示"请手动删除 <路径> 避免再次显示欢迎页"

### 5.4 重装数据保留选择

#### 5.4.1 业务规则

1. **重装检测**：NSIS 检测到目标目录已有安装（存在 `AgentSkills Runtime.exe`），必须弹出数据保留选择页面。
   - 验收条件：[重装 + 目标目录已有安装] → [显示数据保留选择页面]

2. **覆盖安装执行完整初始化**：用户选择"覆盖安装"时，必须执行与首次安装相同的完整初始化（创建新管理员 + seed 导入）。
   - 验收条件：[选择覆盖] → [执行 ucInstaller.exe install，创建新管理员，覆盖旧数据]

3. **保留数据跳过初始化**：用户选择"保留已有数据"时，必须跳过初始化，仅更新程序文件，不创建新管理员，不导入 seed。
   - 验收条件：[选择保留] → [不执行 install，不创建管理员，不导入 seed，既有数据不变]

4. **保留数据不显示欢迎页**：保留数据安装后，PC 首次启动不显示欢迎页面（沿用已有管理员账号）。
   - 验收条件：[保留数据安装后启动] → [不显示欢迎页，直接加载首页]

5. **覆盖安装显示欢迎页**：覆盖安装后，PC 首次启动显示欢迎页面（展示新创建的管理员账号）。
   - 验收条件：[覆盖安装后启动] → [显示欢迎页，展示新管理员账号]

6. **禁止项**：禁止保留数据安装时意外覆盖数据库（必须跳过所有 DDL/DML）。
   - 验收条件：[保留数据安装] → [不执行任何 DDL/DML，数据库内容不变]

#### 5.4.2 交互流程

```
NSIS 检测已有安装
  → 弹出选择页面：
    ○ 覆盖安装（创建新管理员，覆盖已有数据）
    ○ 保留已有数据（仅更新程序，保留数据库）
  → if 覆盖:
    → 执行完整初始化（同 5.1）
    → 写 first-run-credentials.json
  → if 保留:
    → 仅解压程序文件
    → 不写 first-run-credentials.json
  → 继续安装
```

#### 5.4.3 异常场景

1. **保留数据但数据库损坏**
   - 触发条件：选择保留数据，但既有数据库无法连接
   - 系统行为：提示数据库异常，建议选择覆盖安装
   - 用户感知：警告"检测到数据库可能损坏，建议覆盖安装"

2. **覆盖安装但数据库被占用**
   - 触发条件：选择覆盖安装，但 PostgreSQL 进程正在运行（数据库被锁定）
   - 系统行为：提示停止现有 PostgreSQL 后重试
   - 用户感知：错误提示"数据库正在运行，请先停止后重试"

---

## 6. 数据约束

### 6.1 管理员凭据标记文件（first-run-credentials.json）

1. **email**：格式为 `<随机字符串>@uctoo.com`，随机字符串长度 ≥ 8 字符，含小写字母 + 数字。
2. **username**：固定值 `admin`。
3. **name**：固定值 `admin`。
4. **password**：明文密码，长度 ≥ 16 字符，含大小写字母 + 数字 + 特殊字符。
5. **createdAt**：ISO 8601 时间戳，标记文件创建时间。
6. **version**：标记文件格式版本，当前为 `1`。

### 6.2 管理员账号（uctoo_user 表）

1. **email**：与标记文件 email 一致，唯一。
2. **username**：`admin`，唯一。
3. **name**：`admin`。
4. **password**：bcrypt cost 10 哈希，与标记文件明文密码对应。
5. **status**：启用状态，默认为启用。

### 6.3 PC 配置（default-config.json）

1. **runtime.autoStart**：默认 `true`，PC 启动时自动启动 runtime。
2. **pgsql.embedded.autoStart**：默认 `true`，PC 启动时自动启动内嵌 PostgreSQL。
3. **webadmin.autoStart**：默认 `true`，PC 启动时自动启动 web-admin。