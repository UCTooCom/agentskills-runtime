# 全栈代码生成闭环 - 任务清单

## 开发规范

### 仓颉代码开发
- 所有仓颉代码(.cj文件)的编写必须使用 **cangjie-coder 技能**，遵循查阅文档→检索代码→编辑适配→写入文件的四步工作流程
- 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
- 仓颉代码必须符合 CangjieMagic 框架和 V4 模块的约定和模式

---

| 任务ID | 任务名称 | 优先级 | 预估工时 | 依赖 |
|--------|---------|--------|---------|------|
| FSC-T001 | 创建fullstack-codegen组合模板 | P0 | 0.5天 | code-gen-skills |
| FSC-T002 | 实现ModelSyncAdapter前后端同构 | P0 | 1天 | 无 |
| FSC-T003 | 增强AutoCreateCode增量生成 | P0 | 0.5天 | 无 |
| FSC-T004 | 构建验证闭环集成 | P0 | 0.5天 | code-gen-skills |
| FSC-T005 | 端到端集成测试 | P0 | 0.5天 | FSC-T001~T004 |

---

## FSC-T001: 创建fullstack-codegen组合模板

**描述**: 创建fullstack-codegen COMPOSITION.yaml组合模板。

**子任务**:
1. 创建skills/fullstack-codegen/目录
2. 编写SKILL.md
3. 编写COMPOSITION.yaml（6步闭环流程）
4. 测试组合模板可被解析

**验收标准**:
- [ ] fullstack-codegen组合模板可解析
- [ ] 6步流程定义正确

---

## FSC-T002: 实现ModelSyncAdapter前后端同构

**描述**: 实现后端PO模型到前端ORM模型的自动映射。

**子任务**:
1. 创建skills/model-sync/目录和SKILL.md
2. 解析后端PO.cj文件，提取字段定义
3. 生成前端ORM模型（TypeScript/pinia-orm格式）
4. 字段类型映射：String→string、Int64→number、DateTime→Date等
5. 验证规则同步

**验收标准**:
- [ ] 后端PO可自动映射为前端ORM模型
- [ ] 字段类型映射正确
- [ ] 验证规则同步正确

---

## FSC-T003: 增强AutoCreateCode增量生成

**描述**: 增强crudgen的AutoCreateCode区域处理，支持增量代码生成。

**子任务**:
1. 分析现有AutoCreateCode标记机制
2. 增强模板引擎，支持保留自定义代码区域
3. 实现代码合并策略（新增/更新/保留）

**验收标准**:
- [ ] 增量生成不覆盖自定义代码
- [ ] 代码合并策略正确

---

## FSC-T004: 构建验证闭环集成

**描述**: 将CodeGenVerifier集成到全栈代码生成闭环中。

**子任务**:
1. 代码生成后自动调用cjpm build
2. 验证失败时自动反馈到cangjie-coder修复
3. 修复后重新验证

**验收标准**:
- [ ] 代码生成后自动构建验证
- [ ] 验证失败自动反馈修复

---

## FSC-T005: 端到端集成测试

**描述**: 测试全栈代码生成闭环的完整流程。

**子任务**:
1. 测试loaddbinfo→crudgen→crudweb闭环
2. 测试前后端模型同构
3. 测试构建验证闭环
4. 测试增量代码生成

**验收标准**:
- [ ] 全栈闭环可自动执行
- [ ] 生成的代码通过cjpm build