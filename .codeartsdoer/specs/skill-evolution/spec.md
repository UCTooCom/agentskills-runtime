# 技能自进化闭环需求规格

## 项目背景

借鉴Hermes项目的Curator机制，实现技能自进化闭环：从经验中创建技能，在使用中改进技能。这是agentskills-runtime区别于其他参赛作品的独特Skill工程能力。

## 核心问题

1. **缺少技能使用追踪**: 技能使用次数、查看次数、修改次数无统计
2. **缺少自动状态流转**: 技能无active→stale→archived自动流转
3. **缺少Curator审查机制**: 无后台技能维护编排器
4. **缺少技能脚本动态生成**: 技能在首次使用时无法自动生成需要的程序工具脚本

## 功能需求

### REQ-SE-001: 技能使用追踪
- 扩展operate_log，增加技能使用统计
- 记录每个技能的使用次数、查看次数、修改次数、最后活动时间
- 统计数据持久化到skill_usage_stats表

### REQ-SE-002: 自动状态流转
- 在SKILL.md中增加state和last_activity_at字段
- 基于使用频率自动转换：active→stale→archived
- 流转规则可配置（如30天未使用→stale，90天未使用→archived）
- Pinned技能豁免自动流转

### REQ-SE-003: Curator审查机制
- 实现skill-curator技能，定期审查Agent创建的技能
- 审查规则通过YAML配置定义
- 参照crontab配置loop的模式，Curator通过crontab定期触发
- 严格不变量：只触碰Agent创建的技能，永不自动删除（只归档）

### REQ-SE-004: 技能脚本动态生成
- SKILL.md中声明scripts需求（名称、描述、语言、生成策略）
- 首次使用时自动生成声明的脚本
- 脚本在WASM沙箱或受限环境中执行
- 脚本与技能版本绑定

## 验收标准

- [ ] 技能使用统计正确记录
- [ ] 自动状态流转按规则正确执行
- [ ] Curator定期审查技能
- [ ] 技能脚本首次使用时自动生成

## 依赖

- 依赖skill-composition-engine工程