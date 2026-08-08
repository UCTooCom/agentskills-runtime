# 测试脚本动态生成技能 - 任务清单

## 开发规范

### 仓颉代码开发
- 所有仓颉代码(.cj文件)的编写必须使用 **cangjie-coder 技能**，遵循查阅文档→检索代码→编辑适配→写入文件的四步工作流程
- 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
- 仓颉代码必须符合 CangjieMagic 框架和 V4 模块的约定和模式

### 技能文件开发
- SKILL.md、agents/*.md 遵循YAML frontmatter + Markdown正文格式
- Python脚本遵循项目现有scripts/目录规范，支持命令行参数和JSON输出
- COMPOSITION.yaml遵循现有组合模板格式

---

## 任务总览

| 任务ID | 任务名称 | 优先级 | 预估工时 | 依赖 |
|--------|---------|--------|---------|------|
| TG-T001 | 创建test-generator技能目录和SKILL.md | P0 | 0.5天 | 无 |
| TG-T002 | 创建agents/子目录和3个subagent定义 | P0 | 1天 | TG-T001 |
| TG-T003 | 创建scripts/子目录和5个测试脚本模板 | P0 | 1.5天 | TG-T001 |
| TG-T004 | 创建references/子目录和测试模式文档 | P0 | 0.5天 | TG-T001 |
| TG-T005 | 创建COMPOSITION.yaml闭环组合定义 | P0 | 0.5天 | TG-T002, TG-T003 |
| TG-T006 | 测试反馈闭环端到端验证 | P0 | 1天 | TG-T002, TG-T003, TG-T005 |

---

## TG-T001: 创建test-generator技能目录和SKILL.md

**描述**: 创建skills/test-generator/目录，编写SKILL.md主技能定义文件（编排器模式）。

**子任务**:
1. 创建skills/test-generator/目录
2. 编写SKILL.md，包含YAML frontmatter（name、description、version、dependencies、agents、scripts）
3. 定义编排器模式：test-planner→test-writer→test-runner三步工作流
4. 定义测试反馈闭环逻辑（测试失败→code-editor修复→重新测试，最多3次）
5. 定义输入输出格式
6. 声明依赖：cangjie-coder

**验收标准**:
- [ ] skills/test-generator/SKILL.md文件存在
- [ ] YAML frontmatter包含name、version、dependencies、agents、scripts字段
- [ ] 编排流程清晰定义（三步工作流+闭环）
- [ ] 依赖声明包含cangjie-coder

---

## TG-T002: 创建agents/子目录和3个subagent定义

**描述**: 创建skills/test-generator/agents/目录，编写3个subagent定义文件。

**子任务**:
1. 创建agents/目录
2. 编写test-planner.md（测试规划Agent）
   - YAML frontmatter: name=test-planner, agent_type=sub, tools=[file_read, file_search, directory_list]
   - 定义输入: code_path, test_types, project_path
   - 定义输出: test_cases列表（id, type, target, description, expected_result, framework, priority）
   - 定义处理流程: 分析代码→提取函数/API/数据模型→规划测试用例
3. 编写test-writer.md（测试脚本生成Agent）
   - YAML frontmatter: name=test-writer, agent_type=sub, tools=[file_read, file_write, file_search]
   - 定义输入: test_cases, code_path, project_path, output_dir
   - 定义输出: scripts列表（test_case_id, file_path, framework, language）
   - 定义处理流程: 选择模板→填充测试逻辑→写入脚本文件
   - 定义多框架支持: pytest(requests), pytest(psycopg2), Playwright, cangjie_unittest
4. 编写test-runner.md（测试执行Agent）
   - YAML frontmatter: name=test-runner, agent_type=sub, tools=[file_read, cli_execute]
   - 定义输入: scripts, project_path, timeout_seconds
   - 定义输出: result(pass/partial/fail), total, passed, failed, details, retry_count
   - 定义处理流程: 执行脚本→收集结果→解析输出→生成报告
5. 每个subagent包含完整的YAML frontmatter和协作模式说明

**验收标准**:
- [ ] agents/目录包含3个.md文件
- [ ] 每个文件有完整的YAML frontmatter（name, agent_type, tools, permissions等）
- [ ] test-planner输出结构化测试用例列表
- [ ] test-writer支持4种测试框架
- [ ] test-runner输出结构化测试报告
- [ ] 每个subagent声明了正确的tools和permissions

---

## TG-T003: 创建scripts/子目录和5个测试脚本模板

**描述**: 创建skills/test-generator/scripts/目录，编写5个测试脚本模板和工具。

**子任务**:
1. 创建scripts/目录
2. 编写api_test_template.py（API测试模板）
   - 基于pytest + requests框架
   - 包含fixture定义（base_url, auth_token）
   - 包含参数化测试模式
   - 支持GET/POST/PUT/DELETE方法测试
   - 输出: pytest标准输出
3. 编写db_test_template.py（数据库测试模板）
   - 基于pytest + psycopg2框架
   - 包含fixture定义（db_connection, test_data）
   - 包含事务回滚模式（测试数据隔离）
   - 支持CRUD操作验证
   - 输出: pytest标准输出
4. 编写ui_test_template.js（UI测试模板）
   - 基于Playwright框架
   - 包含页面对象模式
   - 包含截图和trace收集
   - 支持多浏览器测试
   - 输出: Playwright JSON报告
5. 编写cangjie_unit_test_template.py（仓颉单元测试模板）
   - 调用cjpm test执行仓颉unittest
   - 解析仓颉测试输出格式
   - 转换为标准测试结果JSON
   - 输出: JSON格式测试结果
6. 编写test_result_parser.py（测试结果解析器）
   - 解析pytest输出（--tb=json或text）
   - 解析Playwright JSON报告
   - 解析仓颉unittest输出
   - 统一输出为标准JSON格式
   - 支持命令行调用: `python test_result_parser.py --framework pytest --output result.json`
7. 每个脚本支持命令行参数和JSON输出

**验收标准**:
- [ ] scripts/目录包含5个文件（4个模板+1个解析器）
- [ ] api_test_template.py可生成pytest+requests测试脚本
- [ ] db_test_template.py可生成pytest+psycopg2测试脚本
- [ ] ui_test_template.js可生成Playwright测试脚本
- [ ] cangjie_unit_test_template.py可调用cjpm test
- [ ] test_result_parser.py可解析3种框架的测试输出
- [ ] 所有Python脚本支持命令行参数

---

## TG-T004: 创建references/子目录和测试模式文档

**描述**: 创建skills/test-generator/references/目录，编写测试模式参考文档。

**子任务**:
1. 创建references/目录
2. 编写test_patterns.md（测试模式和最佳实践）
   - API测试模式: 请求/响应验证、状态码断言、数据格式校验
   - 数据库测试模式: CRUD验证、事务隔离、数据完整性
   - UI测试模式: 页面对象模式、元素定位、交互验证
   - 仓颉单元测试模式: 函数测试、类型测试、异常测试
   - 测试命名规范
   - 测试数据管理策略
   - 测试覆盖率目标

**验收标准**:
- [ ] references/目录包含test_patterns.md
- [ ] 文档覆盖4种测试框架的测试模式
- [ ] 包含命名规范和数据管理策略

---

## TG-T005: 创建COMPOSITION.yaml闭环组合定义

**描述**: 创建skills/test-generator/COMPOSITION.yaml，定义测试反馈闭环组合。

**子任务**:
1. 创建COMPOSITION.yaml
2. 定义4个步骤: plan-tests, write-tests, run-tests, fix-and-retest
3. 定义步骤依赖关系
4. 定义输入映射（步骤间数据传递）
5. 定义fix-and-retest步骤的条件执行（仅测试失败时触发）
6. 定义重试机制（max_retries=3, retry_on=fail）
7. 定义最终输出

**验收标准**:
- [ ] COMPOSITION.yaml文件存在
- [ ] 包含4个步骤定义
- [ ] 步骤依赖关系正确
- [ ] fix-and-retest步骤有条件执行和重试定义
- [ ] 输出映射正确

---

## TG-T006: 测试反馈闭环端到端验证

**描述**: 验证test-generator技能的完整编排流程和测试反馈闭环。

**子任务**:
1. 验证test-planner分析代码并规划测试用例
   - 输入: 一个仓颉代码文件路径
   - 预期: 输出结构化测试用例列表
2. 验证test-writer生成测试脚本
   - 输入: 测试用例列表
   - 预期: 生成可执行的pytest/Playwright脚本
3. 验证test-runner执行测试并收集结果
   - 输入: 测试脚本列表
   - 预期: 输出结构化测试报告
4. 验证测试反馈闭环
   - 场景: 测试失败→code-editor修复→重新测试
   - 预期: 闭环正确触发，最多3次重试
5. 验证多框架支持
   - API测试: pytest+requests
   - 数据库测试: pytest+psycopg2
   - UI测试: Playwright
   - 仓颉单元测试: cjpm test
6. 验证test_result_parser.py解析3种框架输出

**验收标准**:
- [ ] test-planner正确分析代码并输出测试用例
- [ ] test-writer生成可执行的测试脚本
- [ ] test-runner正确执行测试并收集结果
- [ ] 测试失败时反馈闭环正确触发
- [ ] 最多3次重试后停止
- [ ] 4种测试框架均可正常工作
- [ ] test_result_parser.py正确解析测试输出