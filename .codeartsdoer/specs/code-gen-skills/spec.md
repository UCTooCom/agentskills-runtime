# 代码生成工具Skills化封装需求规格

## 项目背景

agentskills-runtime已有三个代码生成内置工具（crudgen、crudweb、loaddbinfo），但它们是硬编码的内置工具，无法通过Skills编排调用。本工程将这三个工具封装为SKILL.md格式的技能，使其可通过技能组合引擎编排调用，并实现代码生成的闭环验证。

## 核心问题

1. **代码生成工具非技能化**: crudgen/crudweb/loaddbinfo是内置工具，无法通过SKILL.md标准加载和触发
2. **缺少技能组合模板**: 代码生成工具的组合模式（loaddbinfo→crudgen→crudweb→cangjie-coder）无法保存为模板复用
3. **缺少闭环验证**: 代码生成后无法自动编译验证、API验证、业务规则验证
4. **Agent无法动态调用**: CoderWorker无法通过技能调用代码生成工具

## 功能需求

### REQ-CGS-001: crud-generator技能封装

- 将CrudGenService和WebCrudGenService封装为SKILL.md格式
- 技能定义包含：输入参数（table_name、database）、输出（生成的文件列表）
- 支持后端CRUD代码生成（Model/DAO/Service/Controller/Route）
- 支持前端CRUD页面生成（Vue 3 + OpenTiny Vue）

### REQ-CGS-002: loaddbinfo技能封装

- 将数据库信息加载封装为SKILL.md格式
- 技能定义包含：输入参数（database）、输出（表结构信息）
- 支持从information_schema加载到db_info表

### REQ-CGS-003: code-gen-optimize组合模板

- 定义code-gen-optimize组合模板
- 流程：loaddbinfo→crudgen→crudweb→cangjie-coder
- 支持从模板实例化组合（提供table_name和database参数）

### REQ-CGS-004: 代码生成闭环验证

- 编译验证：代码生成后自动调用cjpm build验证
- API验证：自动调用生成的API接口验证CRUD操作
- 业务规则验证：验证生成的代码符合业务规则
- 错误反馈闭环：验证失败时自动反馈到代码修复

## 验收标准

- [ ] crud-generator技能可通过SKILL.md格式加载和触发
- [ ] loaddbinfo技能可通过SKILL.md格式加载和触发
- [ ] code-gen-optimize组合模板可正确执行
- [ ] CoderWorker可通过技能调用代码生成工具
- [ ] 代码生成后自动编译验证
- [ ] 验证失败时自动反馈到代码修复

## 依赖

- 复用现有CrudGenService.cj和WebCrudGenService.cj
- 复用现有RESTful API接口
- 复用现有模板引擎
- 依赖skill-composition-engine工程的组合执行能力