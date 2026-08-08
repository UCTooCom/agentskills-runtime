# 测试脚本动态生成技能需求规格

## 项目背景

在AI驱动开发全流程Demo中，QA Agent需要能够动态生成测试脚本来验证生成的代码。这是赛事"自主闭环能力"的关键体现。

## 核心问题

1. **缺少测试生成能力**: agentskills-runtime没有内置的测试生成能力
2. **缺少动态生成测试脚本机制**: 无法动态生成JS/Python测试脚本
3. **缺少测试结果反馈闭环**: 测试脚本执行结果无法反馈到代码修复

## 功能需求

### REQ-TG-001: test-planner subagent
- 分析待验证代码，规划测试用例
- 输出：测试用例列表（类型、目标、预期结果）

### REQ-TG-002: test-writer subagent
- 根据测试用例生成Python/JS测试脚本
- 支持pytest（Python）和Playwright（JS）框架
- 输出：可执行的测试脚本文件

### REQ-TG-003: test-runner subagent
- 执行测试脚本，收集结果
- 输出：测试报告（通过/失败/错误详情）

### REQ-TG-004: 多框架支持
- API接口测试：Python (requests/pytest)
- 数据库测试：Python (psycopg2/pytest)
- 前端UI测试：JavaScript (Playwright)
- 仓颉单元测试：仓颉 (unittest)

### REQ-TG-005: 测试结果反馈闭环
- 测试失败时反馈给code-editor修复
- 修复后重新测试
- 最多3次重试

## 验收标准

- [ ] test-planner正确分析代码并规划测试用例
- [ ] test-writer生成可执行的Python/JS测试脚本
- [ ] test-runner正确执行测试脚本并收集结果
- [ ] 测试失败时反馈到代码修复闭环

## 依赖

- 依赖cangjie-coder-agents工程的agents子目录机制