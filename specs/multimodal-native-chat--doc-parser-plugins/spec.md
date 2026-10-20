# 子系统需求规格：文档解析插件轨（`doc-parser-plugins`）

> 主工程：`multimodal-native-chat` ｜ 子系统 `feature_name`：`multimodal-native-chat--doc-parser-plugins`
> 版本：v1 ｜ 日期：2026-10-15 ｜ 阶段：spec
> 上游：`host-attach-core` v1（契约）、主工程 `spec.md` v2 §5.3、`research-doc-parser-ecosystem.md`
> 契约：本目录 `contract.md`（v1，草案）
> 语言标签：cangjie（L2 轨）/ 脚本·Python·Node（L3 轨）

---

## 1. 组件定位

### 1.1 核心职责

本子系统负责以**宿主外插件**形态提供各类文档格式的解析能力，把文档字节转换为带来源标注的文本块，供宿主随聊天提交给模型。

### 1.2 核心输入

1. 宿主下发的 `ParseRequest`（文件名 / MIME / 原始字节 / limits）。
2. 待接入的生态解析实现（MarkItDown / MinerU / PaddleOCR / 技能市场既有技能等）。
3. v1 遗留的宿主内抽取器源码（作为首个参考实现的搬迁输入）。

### 1.3 核心输出

1. 符合 `DocumentParser` 契约的解析插件（L2 动态库轨 或 L3 进程隔离轨）。
2. 注册到宿主 `ParserRegistry` 的 `ParserDescriptor`。
3. `ParseResult`（含 `FilePart` 列表与 `parserId` / `parserVersion`）。
4. 生态解析技能的适配结果（`SkillAdapter` 产出）。

### 1.4 职责边界

本子系统**不负责**：

1. 附件接收、限流、调度、提交与留痕（归 `host-attach-core`）。
2. 前端交互（归 `web-multimodal`）。
3. 附件落库（归 `attachment-persistence`）。
4. 重新发明插件加载机制——**必须复用** `plugin-system` 既有三轨（sync / dylib / process）。
5. 修改宿主源码以接入新格式（接入 = 装插件，不是改宿主）。

---

## 2. 领域术语

**解析插件**
: 实现 `DocumentParser` 契约、以 L2 或 L3 轨形态承载的独立交付单元。
: 备注：一个插件可覆盖一种或多种格式。

**L2 动态库轨**
: 预编译动态库经 `PackageInfo.load` 热加载，与宿主同进程。
: 备注：零 IPC，适合同语言（仓颉）实现的轻量解析器；宿主需做异常边界。

**L3 进程隔离轨**
: cordis-cj 拉起独立子进程，经 stdio/jsonrpc IPC 调用。
: 备注：**可承载非仓颉实现**（Python / Node），崩溃不影响宿主。

**技能适配器（SkillAdapter）**
: 把 agentskills 标准技能（`SKILL.md` + `scripts/`）包装成 `DocumentParser` 的适配层。
: 备注：复用技能市场既有实现时无需改写其实现。

**能力声明（capabilities）**
: 插件额外权限声明（如 `needs_fs` / `needs_net`），非空时安装需人工确认。

---

## 3. 角色与边界

### 3.1 核心角色

- **文档解析插件作者**：实现某一种或几种格式的解析器（团队内部或第三方）。
- **运维/管理员**：安装、启停、卸载插件，设置优先级。

### 3.2 外部系统

- **`host-attach-core`**（上游调用方）：下发 `ParseRequest`、消费 `ParseResult`。
- **`plugin-system` 三轨机制**（承载底座）：插件注册、生命周期、服务代理。
- **智能体技能市场**（可选供给方）：既有解析技能来源。

### 3.3 交互上下文

```plantuml
@startuml
skinparam rectangle { BackgroundColor #F5F5F5 BorderColor #333333 }
skinparam shadowing false

rectangle "文档解析插件作者" as Author
rectangle "智能体技能市场" as Market
rectangle "文档解析插件轨\n(本子系统)" as Plug
rectangle "plugin-system 三轨" as PS
rectangle "宿主附件消费内核\n(host-attach-core)" as Host

Author --> Plug : 实现解析器
Market --> Plug : 供给既有技能(SkillAdapter)
Plug --> PS : 以 L2 或 L3 轨注册
PS --> Host : 暴露解析器引用
Host --> Plug : parse(ParseRequest)
Plug --> Host : ParseResult(FilePart[])
@enduml
```

---

## 4. DFX 约束

### 4.1 性能
1. 单个插件对单份文档的解析应在宿主下发的 `limits.timeoutMs`（默认 10s）内返回。
2. 插件必须遵守 `limits.maxChars` 自行截断，不得返回超限文本。
3. L3 轨插件的进程冷启动不计入首次解析预算（由宿主预热策略承担，P2）。

