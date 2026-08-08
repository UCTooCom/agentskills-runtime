# AI驱动开发全流程Demo场景 - 任务清单

## 开发规范

### 仓颉代码开发
- 所有仓颉代码(.cj文件)的编写必须使用 **cangjie-coder 技能**，遵循查阅文档→检索代码→编辑适配→写入文件的四步工作流程
- 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
- 仓颉代码必须符合 CangjieMagic 框架和 V4 模块的约定和模式

---

| 任务ID | 任务名称 | 优先级 | 预估工时 | 依赖 |
|--------|---------|--------|---------|------|
| DEM-T001 | 创建demo-team.yaml团队配置 | P0 | 0.5天 | agent-teams |
| DEM-T002 | 创建Demo入口API | P0 | 1天 | DEM-T001 |
| DEM-T003 | Demo执行流程编排 | P0 | 1天 | DEM-T001, agent-orchestration |
| DEM-T004 | Demo前端展示页面 | P0 | 1.5天 | DEM-T002 |
| DEM-T005 | Demo稳定性测试 | P0 | 1天 | DEM-T001~T004 |

---

## DEM-T001: 创建demo-team.yaml团队配置

**描述**: 创建AI驱动开发Demo的团队配置文件。

**子任务**:
1. 创建demo-team.yaml
2. 定义ProductManager(Manager)角色和技能
3. 定义Developer(TeamLeader)角色和技能
4. 定义CoderWorker(Worker)角色和技能
5. 定义QA Worker(Worker)角色和技能

**验收标准**:
- [ ] demo-team.yaml格式正确
- [ ] 4个Agent角色和技能定义完整

---

## DEM-T002: 创建Demo入口API

**描述**: 创建一键启动Demo的RESTful API。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 创建DemoController
2. 实现start API（创建团队、提交任务）
3. 实现status API（查询执行状态）
4. 实现evidences API（查询执行证据）
5. 遵循uctoo-v4 API规范

**验收标准**:
- [ ] start API正确创建团队并提交任务
- [ ] status API正确返回执行状态
- [ ] evidences API正确返回执行证据

---

## DEM-T003: Demo执行流程编排

**描述**: 编排Demo的完整执行流程。

**子任务**:
1. 创建demo-orchestration.yaml（DAG执行计划）
2. 定义步骤：需求分析→数据库设计→后端生成→前端生成→代码验证
3. 与AgentTeams集成
4. 与DagScheduler集成

**验收标准**:
- [ ] DAG执行计划可正确调度
- [ ] 步骤按正确顺序执行

---

## DEM-T004: Demo前端展示页面

**描述**: 创建Demo的前端展示页面。

**子任务**:
1. 创建Demo启动页面（输入需求、选择表）
2. 创建执行状态展示页面（实时进度、Agent协作拓扑）
3. 创建执行证据展示页面（证据链、验证结果）
4. 使用Vue 3 + OpenTiny Vue组件库

**验收标准**:
- [ ] Demo启动页面可正常使用
- [ ] 执行状态实时展示
- [ ] 证据链可视化展示

---

## DEM-T005: Demo稳定性测试

**描述**: 测试Demo的稳定性和可重复性。

**子任务**:
1. 多次运行Demo，验证结果一致性
2. 测试不同业务场景（员工管理、部门管理等）
3. 测试异常场景（验证失败、Agent错误等）
4. 录制Demo视频作为备份

**验收标准**:
- [ ] Demo可重复运行，结果一致
- [ ] 不同业务场景可正确执行
- [ ] 异常场景可正确处理