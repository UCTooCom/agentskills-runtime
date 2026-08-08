# 代码生成工具Skills化封装 - 任务清单

## 开发规范

### 仓颉代码开发
- 所有仓颉代码(.cj文件)的编写必须使用 **cangjie-coder 技能**，遵循查阅文档→检索代码→编辑适配→写入文件的四步工作流程
- 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
- 仓颉代码必须符合 CangjieMagic 框架和 V4 模块的约定和模式

---

| 任务ID | 任务名称 | 优先级 | 预估工时 | 依赖 |
|--------|---------|--------|---------|------|
| CGS-T001 | 更新crud-generator SKILL.md为v2.0.0 | P0 | 0.5天 | 无 |
| CGS-T002 | 创建loaddbinfo SKILL.md | P0 | 0.5天 | 无 |
| CGS-T003 | 创建code-gen-optimize COMPOSITION.yaml | P0 | 0.5天 | CGS-T001, CGS-T002 |
| CGS-T004 | 创建code-gen-verifier技能 | P0 | 1天 | 无 |
| CGS-T005 | 代码生成闭环验证实现 | P0 | 1天 | CGS-T004 |
| CGS-T006 | 与SkillToToolAdapter集成测试 | P0 | 0.5天 | CGS-T001~T005 |

---

## CGS-T001: 更新crud-generator SKILL.md

**描述**: 更新skills/crud-generator/SKILL.md为v2.0.0，增加标准化输入输出定义。

**子任务**:
1. 增加inputs/outputs标准字段
2. 增加dependencies声明（loaddbinfo）
3. 更新description为全栈CRUD代码生成
4. 保留现有内容和模板

**验收标准**:
- [ ] SKILL.md包含inputs/outputs定义
- [ ] 依赖声明正确

---

## CGS-T002: 创建loaddbinfo SKILL.md

**描述**: 创建skills/loaddbinfo/SKILL.md技能定义文件。

**子任务**:
1. 创建loaddbinfo技能目录
2. 编写SKILL.md，定义inputs（database）和outputs（表结构信息）
3. 与LoadDbInfoService API对接

**验收标准**:
- [ ] loaddbinfo技能可通过SKILL.md加载
- [ ] 输入输出定义正确

---

## CGS-T003: 创建code-gen-optimize COMPOSITION.yaml

**描述**: 创建code-gen-optimize组合模板。

**子任务**:
1. 在skills/crud-generator/目录下创建COMPOSITION.yaml
2. 定义4步组合流程
3. 定义输入映射表达式
4. 测试组合模板可被CompositionYamlParser解析

**验收标准**:
- [ ] COMPOSITION.yaml格式正确
- [ ] 组合模板可被解析

---

## CGS-T004: 创建code-gen-verifier技能

**描述**: 创建代码生成验证技能。

**子任务**:
1. 创建skills/code-gen-verifier/目录
2. 编写SKILL.md
3. 实现编译验证（调用cjpm build）
4. 实现API验证（调用生成的API接口）
5. 实现业务规则验证

**验收标准**:
- [ ] code-gen-verifier技能可加载
- [ ] 编译验证正确工作

---

## CGS-T005: 代码生成闭环验证实现

**描述**: 实现代码生成的闭环验证流程。

**子任务**:
1. 实现验证失败时的错误反馈
2. 实现与cangjie-coder的修复闭环
3. 端到端测试：生成→验证→修复→再验证

**验收标准**:
- [ ] 验证失败时自动反馈
- [ ] 修复闭环正确工作

---

## CGS-T006: 与SkillToToolAdapter集成测试

**描述**: 测试技能化封装后的代码生成工具可通过SkillToToolAdapter调用。

**子任务**:
1. 测试crud-generator技能通过SkillToToolAdapter调用
2. 测试loaddbinfo技能通过SkillToToolAdapter调用
3. 测试code-gen-optimize组合模板执行

**验收标准**:
- [ ] 技能可通过SkillToToolAdapter调用
- [ ] 组合模板可正确执行