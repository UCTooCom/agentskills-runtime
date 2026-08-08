# AI驱动开发全流程Demo场景需求规格

## 项目背景

GOAI 2026「新智基座」赛道要求参赛作品展示"3+个Agent协作完成从需求到代码的完整闭环"，体现场景价值和行业可复制性。本工程构建一个完整的AI驱动软件开发全流程Demo，展示ProductManager→Developer→CoderWorker→QA四Agent协作闭环，是所有P0工程的集成验证。

## 核心问题

1. **缺少完整Demo场景**: 当前项目偏技术框架，缺少一个完整的、有行业价值的业务场景闭环演示
2. **缺少多Agent协作Demo**: 无法展示3+个Agent协作完成从需求到代码的完整闭环
3. **缺少行业可复制性论证**: 未展示技能和协作模式如何迁移到相似行业场景

## 功能需求

### REQ-DEM-001: Demo场景设计

**场景**: 用户提交一个业务需求（如"开发一个员工管理模块"），系统自动完成从需求分析到代码生成的全流程。

**Agent角色定义**:
1. **ProductManager Agent（Manager角色）**: 接收用户需求，分析需求，分解为开发任务，分配给开发团队，验证最终结果
2. **Developer Agent（TeamLeader角色）**: 接收开发任务，规划代码生成步骤，分配给Worker执行，聚合代码结果
3. **CoderWorker Agent（Worker角色）**: 执行具体编码任务（生成数据库DDL、生成后端CRUD代码、生成前端页面代码）
4. **QA Agent（Worker角色）**: 验证生成的代码，执行测试，报告问题

### REQ-DEM-002: 完整闭环流程

```
用户: "开发一个员工管理模块"
  → ProductManager: 分析需求，分解为[数据库设计, 后端开发, 前端开发, 测试验证]
  → Developer: 规划执行顺序，分配给CoderWorker
    → CoderWorker-1: 使用crudgen生成数据库DDL和后端CRUD
    → CoderWorker-2: 使用crudweb生成前端管理页面
    → QA Agent: 验证生成代码的完整性和正确性
  → ProductManager: 汇总结果，验证闭环，交付用户
```

### REQ-DEM-003: Skill复用

- crud-generator: 数据库DDL和CRUD代码生成
- cangjie-coder: 代码优化和修复
- sdd-spec/sdd-design/sdd-task: SDD规范驱动开发流程
- file_read/file_write: 文件操作

### REQ-DEM-004: 执行证据展示

- Demo执行过程有完整的证据链
- 每个Agent的决策和执行步骤可追溯
- 支持执行回放

### REQ-DEM-005: 行业可复制性

- Demo场景可迁移到其他业务模块（如部门管理、项目管理等）
- 技能组合模板可复用
- Agent协作模式可复制

## 验收标准

- [ ] 3+个Agent协作完成从需求到代码的完整闭环
- [ ] 每个Agent有明确的职责和输出
- [ ] 执行过程有完整的证据链
- [ ] Demo可重复运行，结果一致
- [ ] 场景具有行业可复制性

## 依赖

- 依赖所有P0工程（agent-teams、agent-orchestration、execution-audit、skill-composition-engine、cangjie-coder-agents、code-gen-skills、sdd-skills、fullstack-codegen）