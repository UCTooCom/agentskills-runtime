---
name: cangjie-coder
description: 仓颉代码编写技能（纯技能形态，不派生子 agent）。当用户需要编写、修改、重构或优化任何 .cj 仓颉代码文件时,必须使用此技能。主 agent 加载后按四步工作流自行执行：查阅文档 → 检索代码片段 → 编辑适配 → 写入文件，再按验证结果修复闭环（最多 3 次）。此技能确保所有仓颉代码完全符合语言规范,并提供最佳实践指导。
version: 4.0.0
author: OpenCangjie Team
# 知识库依赖：与本项目同目录的 ../CangjieSkills（渐进披露知识库，经 scripts/search_docs.py 查询），
# 不再依赖旧版 cangjie-language-guide / cangjie-full-docs 静态文档布局。
dependencies: []
# 说明：原 `agents:` 声明键与 skills/cangjie-coder/agents/ 目录已按 SDD tasks.md v3/T-18
# **下线**——"换脑子的才派生，换说明书的用技能"：编码不需要换脑子，需要的是确定的
# API 依据与工程内既有范式。四角色职责已并入下方「四步工作流」，由主 agent 直接执行。
scripts:
  - cangjie_syntax_check.ts  # TypeScript 版本（推荐）
  - cangjie_compile.ts       # TypeScript 版本（推荐）
  - cangjie_test_runner.ts   # TypeScript 版本（推荐）
  - cangjie_fix_suggest.ts   # TypeScript 版本（推荐）
  - cangjie_syntax_check.py  # Python 降级备选
  - cangjie_compile.py       # Python 降级备选
  - cangjie_test_runner.py   # Python 降级备选
  - cangjie_fix_suggest.py   # Python 降级备选
  - pkggraph.ts             # 包级循环依赖检测（TypeScript，推荐）
  - pkggraph.py             # 包级循环依赖检测（Python 降级备选）
---

## 脚本运行说明

本技能的脚本提供 TypeScript 和 Python 两个版本，**优先使用 TypeScript 版本**以减少对 Python 运行环境的依赖。

- **TypeScript 版本（推荐）**：`scripts/*.ts`
  - 运行方式：`node --experimental-strip-types scripts/<script>.ts [参数]`
  - 依赖：Node.js ≥22.6（推荐 v23.10+），无需额外 npm 包
- **Python 版本（降级备选）**：`scripts/*.py`
  - 运行方式：`python scripts/<script>.py [参数]`
  - 仅在 TypeScript 版本运行出错时降级使用

## 包依赖循环检测（pkggraph.ts / pkggraph.py）

仓颉**跨包反向 import 会直接触发 `cyclic dependency` 拒绝构建**。本工具解析工程内每个
`.cj` 的 `package` / `import` 声明，构建包级依赖图，用 Tarjan 强连通分量（SCC）算法检测
循环依赖——在以下场景**改动后立即跑一遍再编译**：

- 新增/调整 `package` 边界（新建文件写错包名、把工具类下沉到公共包）
- 改跨包 import（尤其引入新的 `magic.*` 反向依赖，例如 `bridge→tools→plugin→lrt→bridge` 环）
- 插件进程拆包、把模块从宿主抽到 `skills/<plugin>/src`

**两个版本功能完全一致**：`pkggraph.ts`（TypeScript，**推荐**）与 `pkggraph.py`（Python 降级备选）。
按技能通用约定**优先用 TypeScript 版本**以减少对 Python 运行环境的依赖；仅当 `node` 不可用
或 TS 版本运行异常时降级到 Python 版本。

### 运行方式（推荐：TypeScript）

```bash
# 进入工程根目录（含 src/），扫描 src/
node --experimental-strip-types skills/cangjie-coder/scripts/pkggraph.ts

# 指定源码根（相对当前目录或绝对路径）
node --experimental-strip-types skills/cangjie-coder/scripts/pkggraph.ts --root src
node --experimental-strip-types skills/cangjie-coder/scripts/pkggraph.ts --root apps/foo/src

# 输出 JSON（便于脚本化判断是否有环）
node --experimental-strip-types skills/cangjie-coder/scripts/pkggraph.ts --json
```

> 依赖：Node.js ≥ 22.6（推荐 v23.10+）。`--root` 相对**当前工作目录**解析，故务必在
> 「能看见 src/ 的那一层」执行，否则打印 `源码根目录不存在` 并以退出码 1 退出（误报）。

### 运行方式（降级：Python）

```bash
python skills/cangjie-coder/scripts/pkggraph.py
python skills/cangjie-coder/scripts/pkggraph.py --root src
python skills/cangjie-coder/scripts/pkggraph.py --json
```

### 输出与判定（两版本一致）

- 文本模式（默认）：

  ```
  === cyclic dependency (SCC size > 1) ===
  NONE                       # 无环，安全
  # 或
  * magic.x <-> magic.y     # 存在循环依赖的包集合（逐个列出）
  随后打印 packages=N edges=M cycles=K 汇总
  ```

- JSON 模式（`--json`）：`{"cyclic": [...], "packages": N, "edges": M, "cycles": K}`

- 退出码：`0` = 无环；`2` = 存在循环依赖；`1` = 参数/IO 错误。

### 依赖忽略规则（与仓颉构建一致）

只统计 `magic.*` 开头的 import（跨包边界）；`std*` / `ystyle` / `f_` / `jsonvalue`
等外部或同包引用一律忽略。`magic.a.b::{c}` 或 `magic.a.b::{c, d}` 取 `magic.a.b`；
其余 `magic.a.b.c` 逐级向上归并到已知包（SCC 只看包粒度，不看子目录文件）。

### 工程内既有用法

此前该工具位于 `apps/agentskills-runtime/.workbuddy/pkggraph.py`，现已纳入本技能并补齐
TypeScript 版本。典型调用（结束判据 grep `cyclic` / `NONE`）：

```bash
node --experimental-strip-types skills/cangjie-coder/scripts/pkggraph.ts 2>&1 | grep -i "cyclic\|NONE\|error"
```

# Cangjie Coder 技能（编排器模式）

## 概述

本技能用于编写、修改、重构和优化符合仓颉(Cangjie)编程语言规范的高质量代码文件(.cj 后缀)。通过4个专用subagent协作完成代码编写全流程，确保所有仓颉代码既符合规范又遵循最佳实践。

**适用场景**:
- ✅ 新建仓颉代码文件
- ✅ 修改现有仓颉代码
- ✅ 重构仓颉代码结构
- ✅ 优化仓颉代码性能
- ✅ 修复仓颉代码错误
- ✅ 添加新功能到现有代码
- ✅ 改进代码质量和可维护性

**核心工作流程**: 查阅文档 → 检索代码 → 编辑适配 → 验证代码（失败时自动修复闭环）

## 四步工作流（纯技能形态）

> **T-18 变更（2026-09-28）**：早期的「编排器模式 + 四个专用 subagent」已下线——
> `skills/cangjie-coder/agents/` 目录已删除，四个角色（doc-consultant / code-searcher /
> code-editor / code-verifier）的职责**并入下面这四步**，由**主 agent 自己按序执行**。
> 依据：SDD tasks.md v3 决策「换脑子的才派生，换说明书的用技能」——编码不需要换脑子，
> 需要的是确定的 API 依据与工程内既有范式。派生带来的上下文重建成本不再划算。

本技能由主 agent 加载后按四步执行（不再派生任何子 agent）：

```
主 agent（已加载 cangjie-coder）
    ├── Step 1: 查文档   → 查阅 CangjieSkills 文档（原 doc-consultant 职责）
    ├── Step 2: 检索代码 → 检索工程内既有代码片段（原 code-searcher 职责）
    ├── Step 3: 编辑适配 → 复制 + 最小适配 + 写入文件（原 code-editor 职责）
    └── Step 4: 验证     → 依据编译日志/复核清单自查（原 code-verifier 职责）
           │
           └── (验证失败) → 回到 Step 3 修复 → Step 4 重新验证，最多 3 次
```

### 四步职责对照（原 Subagent → 现由主 agent 直接执行）

