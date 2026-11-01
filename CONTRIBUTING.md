# 贡献指南

感谢你对 AgentSkills Runtime 项目的关注！本文档将指导你如何参与贡献。

## 开发环境搭建

### 前置条件

1. **仓颉(Cangjie) SDK** — 从[仓颉官方渠道](https://cangjie-lang.cn/)获取并安装
2. **cjpm** — 仓颉包管理器，随SDK一起安装
3. **PostgreSQL** — 14+版本，用于数据库存储
4. **Git** — 版本控制
5. **Windows 系统特别要求** — 需要安装 OpenSSL 库以支持 WebSocket 通信
   - 下载地址: https://slproweb.com/products/Win32OpenSSL.html
   - 安装时选择 "Copy OpenSSL DLLs to: The OpenSSL binaries (/bin) directory"
   - 确保 OpenSSL 的 bin 目录已添加到系统 PATH 环境变量

### 搭建步骤

```bash
# 1. 确认仓颉环境已安装
cjpm --version

# 2. 克隆仓库
git clone https://atomgit.com/uctoo/agentskills-runtime.git
cd agentskills-runtime

# 3. 安装依赖
cjpm install

# 4. 配置环境变量
cp .env.example .env
# 编辑 .env 文件，配置数据库连接、API Key等参数
# Windows 需要配置 CANGJIE_HOME、CANGJIE_STDX_PATH 环境变量

# 5. 初始化数据库
# 执行 sql/ 目录下的DDL脚本

# 6. 编译项目
cjpm build

# 7. 运行 API 服务
cjpm run --skip-build --name magic.app
# 或在指定端口上运行
cjpm run --skip-build --name magic.app 8081
```

> **注意**: 运行项目必须使用 `cjpm run --skip-build --name magic.app`，不能仅用 `cjpm run`。详见 [API 服务运行指南](docs/api-service-run.md)。

## 项目结构

```
agentskills-runtime/
├── cjpm.toml                # 仓颉包配置
├── build.cj                 # 构建脚本
├── src/                     # 仓颉源代码
│   ├── app/                 # 应用服务器模块
│   │   ├── main.cj          # 应用主入口
│   │   ├── core/            # 核心组件（server/router/middleware/http/database）
│   │   ├── routes/          # 路由处理
│   │   ├── controllers/     # 控制器
│   │   ├── services/        # 业务服务
│   │   ├── middlewares/     # 中间件实现
│   │   └── registry/        # 自动路由注册
│   ├── core/                # 核心定义（Agent/Team/Skill）
│   ├── agent_group/         # Agent分组与协作
│   ├── agent_executor/      # Agent执行器与DAG编排
│   ├── interaction/         # 交互层（审批/回滚/记忆/优化）
│   ├── skill/               # 技能实现
│   ├── tool/                # 工具定义
│   ├── security/            # 安全模块（WASM沙箱/访问控制）
│   └── runtime/             # 运行时核心
├── skills/                  # 技能定义目录（SKILL.md + agents/）
├── config/                  # 配置文件（YAML）
├── sql/                     # 数据库DDL
├── sdk/                     # 多语言SDK（JavaScript/Python/Java/Go/Rust/C#）
├── tests/                   # 测试
├── docs/                    # 文档
└── scripts/                 # 辅助脚本
```

## 贡献流程

### 1. Fork与分支

```bash
# Fork仓库后
git checkout -b feature/your-feature-name
```

分支命名规范：
- `feature/` — 新功能
- `fix/` — Bug修复
- `refactor/` — 重构
- `docs/` — 文档更新

### 2. 编码规范

- **仓颉代码必须使用 cangjie-coder 技能编写**，遵循四步工作流程：
  1. 查阅文档 → 检索CangjieSkills技能获取语言规范
  2. 检索代码 → 从代码片段库搜索可复用代码
  3. 编辑适配 → 根据规范编辑适配代码
  4. 写入文件 → 写入并验证代码

- **数据库变更遵循 uctoo-v4 通用模块开发流程**：
  1. 执行SQL变更 — 在数据库中执行建表或表结构变更SQL
  2. 刷新数据库信息 — 通过Web管理后台的"数据库信息"页面点击"加载数据库信息"，或调用API
  3. 生成后端模块 — 使用crudgen生成后端标准CRUD模块
  4. 生成前端页面 — 使用crudweb生成前端Web页面
  5. 业务逻辑开发 — 在AutoCreateCode区域之外编写自定义业务逻辑
  6. 编译验证 — 执行`cjpm build`验证编译通过

- **代码生成工具使用**：
  ```bash
  # crudgen - 后端CRUD模块生成器
  cjpm run --skip-build --name magic.app.tools.crudgen --run-args="--db <数据库名> --table <表名>"

  # crudweb - 前端Web页面生成器
  cjpm run --skip-build --name magic.app.tools.crudweb --run-args="--db <数据库名> --table <表名>"
  ```

- **代码风格**：
  - 使用4空格缩进
  - public成员显式标注`public`修饰符
  - 枚举比较使用match模式匹配或辅助函数
  - 避免循环依赖，使用回调函数解耦
  - interface中不能使用可选参数（默认参数值）

### 3. 提交规范

提交信息格式：`<type>(<scope>): <description>`

- `feat`: 新功能
- `fix`: Bug修复
- `refactor`: 重构
- `docs`: 文档
- `test`: 测试
- `chore`: 构建/工具

示例：`feat(skill): add SkillCurator auto-evolution support`

### 4. 测试

```bash
# 运行测试
cjpm test

# 代码检查
cjpm check
```

确保所有测试通过后再提交。

### 5. Pull Request

1. 推送分支到你的Fork
2. 创建Pull Request，描述变更内容和目的
3. 等待代码审查
4. 根据审查意见修改
5. 合并后删除分支

## 贡献方式

1. **代码贡献** — 提交Pull Request改进代码
2. **文档完善** — 帮助完善技术文档和使用指南
3. **问题反馈** — 报告Bug或提出功能建议
4. **技能开发** — 开发新的技能示例
5. **SDK开发** — 为新的编程语言开发SDK
6. **语言适配器** — 开发新的语言适配器和绑定
7. **生态系统集成** — 集成主流开发工具和平台

## 技能贡献

技能是AgentSkills Runtime的一等公民，贡献新技能是最高价值的贡献方式。

### 技能目录结构

```
skills/your-skill/
├── SKILL.md              # 技能定义（必需）
├── COMPOSITION.yaml      # 技能组合配置（可选）
├── agents/               # 子Agent定义（可选）
│   ├── agent-1.md
│   └── agent-2.md
└── references/           # 参考文档（可选）
```

### SKILL.md 模板

```markdown
---
name: your-skill-name
version: 1.0.0
description: 技能描述
author: Your Name
trigger:
  - 关键词1
  - 关键词2
dependencies:
  - skill-name
---

# 技能名称

## 功能描述
...

## 使用方法
...

## 输入参数
...

## 输出格式
...
```

## 问题反馈

- **Bug报告** — 在 [AtomGit Issues](https://atomgit.com/uctoo/agentskills-runtime/issues) 标注`bug`标签
- **功能建议** — 在 Issues 中标注`enhancement`标签
- **邮件联系** — contact@uctoo.com

## 许可证

本项目采用 MIT 许可证。贡献的代码将采用相同许可证。详见 [LICENSE](LICENSE) 文件。
