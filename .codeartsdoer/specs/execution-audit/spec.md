# 执行证据链与审计系统需求规格

## 项目背景

GOAI 2026「新智基座」赛道要求参赛作品具备"可审计"能力，能够完整追踪Agent执行的每一步决策、工具调用和结果。当前 agentskills-runtime 的 operate_log 仅记录工具调用，缺少Agent决策、任务流转的完整审计链。本工程实现执行证据链与审计系统（GOAI-003）和验证证据账本（GOAI-017），确保Agent执行过程可追溯、可审计、可回放。

## 核心问题

1. **缺少执行轨迹记录**: Agent执行的每个步骤（决策、工具调用、结果）无完整记录
2. **缺少证据链完整性**: 执行记录缺乏时间戳、Agent ID、输入输出、耗时等关键信息
3. **缺少副作用追踪**: 每个步骤的副作用（文件修改、数据库变更）无追踪
4. **缺少不可篡改审计日志**: 审计日志可被修改，无法保证完整性
5. **缺少验证证据账本**: Agent对代码工作空间的验证结果无结构化记录
6. **缺少执行回放**: 无法根据审计日志回放Agent执行过程

## 功能需求

### REQ-EA-001: 执行轨迹记录

- 记录Agent执行的每个步骤：决策、工具调用、结果
- 每条记录包含：步骤ID、Agent ID、步骤类型、输入、输出、时间戳、耗时
- 支持步骤间的因果关系链接（parent_step_id）
- 支持嵌套步骤记录（子步骤）

### REQ-EA-002: 证据链完整性

- 每步执行结果包含：时间戳、Agent ID、输入输出、耗时
- 证据链按执行顺序链接，不可断裂
- 支持证据链的完整性校验
- 证据记录写入execution_evidences表

### REQ-EA-003: 副作用追踪

- 记录每个步骤的副作用类型：file_write、db_insert、db_update、db_delete、api_call
- 副作用记录包含：目标、操作类型、变更前值、变更后值
- 副作用记录与步骤关联
- 支持副作用回滚（与GOAI-009审批回滚工程协作）

### REQ-EA-004: 不可篡改审计日志

- 审计日志写入operate_log表，增加Agent决策和任务流转记录
- 审计日志包含哈希校验，防止篡改
- 支持审计日志查询和导出
- 支持按Agent、时间范围、操作类型筛选

### REQ-EA-005: 验证证据账本

- 记录Agent对代码工作空间的验证结果
- 验证类型：compile（编译验证）、lint（代码检查）、test（测试运行）、business_rule（业务规则验证）、completeness（完整性验证）
- 验证结果：status（pass/fail/error）、output_summary、exit_code
- 被动设计：记录验证结果但不阻止Agent继续执行
- 验证证据持久化到verification_evidences表
- 支持会话级和仓库级聚合

### REQ-EA-006: 执行回放

- 可根据审计日志回放Agent执行过程
- 支持按时间线回放
- 支持按Agent回放
- 支持按步骤类型回放
- 回放结果可视化展示

## 非功能需求

- 证据记录写入延迟 ≤ 10ms
- 审计日志查询延迟 ≤ 100ms（10000条内）
- 验证证据保留期 ≥ 30天
- 证据链完整性校验 ≤ 50ms

## 验收标准

- [ ] Agent执行的每个步骤都有完整的证据记录
- [ ] 证据链包含时间戳、Agent ID、输入输出、耗时
- [ ] 副作用（文件修改、数据库变更）被正确追踪
- [ ] 审计日志不可篡改且可查询
- [ ] 验证证据账本正确记录编译/测试/业务规则验证结果
- [ ] 可根据审计日志回放Agent执行过程

## 数据模型

### execution_evidences 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | bigint | 主键 |
| agent_id | bigint | 执行Agent |
| session_id | varchar(100) | 会话ID |
| step_id | varchar(100) | 步骤ID |
| parent_step_id | varchar(100) | 父步骤ID |
| step_type | varchar(20) | 步骤类型：decision/tool_call/result/error |
| input | jsonb | 输入数据 |
| output | jsonb | 输出数据 |
| duration_ms | bigint | 耗时（毫秒） |
| side_effects | jsonb | 副作用记录 |
| hash | varchar(64) | 哈希校验 |
| created_at | timestamp | 创建时间 |

### verification_evidences 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | bigint | 主键 |
| agent_id | bigint | 验证Agent |
| session_id | varchar(100) | 会话ID |
| verification_type | varchar(20) | 验证类型：compile/lint/test/business_rule/completeness |
| scope | varchar(20) | 范围：session/repository |
| command | varchar(500) | 验证命令 |
| status | varchar(20) | 状态：pass/fail/error |
| exit_code | integer | 退出码 |
| output_summary | text | 输出摘要 |
| created_at | timestamp | 创建时间 |

## 依赖

- 扩展现有operate_log审计日志
- 复用EventHandlerManager事件系统
- 复用WebSocket推送机制
- 与agent-teams工程的TeamMessenger集成