| 步骤 | 原 Subagent | 职责 | 工具 | 输入 | 输出 |
|------|-------------|------|------|------|------|
| Step 1 | doc-consultant | 文档查阅 | search_docs.py, file_read | topic, detail_level | 文档摘要 |
| Step 2 | code-searcher | 代码检索 | file_read, file_search | query, doc_summary | 代码片段列表 |
| Step 3 | code-editor | 代码编辑 | file_read, file_write, file_edit | task_description, doc_summary, code_snippets | 代码文件 |
| Step 4 | code-verifier | 代码验证 | file_read, file_edit | file_path, verify_level | 验证结果 |

> 注：Step 4 **不执行 `cjpm build`**——编译与日志回传由人工在独立终端完成（项目职责边界），
> AI 只依据人工回传的日志做代码分析与修复建议。

### 自动修复闭环

当code-verifier验证失败时：
1. code-verifier生成修复建议
2. code-editor根据建议修复代码
3. code-verifier重新验证
4. 最多重试3次，超过后输出结果（含警告）

## 关键约束

- ⚠️ **必须先查阅文档**: 在编写任何仓颉代码前,必须先通过 `search_docs.py` 查阅 CangjieSkills 技能获取语言规范和最佳实践
- ⚠️ **禁止直接生成代码**: 不得直接使用大模型生成仓颉代码,必须先通过code-searcher检索现有代码片段或参考文档示例
- ⚠️ **必须符合规范**: 所有 .cj 文件必须符合仓颉词法和语法规范
- ⚠️ **工作流程**: 查阅(Consult) → 检索(Retrieval) → 编辑(Editing) → 验证(Verification)
- ⚠️ **适用所有场景**: 新建、修改、重构、优化、修复等所有涉及仓颉代码的操作都必须使用此技能
- ⚠️ **验证闭环**: 代码写入后必须通过code-verifier验证，验证失败时自动修复
- ⚠️ **编译报错必须一轮排净**: 修复编译错误时**不许只改日志里报出来的那几行**。cjpm 按包编译，
  未出错的包本轮根本没被检查，同类错误会在下一次编译时集中爆发。交还人工编译前必须执行
  《编译报错「一轮排净」规程》：跑 `scripts/cangjie_precompile_scan.{ts,py}` + 做同族全域 grep，
  自查口径是 **「扫描 ERROR = 0」** 而非「日志里那几行改完了」
- ⚠️ **检查规则须先验误报率**: 新增任何静态检查/自造规则前，必须先在大库上跑一遍确认误报率。
  也不要凭直觉给代码补 `import`（本仓 `ArrayList`/`HashMap` 均属 prelude，无需 import，详见 §「反例教训」）

---

## 配置项

### CangjieSkills 技能路径

```
CANGJIE_SKILLS_PATH: ../CangjieSkills
```

### 仓颉编程资料目录

```
CANGJIE_CODE_REPOSITORY: D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\CangjieMagic\resource
```

**重要**: 
- CangjieSkills 技能路径指向最新版官方技能根目录，采用脚本化渐进披露检索（`<skill-root>/scripts/search_docs.py`），不要绕过脚本直接读取知识库文件
- 仓颉编程资料目录用于检索现有代码片段
- 两个路径可在使用本技能时由用户配置

### 跨平台路径处理

- **Windows 系统**: 使用双反斜杠 `\\` 作为路径分隔符
- **Linux/Mac 系统**: 使用正斜杠 `/` 作为路径分隔符

---

## 四步工作流程

### 步骤 1: 查阅 CangjieSkills 文档 (Consult)

**目的**: 获取仓颉语言规范、最佳实践和 API 文档

#### 1.1 确定需求主题

根据用户请求,确定需要查阅的主题与不确定的符号:

| 需求类型 | 查询域 (--domain) | 典型查询示例 |
|---------|---------|-------------|
| 基础语法 | language | `--query "for 循环"` / `--query "pattern match"` |
| 类型定义 | language | `--query "class 定义"` / `--query "enum 泛型"` |
| 标准库 API | std | `--query "ArrayList reverse"` / `--query "HashMap iteration"` |
| 扩展标准库 | stdx | `--query "stdx.net.http HttpClient"` |
| 工具链 | tools | `--query "cjpm build"` / `--query "cjpm init"` |
| 应用示例 | examples | `--query "http server 示例"` / `--query "websocket 示例"` |

> 新版 CangjieSkills 采用"主题索引 → 细分索引/API 成员表 → 叶子契约与示例"的渐进披露结构，统一通过 `<skill-root>/scripts/search_docs.py` 脚本查询，不要绕过脚本直接 file_read 知识库文件。把 `CANGJIE_SKILLS_PATH`（`../CangjieSkills`）记为 `<skill-root>`。

#### 1.2 批量摘要查询（首选）

第一次知识访问使用一个脚本进程中的批量查询，每个独立符号或意图各写一个 `--query`；只有必须共同出现的"类型 + 操作"才放在同一查询中。摘要足够时停止，不为简单成员再展开正文。

```bash
python <skill-root>/scripts/search_docs.py \
  --query "ArrayList reverse" \
  --query "Int64 writeBigEndian" \
  --query "cjpm run arguments" \
  --max-results 2
```

- 默认每项返回 3 个候选；精确符号可用 `--max-results 1`，歧义时再扩大
- 可用 `--domain language|std|stdx|tools|examples` 限域
- 不要把互不相关的符号塞进一个长查询
- 结果标记 `ordinary_use_ready` 时，已包含普通调用所需的活动签名与契约；仅在任务还涉及异常、边界或完整示例时展开叶子

#### 1.3 浏览索引树 / 批量读取叶子

不熟悉的领域先读最窄索引；需要参数、异常、限制或完整示例时再把选定 ID 合并为一次叶子查询：

```bash
# 浏览索引树
python <skill-root>/scripts/search_docs.py --node language.collections --view indexes
python <skill-root>/scripts/search_docs.py "集合类型" --view indexes

# 批量读取叶子正文
python <skill-root>/scripts/search_docs.py \
  --query "ArrayList reverse" \
  --query "HashMap tuple iteration" \
  --view leaves
```

- `indexes` 返回节点下全部非叶子页面，API 类型页本身就是成员列表
- `leaves` 可把多个独立 `--query` 与多个精确 `--node` 一次解析、合并并去重
- 宽 API/主题会被拒绝，先读索引并用普通查询选出精确 ID，不要把 `--force` 当作常规流程
- 应用示例固定为"场景分类 → 示例叶子"：先普通查询场景，选中后读取一个或少量示例 ID

#### 1.4 stdx 自动配置（如涉及扩展标准库）

项目导入 `stdx.*` 时，先运行脚本按 `cjc -v` 选择兼容 stdx 并全局复用 `~/.cangjie/stdx/`：

```bash
python <skill-root>/scripts/setup_stdx.py --project <project-root>
# 离线：--archive <release.zip> --offline
# 配置已有构建的项目后先 cjpm clean
```

#### 1.5 查询缺口处理

无结果时依次缩短查询、改用仓颉精确符号、添加 `--domain`，或从最窄相关索引选择叶子；不要枚举知识库文件。若活动知识页仍缺少契约，使用当前工具链构造最小可复现实验并在交付中指出知识缺口，不凭其他语言经验猜写 API。

#### 1.6 提取关键信息

从查询结果中提取:
- ✅ 语法规范和关键字
- ✅ API 签名与使用方法（包、命名参数、返回值、异常）
- ✅ 最佳实践建议
- ✅ 常见错误和注意事项
- ✅ 代码示例

---

### 步骤 2: 检索代码片段 (Retrieval)

**目的**: 从代码片段库中找到可复用的代码基础

#### 2.1 确定搜索关键词

基于步骤 1 的文档查阅结果,确定搜索关键词:

**关键词选择策略**:
1. **功能关键词**: 具体功能名称 (如 "HttpServer", "WebSocket", "HashMap")
2. **语法关键词**: 语法结构 (如 "class", "func", "import", "package")
3. **标准库关键词**: 标准库模块 (如 "std.net.http", "std.collection")
4. **组合关键词**: 功能 + 语法 (如 "HttpServer class", "func listen")

#### 2.2 执行搜索

