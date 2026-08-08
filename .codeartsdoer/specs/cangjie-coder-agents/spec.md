# cangjie-coder agents子目录完善需求规格

## 项目背景

cangjie-coder技能是agentskills-runtime作为coding agent的核心差异化能力。当前cangjie-coder仅有SKILL.md文件，缺少agents子目录（subagent定义）、scripts子目录（确定性脚本）和references子目录（参考文档索引）。参考skill-creator技能已成功实现的agents子目录模式，为cangjie-coder完善agents子目录，实现专用语言多skills编排协作的核心能力。

## 核心问题

1. **缺少agents子目录**: skill-creator已有agents子目录（analyzer.md、comparator.md、grader.md），但cangjie-coder没有
2. **缺少scripts子目录**: skill-creator已有scripts子目录（9个Python脚本），但cangjie-coder没有
3. **缺少references子目录**: CangjieSkills有references/子目录，但cangjie-coder未整合
4. **缺少编译验证能力**: 无法调用cjpm build验证生成的代码
5. **缺少错误修复闭环**: 编译错误无法自动修复
6. **SOP工作流是静态描述**: 四步工作流写在SKILL.md中，执行一致性依赖模型能力

## 功能需求

### REQ-CCA-001: doc-consultant subagent

- 文档查阅Agent，从CangjieSkills技能中检索和提取语言规范、API文档和最佳实践
- 支持按关键词和语义检索
- 输出：相关文档片段和规范引用

### REQ-CCA-002: code-searcher subagent

- 代码检索Agent，从代码片段库中搜索可复用的代码基础
- 支持按功能、模式、类名检索
- 输出：匹配的代码片段和文件路径

### REQ-CCA-003: code-editor subagent

- 代码编辑Agent，根据文档规范和代码片段编辑适配代码
- 支持文件读写和编辑
- 应用最佳实践
- 输出：编辑后的代码文件

### REQ-CCA-004: code-verifier subagent

- 代码验证Agent，编译验证、语法检查、测试运行和错误修复建议
- 支持cjpm build编译验证
- 支持语法检查
- 输出：验证结果和修复建议

### REQ-CCA-005: 编排器与自动修复闭环

- cangjie-coder SKILL.md作为编排器，协调四个subagent
- 串行+反馈闭环的协作：doc-consultant→code-searcher→code-editor→code-verifier
- 验证失败时自动修复（最多3次重试）
- 每个subagent的输出通过标准化文件路径传递

### REQ-CCA-006: scripts子目录

- cangjie_syntax_check.py: 仓颉语法检查脚本
- cangjie_compile.py: 编译验证脚本
- cangjie_test_runner.py: 测试运行脚本
- cangjie_fix_suggest.py: 修复建议脚本

### REQ-CCA-007: references子目录

- language_guide_index.md: 语言指南索引
- code_patterns.md: 代码模式库

## 验收标准

- [ ] cangjie-coder/agents/目录包含4个subagent定义文件
- [ ] 每个subagent有完整的YAML frontmatter和职责描述
- [ ] 编排器正确协调四个subagent的执行顺序
- [ ] 验证失败时自动修复闭环正常工作
- [ ] 生成的仓颉代码通过cjpm build编译验证
- [ ] scripts子目录包含4个Python脚本
- [ ] references子目录包含文档索引

## 依赖

- 复用skill-creator的agents子目录声明模式
- 复用CangjieSkills的cangjie-language-guide和cangjie-full-docs技能
- 复用CangjieMagic/resource代码片段库
- 复用现有file_read/file_write/file_search工具