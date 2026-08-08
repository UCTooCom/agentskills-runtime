# SDD规范驱动开发技能集 - 任务清单

## 开发规范

### 仓颉代码开发
- 所有仓颉代码(.cj文件)的编写必须使用 **cangjie-coder 技能**，遵循查阅文档→检索代码→编辑适配→写入文件的四步工作流程
- 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
- 仓颉代码必须符合 CangjieMagic 框架和 V4 模块的约定和模式

---

| 任务ID | 任务名称 | 优先级 | 预估工时 | 依赖 | 状态 |
|--------|---------|--------|---------|------|------|
| SDD-T001 | 创建sdd-spec技能 | P0 | 0.5天 | 无 | ✅已完成 |
| SDD-T002 | 创建sdd-design技能 | P0 | 0.5天 | 无 | ✅已完成 |
| SDD-T003 | 创建sdd-task技能 | P0 | 0.5天 | 无 | ✅已完成 |
| SDD-T004 | 创建sdd-test技能 | P0 | 0.5天 | 无 | ✅已完成 |
| SDD-T005 | 创建sdd-flow组合模板 | P0 | 0.5天 | SDD-T001~T004 | ✅已完成 |
| SDD-T006 | 与AgentTeams集成测试 | P0 | 0.5天 | SDD-T005, agent-teams | ⏳待完成 |

---

## SDD-T001: 创建sdd-spec技能

**描述**: 创建skills/sdd-spec/SKILL.md，定义SpecAgent技能。

**子任务**:
1. 创建sdd-spec技能目录
2. 编写SKILL.md，定义输入（requirement、project_path）和输出（spec_path）
3. 定义spec.md模板格式
4. 定义agent_type为spec-agent

**验收标准**:
- [ ] sdd-spec技能可加载
- [ ] 输入输出定义正确

---

## SDD-T002: 创建sdd-design技能

**描述**: 创建skills/sdd-design/SKILL.md，定义DesignAgent技能。

**子任务**:
1. 创建sdd-design技能目录
2. 编写SKILL.md，定义输入（spec_path）和输出（design_path）
3. 定义design.md模板格式
4. 定义agent_type为design-agent

**验收标准**:
- [ ] sdd-design技能可加载

---

## SDD-T003: 创建sdd-task技能

**描述**: 创建skills/sdd-task/SKILL.md，定义TaskAgent技能。

**子任务**:
1. 创建sdd-task技能目录
2. 编写SKILL.md，定义输入（design_path）和输出（tasks_path）
3. 定义tasks.md模板格式
4. 定义agent_type为task-agent

**验收标准**:
- [ ] sdd-task技能可加载

---

## SDD-T004: 创建sdd-test技能

**描述**: 创建skills/sdd-test/SKILL.md，定义TestAgent技能。

**子任务**:
1. 创建sdd-test技能目录
2. 编写SKILL.md，定义输入（code_path）和输出（report_path）
3. 定义验证报告格式
4. 定义agent_type为qa-worker

**验收标准**:
- [ ] sdd-test技能可加载

---

## SDD-T005: 创建sdd-flow组合模板

**描述**: 创建sdd-flow组合模板，编排完整SDD流程。

**子任务**:
1. 创建skills/sdd-flow/目录
2. 编写SKILL.md
3. 编写COMPOSITION.yaml
4. 定义5步组合流程
5. 测试组合模板可被解析

**验收标准**:
- [ ] sdd-flow组合模板可解析
- [ ] 5步流程定义正确

---

## SDD-T006: 与AgentTeams集成测试

**描述**: 测试SDD流程与AgentTeams分层架构的集成。

**子任务**:
1. 测试SpecAgent在Manager角色正确工作
2. 测试DesignAgent/TaskAgent在TeamLeader角色正确工作
3. 测试CodeAgent/TestAgent在Worker角色正确工作
4. 端到端测试：从需求到代码的完整SDD流程

**验收标准**:
- [ ] SDD流程在AgentTeams架构中正确执行
- [ ] 各阶段输出正确传递