使用 `file_search` 工具搜索代码片段:

```json
{
  "toolcall": {
    "thought": "搜索包含HTTP服务器功能的仓颉代码片段",
    "name": "file_search",
    "params": {
      "path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\CangjieMagic\\resource",
      "query": "HttpServer",
      "recursive": true,
      "caseSensitive": false,
      "filePattern": "*.cj"
    }
  }
}
```

#### 2.3 筛选结果

**筛选标准**:
1. **相关性**: 代码是否实现了所需功能
2. **质量**: 代码结构是否清晰,注释是否完整
3. **规范性**: 代码是否符合仓颉语法规范
4. **可维护性**: 代码是否易于修改和扩展

**优先级排序**:
1. 完全匹配需求的代码
2. 部分匹配但易于修改的代码
3. 通用性强可作为基础的代码

#### 2.4 读取选中代码

使用 `file_read` 工具读取选中的代码片段:

```json
{
  "toolcall": {
    "thought": "读取选中的HTTP服务器代码片段",
    "name": "file_read",
    "params": {
      "path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\CangjieMagic\\resource\\http_server.cj"
    }
  }
}
```

---

### 步骤 3: 编辑适配 (Editing)

**目的**: 根据项目需求和最佳实践修改代码片段

#### 3.1 分析原始代码

对照步骤 1 查阅的文档,分析原始代码:
- ✅ 检查语法是否符合规范
- ✅ 检查是否遵循最佳实践
- ✅ 检查是否有潜在问题
- ✅ 确定需要修改的部分

#### 3.2 应用最佳实践

根据 CangjieSkills 文档中的最佳实践:

**代码风格**:
- 使用有意义的变量名和函数名
- 添加必要的注释和文档
- 遵循仓颉命名规范 (驼峰命名)
- 保持代码缩进和格式一致

**性能优化**:
- 避免不必要的对象创建
- 使用合适的数据结构
- 合理使用不可变变量 (let)
- 注意内存管理

**错误处理**:
- 使用 Option 类型处理可能为空的值
- 使用 try-catch 处理异常
- 提供有意义的错误信息
- 避免忽略错误

**安全性**:
- 验证输入参数
- 避免资源泄漏
- 使用安全的 API
- 处理边界情况

#### 3.3 修改代码

根据项目需求修改代码:

**常见修改类型**:
1. **调整函数签名**: 修改参数类型、返回类型
2. **修改类型声明**: 调整类、结构体定义
3. **适配命名规范**: 修改变量名、函数名
4. **添加功能**: 增加新的方法或属性
5. **优化性能**: 改进算法或数据结构
6. **增强错误处理**: 添加异常处理和验证

**修改示例**:

原始代码:
```cangjie
func startServer(port: Int): Unit {
  let server = http.HttpServer()
  server.listen(port)
  println("Server started")
}
```

修改后代码:
```cangjie
/// 启动HTTP服务器
/// 
/// 参数:
///   - port: 监听端口号,有效范围 1-65535
/// 
/// 返回:
///   - Option<HttpServer>: 成功返回服务器实例,失败返回 None
func startServer(port: Int): Option<HttpServer> {
  // 参数验证
  if (port < 1 || port > 65535) {
    println("Error: Invalid port number ${port}")
    return None
  }
  
  // 创建服务器
  let server = HttpServer()
  
  // 启动监听
  try {
    server.listen(port)
    println("HTTP Server started on port ${port}")
    return Some(server)
  } catch (e: Exception) {
    println("Error: Failed to start server - ${e.message}")
    return None
  }
}
```

#### 3.4 验证语法

确保修改后的代码符合仓颉语法规范:

**词法验证**:
- [ ] 标识符命名符合规范
- [ ] 关键字使用正确
- [ ] 字符串格式正确
- [ ] 注释格式正确

**语法验证**:
- [ ] 包声明正确
- [ ] 导入语句正确
- [ ] 函数定义格式正确
- [ ] 变量声明格式正确
- [ ] 控制语句结构正确
- [ ] 类定义格式正确

**语义验证**:
- [ ] 函数调用参数正确
- [ ] 变量使用合理
- [ ] 错误处理完善
- [ ] 代码逻辑清晰

---

### 步骤 4: 写入文件 (Writing)

**目的**: 将修改后的代码写入正确的文件位置

#### 4.1 确定文件路径

根据项目结构确定文件路径:

**路径规划原则**:
1. **按功能模块组织**: 相关功能放在同一目录
2. **遵循项目约定**: 遵循现有项目的目录结构
3. **便于维护**: 路径清晰,易于查找
4. **避免冲突**: 不覆盖现有文件

**常见目录结构**:
```
project/
├── src/
│   ├── main.cj          # 主入口
│   ├── api/             # API 相关
│   │   ├── http_server.cj
│   │   └── websocket.cj
│   ├── models/          # 数据模型
│   │   ├── user.cj
│   │   └── product.cj
│   ├── services/        # 业务逻辑
│   │   └── auth.cj
│   └── utils/           # 工具函数
│       └── helper.cj
└── tests/
    └── test_main.cj     # 测试文件
```

#### 4.2 创建目录结构

使用 `directory_create` 工具创建必要的目录:

```json
{
  "toolcall": {
    "thought": "创建API模块的目录结构",
    "name": "directory_create",
    "params": {
      "path": "D:\\project\\src\\api",
      "recursive": true
    }
  }
}
```

#### 4.3 写入代码文件

使用 `file_write` 工具写入 .cj 文件:

```json
{
  "toolcall": {
    "thought": "写入修改后的HTTP服务器代码",
    "name": "file_write",
    "params": {
      "path": "D:\\project\\src\\api\\http_server.cj",
      "content": "// HTTP服务器模块\npackage api\n\nimport std.net.http\n\n/// 启动HTTP服务器\nfunc startServer(port: Int): Option<HttpServer> {\n  // 实现代码...\n}\n",
      "mode": "create"
    }
  }
}
```

#### 4.4 验证写入结果

确认文件已正确创建:
- ✅ 文件路径正确
- ✅ 文件内容完整
- ✅ 文件编码正确 (UTF-8)
- ✅ 文件权限正确

---

## 仓颉 JSON 编码易错点（compile-error 高发区）

> 凡涉及 `stdx.encoding.json` 的类型判别 / 取值，一律走 `magic.jsonable.JsonUtils` 的安全转换（返回 `Option<T>`），**不要用 `as` 强转 + `let Some(...) <-` 绑定模式**——编译器会报 `unclosed delimiter: '('`（误把 `as` 表达式塞进绑定模式）。

- ❌ `if (let Some(arr) <- v as JsonArray) { ... }` → 解析错误 `unclosed delimiter: '('`。
- ✅ `if (let Some(arr) <- JsonUtils.asJsonArray(v)) { ... }`（`asJsonArray` / `asJsonObject` 返回 `Option<JsonArray>` / `Option<JsonObject>`）。
- 取 JSON 字符串值用 `JsonUtils.toString(j): Option<String>`（**没有** `asJsonString`）；取数值用 `JsonUtils.toFloat` / `toInt`。
- `JsonArray` 不支持 `for-in` 迭代器，必须 `for (item in arr.getItems())`（已有先例 `checkpoint_manager.cj:63`）。
- 类型判断用 `v is JsonArray` / `v is JsonString`；需要取值时**先 `is` 判断再 `asString()/asInt()/asBool()` + `.getValue()`**（同范式见 `LlmRouteRuleController.cj` `jsonValueToAny`），不要把 `as` 塞进绑定模式。

### 附：`None<T>()` 与 `ArrayList` 元素赋值（本仓高频编译错）

- **`None<T>()` 是错的**（`no matching function for operator '()' function call`）：`None<T>` **不带括号**才是合法写法，错在尾部多了 `()` 把枚举变体当函数调用。
  - ✅ `return None<ModelRouteRulePO>`、`po.deletedAt = None<DateTime>`、`var best: Option<T> = None<T>`
  - ❌ `return None<ModelRouteRulePO>()`、`var best: Option<T> = None<T>()`
  - 形参/返回值类型已标注时也可直接写 bare `None`。