### 4.2 可靠性
1. 插件**无状态**：同一输入重复调用结果一致（幂等）。
2. 插件内部异常必须自我捕获并转为 `status=error` + `error` 描述，**不得崩溃到不可响应**。
3. L3 轨插件崩溃后宿主标记不可用，其它插件与宿主不受影响。
4. 不支持/损坏的文件必须返回 `status=error` 或 `empty`，不得返回乱码正文。

### 4.3 安全性
1. 插件只获得「文件名 + MIME + 字节」三要素，不得索取会话令牌或 DB 凭据。
2. 需要落盘/外网能力的插件必须在 `capabilities` 中显式声明，安装时阻断待人工确认。
3. L3 轨插件 **stdout 是 RPC 独占通道**，诊断日志一律走 stderr。
4. 来自技能市场的第三方实现必须经**源码评审 + 沙箱试跑**后才可接入。

### 4.4 可维护性
1. 每个插件必须声明 `parserId` / `version`，解析结果带这两个字段可溯源。
2. 插件必须能通过 `plugingen` 生成骨架（可复现）。
3. 插件安装/卸载不触发宿主重编与重启。

### 4.5 兼容性
1. 契约 minor 演进不得破坏既有插件。
2. 存量抽取器搬迁后，对同一 fixtures 集的解析结果须与搬迁前等价。
3. 非仓颉生态实现（Python/Node）须在目标部署环境可用，否则该插件标记为环境不适用。

---

## 5. 核心能力

### 5.1 存量抽取器搬迁（首个参考实现，L2 轨）

#### 5.1.1 业务规则

1. **搬迁等价**：v1 宿主内 PDF/DOCX/PPTX/文本族抽取器搬迁为 L2 插件后，解析结果须与搬迁前等价
   a. 验收条件：When 对同一 fixtures 集执行搬迁后解析, the 文档解析插件轨 shall 产出与搬迁前一致的文本块划分与来源标注
2. **零外部依赖可用**：该插件不得依赖 Python/Node，保证最小化部署场景仍可解析
   a. 验收条件：When 部署环境无 Python/Node 运行时, the 文档解析插件轨 shall 仍能由该插件完成基础格式解析
3. **宿主侧清空**：搬迁完成后宿主内不得残留格式解析实现
   a. 验收条件：When 搬迁完成, the 文档解析插件轨 shall 使宿主侧格式解析代码为零

#### 5.1.2 异常场景

1. **损坏/加密文件**
   a. 触发条件：文件损坏或加密
   b. 系统行为：返回 `status=error` + 原因，由宿主转兜底
   c. 用户感知：「文件 X 解析失败」

### 5.2 生态解析器接入（L3 轨）

#### 5.2.1 业务规则

1. **多语言承载**：L3 轨必须能承载非仓颉实现（Python / Node 生态解析库）
   a. 验收条件：When 接入一个 Python 实现的解析器, the 文档解析插件轨 shall 经 L3 轨完成装配并可被调用
2. **覆盖面扩展**：生态解析器应覆盖仓颉实现读不准的场景（CID 中文 PDF、扫描件 OCR、复杂表格）
   a. 验收条件：When 处理 CID 编码中文 PDF, the 文档解析插件轨 shall 经生态解析器产出可读中文文本
3. **故障隔离**：生态解析器崩溃不得影响宿主与其它插件
   a. 验收条件：If L3 解析进程异常退出, the 文档解析插件轨 shall 使宿主捕获异常并标记该插件不可用, 宿主与其它插件不受影响

#### 5.2.2 异常场景

1. **运行环境缺失**
   a. 触发条件：目标环境无 Python/Node 运行时
   b. 系统行为：插件注册时标记「环境不适用」，宿主跳过该插件
   c. 用户感知：无（自动回落到仓颉 L2 插件）

### 5.3 技能市场复用（SkillAdapter）

#### 5.3.1 业务规则

1. **标准技能可装配**：agentskills 标准技能形态（`SKILL.md` + `scripts/`）的解析技能必须能被包装为解析器
   a. 验收条件：When 接入一个标准技能形态的文档解析技能, the 文档解析插件轨 shall 经适配器将其装配为可用解析器
2. **不改写实现**：适配层不得修改第三方技能的实现代码
   a. 验收条件：When 适配第三方技能, the 文档解析插件轨 shall 仅在外层包装, 不改动其 SKILL.md 与脚本
3. **安全前置**：第三方技能须经源码评审与沙箱试跑后才可启用
   a. 验收条件：If 接入来源为第三方市场, the 文档解析插件轨 shall 先完成评审与试跑并记录结论

