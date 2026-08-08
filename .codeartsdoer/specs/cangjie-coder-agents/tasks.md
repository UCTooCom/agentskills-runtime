# cangjie-coder agents子目录完善 - 任务清单

## 开发规范

### 仓颉代码开发
- 所有仓颉代码(.cj文件)的编写必须使用 **cangjie-coder 技能**，遵循查阅文档→检索代码→编辑适配→写入文件的四步工作流程
- 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
- 仓颉代码必须符合 CangjieMagic 框架和 V4 模块的约定和模式

---

## 任务总览

| 任务ID | 任务名称 | 优先级 | 预估工时 | 依赖 |
|--------|---------|--------|---------|------|
| CCA-T001 | 创建agents子目录和4个subagent定义 | P0 | 1天 | 无 |
| CCA-T002 | 更新SKILL.md为编排器模式 | P0 | 0.5天 | CCA-T001 |
| CCA-T003 | 创建scripts子目录和4个Python脚本 | P0 | 1天 | 无 |
| CCA-T004 | 创建references子目录和文档索引 | P0 | 0.5天 | 无 |
| CCA-T005 | 自动修复闭环实现与测试 | P0 | 1天 | CCA-T001, CCA-T002 |

---

## CCA-T001: 创建agents子目录和4个subagent定义

**描述**: 创建cangjie-coder/agents/目录，编写4个subagent定义文件。

**子任务**:
1. 创建agents/目录
2. 编写doc-consultant.md（文档查阅Agent）
3. 编写code-searcher.md（代码检索Agent）
4. 编写code-editor.md（代码编辑Agent）
5. 编写code-verifier.md（代码验证Agent）
6. 每个subagent包含完整的YAML frontmatter

**验收标准**:
- [ ] agents/目录包含4个.md文件
- [ ] 每个文件有完整的YAML frontmatter
- [ ] subagent声明了正确的tools和permissions

---

## CCA-T002: 更新SKILL.md为编排器模式

**描述**: 更新cangjie-coder/SKILL.md，从静态描述改为编排器模式。

**子任务**:
1. 更新SKILL.md的description为编排器描述
2. 定义编排流程（doc-consultant→code-searcher→code-editor→code-verifier）
3. 定义自动修复闭环（最多3次重试）
4. 定义输入输出格式
5. 保留现有dependencies声明

**验收标准**:
- [ ] SKILL.md描述编排器模式
- [ ] 编排流程清晰定义
- [ ] 自动修复闭环逻辑描述

---

## CCA-T003: 创建scripts子目录和4个Python脚本

**描述**: 创建cangjie-coder/scripts/目录，编写4个Python脚本。

**子任务**:
1. 创建scripts/目录
2. 编写cangjie_syntax_check.py（仓颉语法检查）
3. 编写cangjie_compile.py（编译验证，调用cjpm build）
4. 编写cangjie_test_runner.py（测试运行）
5. 编写cangjie_fix_suggest.py（修复建议）
6. 每个脚本支持命令行参数和JSON输出

**验收标准**:
- [ ] scripts/目录包含4个.py文件
- [ ] cangjie_compile.py可调用cjpm build
- [ ] 脚本输出JSON格式结果

---

## CCA-T004: 创建references子目录和文档索引

**描述**: 创建cangjie-coder/references/目录，编写文档索引。

**子任务**:
1. 创建references/目录
2. 编写language_guide_index.md（语言指南索引，指向CangjieSkills技能）
3. 编写code_patterns.md（代码模式库，常用仓颉代码模式）

**验收标准**:
- [ ] references/目录包含2个.md文件
- [ ] 语言指南索引正确指向CangjieSkills
- [ ] 代码模式库包含常用模式

---

## CCA-T005: 自动修复闭环实现与测试

**描述**: 测试cangjie-coder的完整编排流程，验证自动修复闭环。

**子任务**:
1. 测试doc-consultant查阅文档
2. 测试code-searcher检索代码
3. 测试code-editor编辑代码
4. 测试code-verifier验证代码
5. 测试自动修复闭环（验证失败→修复→重新验证）
6. 端到端测试：从代码请求到最终输出

**验收标准**:
- [ ] 四个subagent正确协作
- [ ] 验证失败时自动修复闭环工作
- [ ] 生成的仓颉代码通过cjpm build