- **`ArrayList` 没有 `.set(i, v)`**（`'set' is not a member of class 'ArrayList<T>'`）：本版本用**下标赋值**改元素。
  - ✅ `order[i] = x; order[j] = tmp`（先例 `RouteRegistry.cj:43-44` 冒泡交换、`faiss_database.cj:74`、`mcp_call_cli.cj:113`）
  - ❌ `order.set(i, x)`
  - 读取仍是 `arr.get(i)`（返回 `Option<T>`，配 `.getOrThrow()` / `if (let Some(v) <- arr.get(i))`）。

> **自查命令**（改完 JSON/Option/ArrayList 相关代码后跑一次，零命中才算干净）：
> ```bash
> grep -rn "None<[^>]*>()\|\.set(\|<- .* as Json" src/
> ```

---

## 编译报错「一轮排净」规程（compile-round 强制要求）

> **核心要求：修复编译报错时，不许只改日志里报出来的那几行。必须在一轮之内把「同类
> 错误」在整个工程里排干净，避免让人工反复执行 `cjpm build`。**

### 为什么必须一轮排净

cjpm/cjc 是**按包**编译的：某个包编译失败时，该包的检查立即中止，而**尚未轮到的包
根本不会被检查**。所以一轮日志通常只暴露「第一个出错包的前几条错误」。

**实测案例**（installer 子工程首轮 `cjpm build`）：日志只报了 `log.cj` 的 2 个错，
但同一工程里还潜伏着 `args.cj` 的 6 处同类错、`redact.cj` 的 2 处、`main.cj` 的 1 处
——它们分属 `uc_installer.cli` 包和根包，**本轮完全没被检查**。若只改那 2 行，
人工就得连跑四五轮编译。

### 规程（修完日志里的报错后、交还人工编译前必做）

1. **跑静态扫描**（推荐：一次扫完形态固定的已知错误）：
   ```bash
   # 推荐 TypeScript 版（与目录内其他脚本用法一致）
   node --experimental-strip-types \
     <skill-root>/scripts/cangjie_precompile_scan.ts --src <源码根目录>

   # 或 Python 版
   python <skill-root>/scripts/cangjie_precompile_scan.py --src <源码根目录>
   ```
   退出码 `0` = 无 ERROR，可提交编译；`1` = 仍有 ERROR；`--json` 输出结构化结果。
   规则集见脚本头注释：**E1** 后置 `?` 类型、**E2** match 臂多语句块、
   **E4** `Array<T>` 调增删方法、**E5** 控制流缺花括号、**E6** main 返回类型被推断为 bottom type、
   **W1** `let` 重赋值（WARN 级）。

2. **做「同族全域 grep」**：编译器报的每一类错，都要假设它在别处也存在。通读**所有**
   本次新增/修改过的 `.cj` 文件（不只报错那一个），按下面的清单逐个对照。

3. **修的是根因类别，不是报错的那一行**：看到一个 `match` 臂块错，就把所有 `match`
   臂块都改掉；看到一个类型注解错，就把所有类型注解都核对一遍。

### 六类实测编译错误（原文报错 → 根因 → 修法）

| 规则 | 原文报错 | 错误写法 | 根因 | 正确写法 |
|------|---------|---------|------|---------|
| **E1** | `expected ';' or '<NL>', found '?'` | `var logger: Logger? = None` | **Rust 语法误用**。仓颉可选类型是**前置** `?T` | `Option<Logger> = None<Logger>` 或 `?Logger` |
| **E2** | `expected '=>' in lambda expression, found keyword 'let'` | `case None => {`<br>`    let l = ...`<br>`}` | `=>` 后的 `{` 被解析为 **lambda 起始**，块内首条 `let` 被当成缺 `=>` 的 lambda 参数 | 逻辑外提成函数，臂只留单表达式；或改 `if/else` 分支表达式 |
| **E4** | `'add' is not a member of class 'Array<T>'` | `command: Array<String>` 却调用 `command.add(x)` | `Array<T>` 是**定长数组**，没有 `add/append/remove` | 改用 `ArrayList<T>`，或改用 `arr[i] = v` |
| **E5** | `expected '{', found 'STATUS_MANUAL'` | `it.status = if (c) A else B` | **仓颉 `if` 的花括号是语法的一部分**，分支体必须是代码块 `{...}`，不能只写一个表达式 | `it.status = if (c) { A } else { B }` |
| **E6** | `return type of 'main' is not 'Integer' or 'Unit'` | `main(args: Array<String>) {` …末句 `exit(code)` | **省略返回类型时按函数体最后一个表达式推断**；`std.env.exit(code: Int64): Nothing` 是 bottom type ⇒ 推断出 `Nothing`，而 main 的返回类型只允许 `Unit` 或整数类型 | `main(args: Array<String>): Unit {`，或改成整数返回类型后用 `return code` 退出 |
| **W1** | `cannot assign to immutable value` | `let cur = StringBuilder()` … 后文 `cur = StringBuilder()` | `let` 声明的变量不可重新赋值 | 改 `var`，或改为不可变量重新绑定 |

### E5 的规范依据与「正则 vs 配平」教训

**语法依据**（`language.basic_concepts.3-表达式.3-2-if-条件判断`）：

> 语法：`if (cond) { exprs1 } else { exprs2 }`，`cond` 是 `Bool` 类型表达式

即 **`if` / `while` / `for` 的分支体一律写花括号**，`while (cond) { exprs }`、`for (x in c) { exprs }` 同理。
这条与另一件常被混淆的事无关但容易并提：仓颉**不允许独立的 `{exprs}` 块作为表达式**
（`let r = { let x = 2; x ** 3 }` 不合法）——代码块只能依附于 if/while/for-in/match/函数。
顺便：`if` 用作值时，**有 `else`** 才取「所执行分支最后一个表达式的值」，**无 `else` 时类型恒为 `Unit`**。

**两条必须内置的例外/注意**：

1. **`do { exprs } while (cond)` 的尾部 `while` 本就无块**，不能报。判据：该行去空白后以 `}` 开头。
   实证：本仓唯一的 2 条潜在误报就是 `src/dsl/parser.cj:34/46` 的 do-while。
2. **扫这类问题必须用「括号配平」，不能用正则 `\)\s*[^ {]`**。
   后者会把 `if (hasValue(args, idx)) {` 里 `hasValue(...)` 的**第一个** `)` 当成条件结束
   （紧随的第二个 `)` 正好命中「非空格非 `{`」），在 `installer/src` 上一次性炸出 **20 条假阳性**。
   正确做法：从 `(` 起计数配平到对应的 `)`，再取其后第一个非空白 token 判是否为 `{`。

> E5 规则上线前的验证记录：含缺陷样本命中 3 处真缺陷（含用作值的单行 if-else），
> 而在 1140 个已编译通过的宿主文件上**零误报**；Py / TS 双版本结果逐条一致。

### E6 的规范依据与「bottom type 污染返回类型推断」

**语法依据**（`language.package.3-程序入口.3-1-main-函数` / `3-2-main-函数示例`）：

> - 返回类型：`Unit` 或整数类型
> - 示例：`main(): Int64 { return 0 }`、`main(args: Array<String>): Unit { ... }`
> - ❌ 返回类型不能是 `String`；❌ 参数类型只能是 `Array<String>`

**根因机制**：仓颉**省略返回类型标注时，按函数体最后一个表达式推断**。
而 `std.env.exit(code: Int64): Nothing` 返回 **`Nothing`**（bottom type）。
于是「末句是 `exit(...)` 的 main」被推断为返回 `Nothing` —— 它既不是 `Unit` 也不是整数，
直接报 `return type of 'main' is not 'Integer' or 'Unit'`。

**这一族最容易误判的地方**：本仓明明有大量 `main(args: Array<String>) {` 的无标注写法
（`crudgen.cj:30` / `crudweb.cj:31` / `loaddbinfo.cj:32` / `plugingen.cj:40`）且都能编译通过
——所以**「没写返回类型」本身不是错**，真正的触发条件是「末句返回 bottom type」。
据此写了只命中组合条件的 E6 规则；在这批文件上（末句均为 `println` 等 Unit 调用）**零误报**。

