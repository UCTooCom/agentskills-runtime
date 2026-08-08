---
name: test-generator
version: 1.0.0
description: 测试脚本动态生成技能，支持根据代码变更自动生成单元测试、集成测试和端到端测试，形成测试反馈闭环
type: orchestrator
dependencies:
  - cangjie-coder
agents:
  - agents/test-planner.md
  - agents/test-writer.md
  - agents/test-runner.md
scripts:
  - scripts/generate_unit_test.py
  - scripts/generate_integration_test.py
  - scripts/run_cangjie_test.py
  - scripts/analyze_coverage.py
  - scripts/fix_test_failures.py
---

# test-generator 测试脚本动态生成技能

## 编排流程

### 三步工作流
1. **test-planner**: 分析代码变更，规划测试用例（输入：代码diff → 输出：测试计划）
2. **test-writer**: 根据测试计划生成测试代码（输入：测试计划 → 输出：测试代码）
3. **test-runner**: 执行测试并收集结果（输入：测试代码 → 输出：测试结果）

### 测试反馈闭环
```
test-runner → 测试失败?
  → 是: code-editor修复 → 重新test-runner（最多3次）
  → 否: 输出测试报告
```

## 输入格式
```json
{
  "source_files": ["src/interaction/evaluation_engine.cj"],
  "test_type": "unit|integration|e2e",
  "target_dir": "tests/",
  "max_retries": 3
}
```

## 输出格式
```json
{
  "test_files": ["tests/test_evaluation_engine.cj"],
  "results": {
    "total": 10,
    "passed": 8,
    "failed": 2,
    "coverage_percent": 75.0
  },
  "fixes_applied": 1
}
```