#### 5.3.2 异常场景

1. **技能脚本执行失败**
   a. 触发条件：技能脚本退出码非 0 或输出不可解析
   b. 系统行为：适配器返回 `status=error` + 原因
   c. 用户感知：由宿主转兜底

### 5.4 技能适配与安装时轨决策（install-time decision）

> 本节落实一条产品决策：**从其它智能体技能市场获取的文档格式解析技能，通常需略作适配才能在 agentskills-runtime 中良好运行；而具体以「纯文档技能 / L2 动态库轨 / L3 进程隔离轨」哪一种形态接入，不在架构层预先固定，而是在该技能被安装进本运行时时结合其实现语言、隔离需求与运行环境具体决策与适配。**

#### 5.4.1 业务规则

1. **适配是可预期且归属于本子系统**：第三方市场技能的直接运行契约（输入三要素、输出 `ParseResult`、错误码映射）往往与宿主不同，需要一层薄适配；适配**在外层包装**，**不得改写技能实现本体**。
   a. 验收条件：When 接入一个第三方市场技能, the 文档解析插件轨 shall 在其外层完成适配而不改动其 SKILL.md 与脚本实现
2. **轨形态由安装时决定**：某技能最终以「纯文档技能（直接调脚本）/ L2 动态库轨 / L3 进程隔离轨」哪一种形态接入，由**该技能安装到 agentskills-runtime 时**具体决策，而非套用单一固定形态。
   a. 验收条件：When 一个解析技能被安装, the 文档解析插件轨 shall 在安装环节依据实现语言/隔离需求/运行环境选定适配形态并登记, 而非套用单一固定形态
3. **安装时决策 Checklist**（决策依据，非强制排序）：
   - **实现语言**：仓颉实现优先 L2；Python/Node 等生态实现优先 L3；仅含脚本、无独立进程需求的轻量技能可走「纯文档技能」封装。
   - **隔离需求**：涉及不可信第三方代码、需落盘/外网、可能占用大量内存 → L3 进程隔离。
   - **运行环境**：目标环境无 Python/Node 运行时 → 该 L3 技能标记「环境不适用」，回落到 L2 仓颉插件。
   - **安全**：第三方来源必须经**源码评审 + 沙箱试跑**（见 §4.3.4）通过后才可启用。
4. **适配可叠加**：同一来源技能可同时存在多个适配形态（如既提供 L2 仓颉包装又提供 L3 Python 包装），由注册表的 `priority` 决定命中序。

#### 5.4.2 异常场景

1. **安装时环境不满足**
   a. 触发条件：选定 L3 形态但目标环境无对应运行时
   b. 系统行为：该技能标记「环境不适用」，安装成功但不注册可调用解析器，回落到其它可用插件
   c. 用户感知：无（自动回落）；管理员可在插件管理界面看到该技能的环境状态

### 5.5 多解析器共存与优先级

#### 5.5.1 业务规则

1. **优先级声明**：插件必须声明 `priority`，允许同一格式多个解析器共存
   a. 验收条件：When 同一格式存在多个解析器, the 文档解析插件轨 shall 使宿主按优先级命中, 高优先级失败时回落次优
2. **禁止反向依赖**：插件不得 import 宿主私有模块或直连宿主私有表
   a. 验收条件：If 插件需要宿主能力, the 文档解析插件轨 shall 仅经契约暴露的宿主服务代理获取

---

## 6. 数据约束

### 6.1 ParseRequest（宿主下发，插件消费）
1. **filename**：必填。
2. **mimeType**：必填。
3. **bytes**：原始字节，必填。
4. **limits**：`maxChars` + `timeoutMs`，必填且插件必须遵守。

### 6.2 ParseResult（插件返回）
1. **status**：`ok` / `empty` / `error`，必填。
2. **parts**：`FilePart` 列表，可为空。
3. **error**：`status=error` 时必填。
4. **parserId** / **parserVersion**：必填。

### 6.3 FilePart
1. **source**：来源标注，必填。
2. **text**：可为空串。
3. **images**：可选。

### 6.4 ParserDescriptor（插件注册）
1. **parserId**：全局唯一，必填。
2. **formats**：MIME + 扩展名列表，至少一项非空。
3. **priority**：整数，必填。
4. **track**：`L2` / `L3`，必填。
5. **version**：必填。
6. **capabilities**：额外权限声明，可为空。

---

**文档状态**: spec **v1**（2026-10-15，子系统 spec 步产出）
**下一步**: `contract.md`（冻结）→ `design.md` → `tasks.md` → code → test（L1 + L2）