**修法二选一**（本轮选了前者，因改动最小且不触碰已验证可用的 `exit` 终止语义）：

```cangjie
// ✅ 方案 A：显式标注 Unit，保留 exit 设退出码
main(args: Array<String>): Unit {
    ...
    exit(report.exitCode)
}

// ✅ 方案 B：改用整数返回类型，用 return 退出（文档示例形态）
main(args: Array<String>): Int64 {
    ...
    return report.exitCode
}
```

> **规则实现上的两个坑**（写静态检查时务必注意）：
> ① 判定 body 边界**必须做花括号配平且剔除字符串字面量** —— 否则 `sb.append("{")`
> 里的花括号会让函数「提前收尾」，末句判定失准。本项目用「body 内嵌字符串花括号 +
> 末句为 exit」的变异样本验证过：剔除正确时才命中。
> ② 只对 **`main`** 报 ERROR。普通函数推断出 `Nothing` 未必错，别扩大适用范围。

> E6 规则上线前验证：正例样本命中；天然负例为修复后的 `installer/src/main.cj`
> （已标注 `: Unit`、末句同样是 `exit`，零命中）；全库 1140+ 文件零误报；Py / TS 双版本结果一致。

另有一类不报编译错但会导致流程挂死的做法，一并规避：

- **`let x: T` 先声明、再在多个分支里赋值**（如 `if` / `else if` 链各分支给 `report` 赋值）。
  虽然仓颉有定赋值推断，但这种写法容易同时踩「不可变赋值」与「推断失败」两个坑。
  **改法：把分支逻辑抽成返回值的函数**（如 `dispatch(parsed): Report`），在声明处直接
  `let report = dispatch(parsed)` 完成确定赋值。注意此时常需要补回被移除的 `import`。

### E2 的裁定依据（别判过头）

`case X => {` **并非一律非法**，本仓存在差异：

- ✅ **合法**：`{` 的下一行去空白后紧跟**裸 `=>`**（零参 lambda 写法）——先例
  `src/app/middlewares/auth/JWTAuthMiddleware.cj`。该形态能通过编译，因为它确实是个 lambda。
- ⚠️ **不可作先例**：`src/test/**` **不在主构建图内**（`cjpm build` 不编译），其中的写法
  即使有问题也不会报错。`agent_loader_test.cj:20/35` 目前扫描仍命中 E2，属
  **潜在未暴露的编译错误**，只在 `cjpm test` 时才会现形。

> 判断有歧义时一律**回避该形态**（改 if/else 或外提函数），尤其在分支内要改写外层变量时。

### ⚠️ 反例教训：勿凭「这个类型该不在 prelude」的直觉去补 import

本次一度按直觉给文件补了 `import std.collection.ArrayList`，并据此写了一条 E3 检查规则。
**大库实证证伪**（本仓 `src/`，均能通过编译）：

- 512 个文件使用 `ArrayList`，其中 **248 个从未 import**；
- 430 个文件使用 `HashMap`，其中 **314 个从未 import**。

即二者均在 prelude 内，**不需要 import**（补了通常无害，但属冗余改动）。

同一族故障的第三例（2026-10-08 installer 第二轮编译）：`eprintln` 写了 console 包的 import
→ 报「符号在该包不可访问」。它实际属 **`std.core`**（`std.core.func.eprintln`），默认可见。
**本仓 src/ 里有 8 个文件直接调用 `eprintln`，全部没有任何 console 包 / io 包的 import。**
至此这张 prelude 表已有三例：**`ArrayList` / `HashMap` / `eprintln`（及既有的 `StringBuilder` / `Duration`）**。

> ⚠️ 顺带记一条**自伤**：写完这条修复后，我把错误的 import 原文写进了代码注释，
> 导致日后 `grep -rn "import.*console"` 命中注释产生**假阳性**。
> **注释里不要写错误写法的原文**，要说就写成「console 包 / io 包」这类描述性文字。

**结论：检查规则上线前必须先在大库上验证误报率。** 误报率高的规则比没有规则更糟：
本轮 W1 规则首版在 1140 个文件上炸出 **564 条误报**，根因是用了「全文件的 let 名字集合」
而未划作用域；改成「以函数签名为边界、取作用域内最后一次声明的 kind」后降为 **0 条**，
同时对真实的同作用域重赋值仍准确命中。

> 不确定某个类型是否属于 prelude 时，用这条命令实证（看有多少在用却未 import 的文件）：
> ```bash
> for f in $(grep -rl "ArrayList<" --include=*.cj src/); do
>   grep -q "import std.collection.ArrayList\|import std.collection.\*" "$f" || echo "无import却能用: $f"
> done | wc -l
> ```

---

## 子进程 / 网络 / 环境变量：std API 实测契约（installer Phase 1 沉淀）

来源：2026-10-08 `installer/src/platform/`（T006 子进程超时强杀、T007 进程表、
T008 环境变量、T009 端口探测）四份实现逐条核对的结果。**每一条都有文档叶子或工程实证。**

### 同 package 跨文件不需要 import

**这一条直接决定「要不要补 import」，错了就是 `undeclared identifier`。**

仓颉的 package 是**编译单元而非文件单元**：同一个 package 下所有文件的顶层符号互相直接可见，
**不需要 import**，import 只用于跨包。

**实证（建模：全 `src/` 扫描）**：同 package 跨文件引用符号且未 import 本包的文件数 = **328**。
典型如 `magic.agent.base` 包的 `base_agent.cj` 直接引用同包 `abs_agent.cj` 的 `AbsAgent`；
`magic.agent_executor` 包的 `dag_scheduler.cj` 直接用 `dag_config.cj` 的 `StepConfig`。

验证命令（换包名即可自查）：

```bash
grep -rhoE "^package .+" src/<dir>/*.cj | sort -u
# 看该包下的文件是否 import 了本包 —— 大量「没有」就是免 import 的实证
```

⚠️ 反过来别被害：**跨包**（哪怕名字很像）仍然必须 import。
`report.cj` 写 `import uc_installer.util.{jstr, jint}` 是因为它身在 `uc_installer.cli`。

### `SubProcess.wait(timeout!:)` 超时是抛异常，不是返回哨兵值

```cangjie
let outcome = try {
    p.wait(timeout: cap)          // wait(timeout!: ?Duration = None): Int64
} catch (_: TimeoutException) {   // ← TimeoutException <: Exception，package = std.core（默认可见）
    WAIT_TIMEOUT_SENTINEL         // 哨兵值要自己约定；真实退出码不会是负数
}
```

契约原文（`references/api/std/process/classes/subprocess/wait.md`）：
「阻塞等待子进程执行返回或**等待超时后抛出超时异常**」＋「异常：`TimeoutException`」。

⚠️ **不要按设计文档的示意去写 `if (code != TIMEOUT_SENTINEL)`** —— 那是假定返回值的写法，
按它写就完全 catch 不到超时。installer 的 design.md §4.3.2 原有这个错，已在 2026-10-08 订正。

### Pipe 模式必须先排空管道，否则 `wait` 的超时也救不回来

契约原文警告：「对于需要操作标准流的场景（Pipe 模式），使用者需要优先处理标准流，
**避免子进程标准流缓冲区满后调用本函数产生死锁**」。

机制：子进程写满管道缓冲区后阻塞 → 它永远不退出 → `wait` 再设 timeout 也只会等到超时、
拿不到任何输出。**正确做法是在 wait 之前把两个管道交给独立线程**：

```cangjie
let outPipe = p.stdOutPipe          // stdOutPipe: InputStream
let errPipe = p.stdErrPipe
let outFut: Future<Array<Byte>> = spawn { drainToArray(outPipe) }
let errFut: Future<Array<Byte>> = spawn { drainToArray(errPipe) }
let outcome = try { p.wait(timeout: cap) } catch (_: TimeoutException) { SENTINEL }
let stdoutBytes = awaitDrainedBytes(outFut)   // 用有上限的 get(cap) 收敛，别用无参 get()
```

`InputStream` 只有 `read(buffer: Array<Byte>): Int64`（返回本次读到的字节数），
**没有 `readToEnd`** —— 那个是 `StringReader` 的成员，别混用。

### `Future.get(timeout:)` 是位置参数，调用时不能带标签

| 调用 | 形参签名 | 性质 | 正确写法 |
|---|---|---|---|
| `Future.get(...)` | `get(timeout: Duration): T` | **位置参数**（无 `!`） | `fut.get(cap)` |
| `SubProcess.wait(...)` | `wait(timeout!: ?Duration = None)` | 命名参数（有 `!`） | `p.wait(timeout: cap)` |
| `Process.terminate(...)` | `terminate(force!: Bool = false)` | 命名参数（有 `!`） | `p.terminate(force: true)` |

写成 `fut.get(timeout: cap)` 会报 `invalid named arguments prefix 'timeout:'`。
**有没有感叹号是唯一判据** —— 别按「看起来像配置项」来猜。

### 其它逐条核对过的点

| 事项 | 结论 | 依据 |
|---|---|---|
| `String.fromUtf8Unchecked` | **必须用 `unsafe { }` 包裹** | 宿主 5 处实证：`ScriptExecutor.cj:96`、`lrt_host_executor.cj:911`、`CrudGenService.cj:213` 等 |
| `HashMap(getVariables())` | 一律**不带泛型实参**，泛型由左侧类型标注或返回值位置给出 | 宿主 3 处同款：`ScriptExecutor.cj:76`、`utils/os.cj:62`、`:92` |
| `Path` | 属 **`std.fs`**（不在 prelude，必须 import） | `import std.fs.{File, OpenMode, Path, exists, Directory}` |
| `environment!` 形参 | 实际类型是 `?Map<String,String>`，传 `HashMap` 会被自动装箱 | `ScriptExecutor.cj:34` 传 HashMap 实证 |
| `TcpSocket(host, port)` | port 是 **`UInt16`**，需 `UInt16(port)` 转换 | `HTTPServer.cj:284` `listenAndServeTls(host, UInt16(port))` |
| `SocketTimeoutException` | 属 **`std.net`**，需显式 import | `references/api/std/net/classes/sockettimeoutexception` |
| `TimeoutException` | 属 **`std.core`**，默认可见，无需 import | `std.core.class.timeoutexception` |
| `StringBuilder.size` | 存在（`size: Int64`） | `std.core.class.stringbuilder.prop-size` |
| `Array<T>.isEmpty()` | 存在 | `std.core.struct.array.isempty` |
| 字符串里的反斜杠 | `\\` 表示单个反斜杠，**合法** | 宿主实证 `SyncController.cj:34` 的 `"\\\\"` |
| Rune 转义字面量 | `r'\n'` / `r'\t'` 合法（前缀 `r` 不可省） | `decision_point.cj:51/53`、`adapter_http.cj:213` |
| enum 限定值访问 | `EnvScope.USER` 这种 `EnumName.CASE` 合法 | `Logger.cj:123` 的 `LogLevel.INFO` |

**Windows 环境变量写入的坑（`setx` 与 `setVariable` 必须成对）**：
`setx` 只改注册表（持久化），**不改变当前进程已加载的环境块**；
常驻进程 spawn 的子进程默认继承父进程环境，所以**只调 setx 的话，紧接着起来的子进程看不到新变量**。
正确做法是写完 setx 再 `setVariable` 同步当前进程 —— 配套地，子进程环境要**每次重新**
`HashMap(getVariables())` 构造（而非启动时缓存），`runCapped` 就是这样做的。

---

## 完整使用示例

### 示例 1: 生成 HTTP 服务器代码

**用户请求**: 生成一个监听 8080 端口的 HTTP 服务器代码

#### 步骤 1: 查阅文档

```bash
python ../CangjieSkills/scripts/search_docs.py \
  --query "http server" \
  --query "HttpServer listen" \
  --domain examples \
  --max-results 2
```

**提取关键信息**:
- 使用 `std.net.http` 模块
- 创建 `HttpServer` 实例
- 使用 `listen(port)` 方法
- 需要处理异常情况

#### 步骤 2: 检索代码

```json
{
  "toolcall": {
    "thought": "搜索HTTP服务器代码片段",
    "name": "file_search",
    "params": {
      "path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\CangjieMagic\\resource",
      "query": "HttpServer listen",
      "recursive": true,
      "filePattern": "*.cj"
    }
  }
}
```

#### 步骤 3: 编辑适配

读取并修改代码,添加:
- 参数验证
- 错误处理
- 详细注释
- 最佳实践

#### 步骤 4: 写入文件

```json
{
  "toolcall": {
    "thought": "写入HTTP服务器代码",
    "name": "file_write",
    "params": {
      "path": "D:\\project\\src\\api\\http_server.cj",
      "content": "package api\n\nimport std.net.http\n\n/// HTTP服务器模块\n/// 提供HTTP服务器的创建和启动功能\n\n/// 启动HTTP服务器\n/// \n/// 参数:\n///   - port: 监听端口号,有效范围 1-65535\n/// \n/// 返回:\n///   - Option<HttpServer>: 成功返回服务器实例,失败返回 None\npublic func startServer(port: Int): Option<HttpServer> {\n  // 参数验证\n  if (port < 1 || port > 65535) {\n    println(\"Error: Invalid port number ${port}\")\n    return None\n  }\n  \n  // 创建服务器实例\n  let server = HttpServer()\n  \n  // 启动监听\n  try {\n    server.listen(port)\n    println(\"HTTP Server started on port ${port}\")\n    return Some(server)\n  } catch (e: Exception) {\n    println(\"Error: Failed to start server - ${e.message}\")\n    return None\n  }\n}\n\n/// 主函数\nmain() {\n  let result = startServer(8080)\n  match (result) {\n    case Some(server) => println(\"Server is running\")\n    case None => println(\"Failed to start server\")\n  }\n}\n",
      "mode": "create"
    }
  }
}
```

---

### 示例 2: 生成数据模型类

**用户请求**: 生成一个 User 数据模型类,包含 id、name、email 字段

#### 步骤 1: 查阅文档

查阅 `class` 相关知识（通过 `<skill-root>/scripts/search_docs.py` 批量查询 `--query "class 定义" --query "class 成员" --domain language`）了解:
- class 定义语法
- 成员变量声明
- 构造函数定义
- 属性访问器

#### 步骤 2: 检索代码

搜索 "class User" 或 "data model" 相关代码片段

#### 步骤 3: 编辑适配

根据最佳实践修改:
- 使用 `public` 修饰符
- 添加构造函数
- 添加属性访问器
- 添加文档注释

#### 步骤 4: 写入文件

```cangjie
package models

/// 用户数据模型
/// 
/// 表示系统中的用户实体
public class User {
  /// 用户唯一标识
  public let id: Int64
  
  /// 用户名
  public mut prop name: String
  
  /// 用户邮箱
  public mut prop email: String
  
  /// 构造函数
  /// 
  /// 参数:
  ///   - id: 用户ID
  ///   - name: 用户名
  ///   - email: 用户邮箱
  public init(id: Int64, name: String, email: String) {
    this.id = id
    this.name = name
    this.email = email
  }
  
  /// 验证邮箱格式
  /// 
  /// 返回:
  ///   - Bool: 邮箱格式是否有效
  public func validateEmail(): Bool {
    // 简单的邮箱格式验证
    email.contains("@") && email.contains(".")
  }
}
```

---

## 错误处理指导

### 检索失败处理

当在代码片段库中检索不到相关代码时:

#### 策略 1: 扩展搜索范围
- 扩大搜索关键词范围
- 搜索更通用的功能描述
- 检查目录路径是否正确

#### 策略 2: 基于文档生成
- 如果检索失败,基于 CangjieSkills 文档生成代码
- 严格遵循文档中的语法规范和最佳实践
- 添加详细注释说明代码来源

#### 策略 3: 降级处理
- 向用户说明检索失败的原因
- 告知用户将使用文档指导生成代码
- 提供代码验证建议

### 写入失败处理

当写入文件失败时:

1. **权限检查**: 确保运行时具有文件写入权限
2. **路径验证**: 检查目标路径是否存在且可写
3. **重试机制**: 尝试创建父目录后重试写入
4. **错误报告**: 向用户报告具体的写入错误信息

---

## 代码质量保证

### 质量检查清单

#### 语法规范
- [ ] 使用正确的关键字和标识符
- [ ] 包声明和导入语句正确
- [ ] 函数和变量声明格式正确
- [ ] 控制语句结构正确

#### 最佳实践
- [ ] 使用有意义的命名
- [ ] 添加必要的注释和文档
- [ ] 遵循仓颉命名规范
- [ ] 保持代码格式一致

#### 错误处理
- [ ] 使用 Option 类型处理可能为空的值
- [ ] 使用 try-catch 处理异常
- [ ] 提供有意义的错误信息
- [ ] 验证输入参数

#### 性能优化
- [ ] 避免不必要的对象创建
- [ ] 使用合适的数据结构
- [ ] 合理使用不可变变量
- [ ] 注意内存管理

### 推荐验证工具

- **仓颉编译器**: 使用 `cjpm build` 命令编译代码
- **代码格式化**: 使用 `cjfmt` 格式化代码
- **静态分析**: 使用 `cjlint` 检查代码质量
- **单元测试**: 使用 `cjpm test` 运行测试

---

## 工具使用指南

### 推荐工具

1. **bash**: 运行 `search_docs.py` / `setup_stdx.py` 查询 CangjieSkills 知识库
2. **file_read**: 读取代码片段与查询结果
3. **file_search**: 在代码片段库中搜索相关代码
4. **file_write**: 将修改后的代码写入目标文件
5. **directory_create**: 创建必要的目录结构

### 工具调用顺序

```
1. bash (运行 search_docs.py 查阅 CangjieSkills 知识库)
   ↓
2. file_search (检索代码片段)
   ↓
3. file_read (读取选中的代码片段)
   ↓
4. file_write (写入修改后的代码)
```

---

## 版本兼容性说明

- **仓颉语言版本**: 支持 0.53.18 及以上版本
- **CangjieSkills 版本**: v1.1.0 及以上
- **运行时依赖**: 需要 agentskills-runtime 1.0.0 及以上版本
- **工具依赖**: 需要 file_read、file_search、file_write、directory_create 工具

---

## 注意事项

1. **必须先查阅文档**: 在生成代码前,必须先查阅 CangjieSkills 技能获取规范
2. **路径格式**: 在 Windows 系统上,文件路径需要使用双反斜杠 `\\`
3. **编码规范**: 确保所有生成的代码符合仓颉编程语言的词法和语法规范
4. **文件扩展名**: 仓颉代码文件必须使用 `.cj` 扩展名
5. **目录配置**: 用户可以配置 CangjieSkills 路径和代码片段库路径
6. **错误处理**: 当检索失败时,使用文档指导生成代码
7. **代码验证**: 使用仓颉编译器验证生成的代码
8. **最佳实践**: 始终遵循 CangjieSkills 文档中的最佳实践

---

## 适用场景详解

### 场景 1: 新建仓颉代码文件

**触发条件**: 用户请求创建新的 .cj 文件

**示例**:
- "创建一个 HTTP 服务器代码"
- "新建一个 User 数据模型类"
- "生成一个工具函数文件"

**工作流程**:
1. 查阅 CangjieSkills 文档了解相关 API
2. 检索代码片段库找到参考代码
3. 编辑适配为新代码
4. 写入新文件

### 场景 2: 修改现有仓颉代码

**触发条件**: 用户请求修改现有的 .cj 文件

**示例**:
- "修改 http_server.cj,添加日志功能"
- "更新 User 类,增加 age 字段"
- "修改函数签名,增加新参数"

**工作流程**:
1. 查阅 CangjieSkills 文档了解修改涉及的 API
2. 读取现有代码文件
3. 检索相关代码片段作为参考
4. 编辑修改代码,确保符合规范
5. 写入修改后的文件

### 场景 3: 重构仓颉代码结构

**触发条件**: 用户请求重构现有代码

**示例**:
- "重构 User 类,拆分为多个小类"
- "优化代码结构,提取公共方法"
- "重命名变量和函数,改进命名规范"

**工作流程**:
1. 查阅 CangjieSkills 文档了解最佳实践
2. 读取现有代码文件
3. 分析代码结构和依赖关系
4. 按照最佳实践重构代码
5. 验证重构后的代码符合规范
6. 写入重构后的文件

### 场景 4: 优化仓颉代码性能

**触发条件**: 用户请求优化代码性能

**示例**:
- "优化这个排序算法的性能"
- "减少内存分配,提高效率"
- "使用更高效的数据结构"

**工作流程**:
1. 查阅 CangjieSkills 文档了解性能优化建议
2. 读取现有代码文件
3. 分析性能瓶颈
4. 应用性能优化技术
5. 验证优化后的代码正确性
6. 写入优化后的文件

### 场景 5: 修复仓颉代码错误

**触发条件**: 用户请求修复代码错误或 bug

**示例**:
- "修复这个空指针异常"
- "修正类型不匹配错误"
- "解决编译错误"

**工作流程**:
1. 查阅 CangjieSkills 文档了解错误处理机制
2. 读取现有代码文件
3. 分析错误原因
4. 应用正确的修复方案
5. 验证修复后的代码
6. 写入修复后的文件

**若第 2~6 步处理的是「编译报错」，必须额外执行下面两步**，否则会让人工反复执行 `cjpm build`：

7. **一轮排净**：按《编译报错「一轮排净」规程》跑 `scripts/cangjie_precompile_scan.{ts,py}`，
   并做同族全域 grep——把日志里那几类错误在**整个工程**里一次性改干净
   （详见上文该章节，含 E1/E2/E4/W1 四类实测错误的原文报错与修法）
8. **跨文件连锁检查**：本次改动引入的新符号/新类型，要回头检查涉及文件的 `import`
   是否齐备、形参类型是否同步更新（典型：`joinCommand(tokens: ArrayList<String>)`
   改了形参却忘了 `import std.collection.ArrayList` 之类）

> 交还人工编译前，自查口径是「扫描 ERROR = 0」，而不是「日志里那几行改完了」。

### 场景 6: 添加新功能

**触发条件**: 用户请求在现有代码中添加新功能

**示例**:
- "在 User 类中添加验证方法"
- "为 HTTP 服务器添加中间件支持"
- "增加新的 API 端点"

**工作流程**:
1. 查阅 CangjieSkills 文档了解新功能的实现方式
2. 读取现有代码文件
3. 检索相关代码片段
4. 编辑添加新功能代码
5. 确保新代码与现有代码兼容
6. 写入更新后的文件

### 场景 7: 改进代码质量

**触发条件**: 用户请求改进代码质量

**示例**:
- "添加详细的文档注释"
- "改进错误处理机制"
- "增强代码可读性"

**工作流程**:
1. 查阅 CangjieSkills 文档了解最佳实践
2. 读取现有代码文件
3. 应用代码质量改进
4. 验证改进后的代码
5. 写入改进后的文件

---

## 参考文档

### CangjieSkills 文档（新版渐进披露知识库）

- **技能根目录**: `../CangjieSkills`（`CANGJIE_SKILLS_PATH`，记为 `<skill-root>`）
- **查询入口**: `<skill-root>/scripts/search_docs.py`（批量摘要查询 / 索引浏览 / 叶子读取）
- **stdx 配置**: `<skill-root>/scripts/setup_stdx.py`
- **知识库索引**: `<skill-root>/references/index.md`（language/、std/、stdx/、tools/、examples/ 多域）
- **架构/测试/维护手册**: `<skill-root>/docs/`（architecture.md、testing.md、maintenance.md）

### 官方文档

- [仓颉词法结构文档](https://cangjie-lang.cn/docs?url=%2FSpec%2Fsource_zh_cn%2FChapter_01_Lexical_Structure%28zh%29.html)
- [仓颉语法文档](https://cangjie-lang.cn/docs?url=%2FSpec%2Fsource_zh_cn%2FChapter_Appendix_A%28zh%29.html)
- [仓颉标准库文档](https://cangjie-lang.cn/docs/standard_library)

---

## 更新日志

### v2.5.0 (2026-10-08)

installer **Phase 1 平台层（T006~T009）** 落地时的 API 核对沉淀。**本轮没有编译错误，
全部结论来自「写之前先查文档/查实证」**，四条 before-the-fact 的发现值得单列：

- ✨ 新增专节 **《子进程 / 网络 / 环境变量：std API 实测契约》**，含
  - **同 package 跨文件不需要 import**（仓颉 package 是编译单元不是文件单元）。
    实证：全 `src/` 扫描出 **328 个**同包跨文件引用且不 import 本包的文件。
    反向提醒：跨包仍需 import
  - **`SubProcess.wait(timeout!:)` 超时是抛 `TimeoutException`（`std.core`，默认可见）**，
    不是返回哨兵值；附契约原文。**这条直接推翻了 installer design.md §4.3.2 的示意写法**
    （已在该文档内就地订正，避免后续实现者照抄）
  - **Pipe 模式必须在 `wait` 之前用 `spawn` 排空管道**，否则子进程写满缓冲区后阻塞、
    永远不退出，`wait` 的 timeout 救不回来；附完整代码骨架与「`InputStream` 没有 readToEnd」
  - **`Future.get(timeout:)` 是位置参数（无 `!`）**，三种调用的性质对照表，
    强调「**有没有感叹号是唯一判据**」
  - 另附 10 项逐条核对表（`fromUtf8Unchecked` 需 `unsafe {}`、`HashMap(getVariables())`
    不带泛型、`Path` ∈ `std.fs`、`UInt16(port)`、`SocketTimeoutException` ∈ `std.net`、
    `TimeoutException` ∈ `std.core` 等）
- ✨ 记一条 Windows 专属坑：**`setx` 与 `setVariable` 必须成对使用** ——
  `setx` 只改注册表、不改当前进程环境块，常驻进程 spawn 的子进程看不到新变量；
  配套地子进程环境要每次重取 `getVariables()` 而非启动时缓存

### v2.4.0 (2026-10-08)

installer 第四轮编译（1 error）。**新一族：函数的返回类型被 bottom type 污染。**

- ✨ 「N 类实测编译错误」表扩充为**六类**，新增 **E6** 行：
  `return type of 'main' is not 'Integer' or 'Unit'`。
  根因是**省略返回类型时按函数体最后一个表达式推断**，而 `std.env.exit(code: Int64): Nothing`
  返回 bottom type ⇒ 推断出 `Nothing`。
- ✨ 新增专节 **「E6 的规范依据与「bottom type 污染返回类型推断」」**：给 main 允许的
  返回类型（Unit / 整数）文档依据、两种修法对照、`std.env.exit` 的 Nothing 签名，
  并点明**最容易误判之处**——本仓 `crudgen.cj:30` 等四处 `main(args: Array<String>)` 无标注
  却都能编译通过，所以「没写返回类型」不是错，**真正的触发条件是「末句返回 bottom type」**，
  E6 规则因此只对组合条件报 ERROR
- ✨ `cangjie_precompile_scan.{py,ts}` 同步加入 E6（含 `findBodyLastStmt` 辅助：
  花括号配平 + 剔除字符串字面量/多行字符串/注释）。配套的记录两条实现坑：
  ① body 边界判定不剔字符串会被 `sb.append("{")` 带偏；② 只对 main 报，
  普通函数推断出 Nothing 未必错
- 📌 上线前双检全过：变异正例命中（body 内嵌字符串花括号仍正确识别末句）、
  天然负例 `installer/src/main.cj` 零命中、全库零误报、Py/TS 结果一致

### v2.3.0 (2026-10-08)

**新增**:
- ✨ 预编译扫描脚本新增 **E5 规则：`if` / `while` / `for` 的分支体必须写花括号**。
  报错形态 `expected '{', found 'XXX'`；规范依据 `language.basic_concepts.3-表达式.3-2-if-条件判断`
  的 `if (cond) { exprs1 } else { exprs2 }` —— **花括号是语法的一部分，不可省**，
  分支体也不能只写单个表达式（含「用作值」的单行 `if-else` 也要加）。
  Py / TS 双版本同步实现
- 📚 新增《E5 的规范依据与「正则 vs 配平」教训》小节，固化两个必须内置的例外：
  ① `do { } while (cond)` 的尾 while 合法无块（判据：该行去空白以 `}` 开头，
  本仓仅 `src/dsl/parser.cj:34/46` 两处）；② **扫这类问题必须用括号配平而非
  `\)\s*[^ {]` 正则**——后者会把 `if (hasValue(args, idx)) {` 里内层调用的**第一个** `)`
  当成条件结束，在 installer/src 上炸出 **20 条假阳性**
- 📌 顺记两个连带知识点：仓颉**不允许独立 `{exprs}` 块作为表达式**（只能依附
  if/while/for-in/match/函数）；`if` 用作值时**无 `else` 则类型恒为 `Unit`**

**验证记录**（E5 上线前双检，符合 v2.2.0 定下的「先验误报率」红线）:
- 🐛 首版 do-while 例外只加在「条件后同行走»分支，漏了「条件在行尾」分支，
  导致 `} while (true)` 误报；「分支体同行」与「条件在行尾」两个分支都要排除，已修
- ✅ 含缺陷样本命中 3 处真缺陷；1140 个已编译宿主文件上 **E5 零误报**；
  Py / TS 结果逐条一致

**来源**: installer Phase 0 第四轮编译，`cli/report.cj:137`
`it.status = if (code == EXIT_MANUAL) STATUS_MANUAL else STATUS_FAIL`

### v2.2.0 (2026-10-08)

**重大更新**:
- ✨ 新增《编译报错「一轮排净」规程》章节:明确 cjpm 按包编译导致
  "一轮日志只暴露首个出错包"的机制,固化「同一类错误必须一轮排净」的强制要求
- ✨ 新增 `scripts/cangjie_precompile_scan.{py,ts}` 静态扫描脚本:
  覆盖 E1 后置 `?` 类型 / E2 match 臂多语句块 / E4 `Array<T>` 调增删方法 /
  W1 `let` 重赋值(WARN),支持 `--json` / `--quiet`,ERROR 是否为 0 决定退出码
- ✨ 关键约束新增两条:编译报错必须一轮排净、检查规则须先验误报率
- ✨ 「场景 5 修复仓颉代码错误」补充第 7/8 步:一轮排净 + 跨文件连锁检查

**改进**:
- 📚 记录四类实测编译错误的**原文报错 → 根因 → 修法**对照表(E1/E2/E4/W1)
- 📚 澄清 E2 裁定依据:`JWTAuthMiddleware.cj` 的零参 lambda 形态合法,
  而 `src/test/**` 不在主构建图内、其写法不可作先例
- 🐛 修正反例教训:经大库实证 `ArrayList`/`HashMap` 属 prelude(512 个文件用
  ArrayList 其中 248 个未 import 仍能编译),据此废止误报的 E3「缺 import」规则
- 🐛 W1 规则由「全文件 let 名字集合」改为「按函数签名划作用域、取最后一次声明 kind」,
  误报由 564 条降为 0 条,同时保留对真实重赋值的准确命中

### v2.1.0 (2026-03-13)

**重大更新**:
- ✨ 扩展适用场景:从代码生成扩展到所有仓颉代码编写场景
- ✨ 新增 7 种适用场景详解
- ✨ 更新描述字段,覆盖新建、修改、重构、优化、修复等所有操作

**改进**:
- 📚 更全面的触发条件
- 📚 更详细的工作流程说明
- 📚 更清晰的场景分类

### v2.0.0 (2026-03-13)

**重大更新**:
- ✨ 新增四步工作流程: 查阅 → 检索 → 编辑 → 写入
- ✨ 整合 CangjieSkills 官方文档资源
- ✨ 添加最佳实践指导
- ✨ 增强错误处理和验证
- ✨ 提供完整的代码示例

**改进**:
- 📚 从三步工作流程升级为四步工作流程
- 📚 新增 CangjieSkills 文档查阅步骤
- 📚 增强代码质量保证机制
- 📚 提供更详细的错误处理指导

### v1.1.0

- 初始版本,实现三步工作流程
- 基础的代码检索和生成功能
