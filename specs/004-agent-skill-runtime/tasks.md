# AgentSkills-Runtime 开发任务列表

> 基于 [skill_execution_design.md](./skill_execution_design.md) 设计文档，按照 MVP 优先原则规划开发任务。
> 
> **版本**: 1.1.0  
> **创建日期**: 2026-02-21  
> **更新日期**: 2026-02-21  
> **状态**: 开发中

---

## 任务优先级说明

| 优先级 | 说明 |
|--------|------|
| P0 | MVP 核心功能，必须完成 |
| P1 | 重要功能，MVP 后立即实现 |
| P2 | 增强功能，按需实现 |
| P3 | 优化功能，可延后实现 |

---

# 历史任务记录 (已完成的开发工作)

> 以下任务来自原 tasks.md 备份文件，记录了项目从启动到当前的已完成工作。
> 部分任务可能只实现了框架和主流程，具体功能可能需要进一步完善。

**Feature**: Agent Skill Runtime - Universal runtime for AI agent tools that is secure, portable, and intelligent  
**Tech Stack**: Cangjie 1.0 (primary kernel), TypeScript/JavaScript (ecosystem layer)  
**Project Structure**: Based on CangjieMagic framework with uctoo-inspired enhancements  
**Feature Spec**: [004-agent-skill-runtime](specs/004-agent-skill-runtime/spec.md)

## 历史任务依赖关系

### User Story Completion Order
- US7 (P1) - 集成CangjieMagic框架: Foundation using existing 003-agentskills-enhancement implementation
- US1 (P1) - 安装并运行AI技能: Built on top of CangjieMagic foundation
- US6 (P1) - 技能安装管理: Implemented via CLI and API
- US3 (P1) - 安全执行技能: Enhanced security layer
- US2 (P1) - 搜索和发现技能: Added after core functionality
- US4 (P2) - 开发生命周期管理: Added after core functionality
- US5 (P2) - 跨平台兼容性: Ensured throughout development

### Parallel Execution Opportunities
- API and CLI development can run in parallel after CangjieMagic foundation
- JavaScript SDK development can run in parallel after API implementation
- Security enhancements can run in parallel after core functionality
- Search capabilities can run in parallel after core functionality

---

## Phase 1: Setup (已完成)

### Story Goal
Initialize the project structure and development environment for the agent skill runtime.

### Independent Test Criteria
Project can be built and basic tests pass.

### Implementation Tasks
- [X] T000 详细研究apps/CangjieMagic/ 目录中已有的代码和文档，掌握正确的CangjieMagic框架拓展开发。也参考此文档 specs\004-agent-skill-runtime\STRUCTURE_VERIFICATION.md
  - **研究成果**: CangjieMagic 框架已实现完整的技能管理基础设施，包括：
    - `src/skill/` - 技能模块（领域层、应用层、基础设施层）
    - `src/dsl/` - DSL 实现（包含 @skill 宏）
    - `src/agent_executor/` - 多种执行器（ReAct、PlanReAct、Naive等）
    - `src/mcp/` - MCP 协议支持
    - `src/rag/` - RAG 检索增强生成
    - `src/core/` - 核心框架（Agent、Tool、Memory、Model）
- [X] T001 详细阅读开发宪章文档.specify\memory\constitution.md ，确保以遵循仓颉编程语言代码输出工作流的方式进行开发，输出符合仓颉编程语言规范的代码。
  - **研究成果**: 必须遵循仓颉编程语言代码输出工作流：
    1. 严禁直接生成仓颉代码，必须从 CangjieMagic/resource 目录检索已有代码
    2. 复制基本符合需求的代码，按规范二次编辑
    3. 尽可能复用仓颉标准库、stdx拓展库、TPC第三方库
- [X] T002 [P] 研究apps\CangjieMagic\resource 目录中仓颉标准库、stdx拓展库、TPC第三方库已有的生态基础能力和组件，尽量复用仓颉生态已有基础设施，完善specs\004-agent-skill-runtime 项目的设计文档。如果有可复用的第三方库则添加到CangjieMagic框架的依赖配置文件中。
  - **研究成果**: 详见下方"可复用的仓颉生态第三方库"章节
- [X] T003 [P] 根据以上研究情况进一步优化specs\004-agent-skill-runtime\tasks.md 任务文档，确保基于已有开发成果进行增量开发，不覆盖原有已开发已测试已发布的功能特性。
- [X] T004 Create initial README.md with project overview
- [X] T005 Set up basic documentation structure in apps/CangjieMagic/docs/

---

## Phase 2: [US7] 集成CangjieMagic框架 (已完成)

### Story Goal
Enhance existing CangjieMagic framework from specs/003-agentskills-enhancement with uctoo-inspired features to create and manage skills, utilizing its DSL advantages and ecosystem.

### Independent Test Criteria
Can create a skill using CangjieMagic DSL (`@skill` macro) and verify it integrates correctly with the enhanced framework.

### Implementation Tasks
- [X] T009 [US7] [P] Integrate existing CangjieMagic agentskill implementation from specs/003-agentskills-enhancement，Enhance CangjieMagic框架原有的log机制，统一采用JSON格式，防止由于log格式不符造成对MCP等通信协议的干扰
- [X] T010 [US7] [P] Enhance @skill DSL macro with uctoo-inspired features in apps/CangjieMagic/src/dsl/skill_macro.cj
- [ ] T011 [US7] [P] Enhance SkillManager interface following CangjieMagic patterns **(待完善)**
- [X] T012 [US7] [P] Enhance CompositeSkillToolManager with uctoo-inspired features in apps/CangjieMagic/src/skill/composite_skill_tool_manager.cj
- [ ] T013 [US7] [P] Enhance MCP server following CangjieMagic patterns **(待完善)**
- [X] T014 [US7] [P] Enhance progressive skill loader with uctoo-inspired features in apps/CangjieMagic/src/skill/progressive_skill_loader.cj
- [X] T015 [US7] [P] Enhance standard skill validator with uctoo-inspired features in apps/CangjieMagic/src/skill/standard_skill_validator.cj
- [X] T016 [US7] [P] Enhance skill factory system with uctoo-inspired features in apps/CangjieMagic/src/skill/skill_factory.cj
- [X] T017 [US7] [P] Enhance skill registry following CangjieMagic architecture
- [ ] T018 [US7] [P] Enhance MCP protocol support to skill runtime **(待完善)**
- [X] T019 [US7] [P] Create example skills using @skill DSL
- [X] T020 [US7] [P] Enhance skill loading from multiple directories
- [X] T021 [US7] [P] Add backward compatibility with existing CangjieMagic skills

---

## Phase 3: CLI and API Layer Development (已完成)

### Story Goal
Create command-line interface and standard API layer for managing and executing skills.

### Independent Test Criteria
Can execute basic CLI commands and API endpoints respond correctly.

### Implementation Tasks
- [X] T022 [P] Create CLI command structure in apps/CangjieMagic/src/cli/
- [X] T023 [P] Implement basic skill execution command (`skill run`)
- [X] T024 [P] Implement skill listing command (`skill list`)
- [X] T025 [P] Create API router and middleware
- [X] T026 [P] Implement GET /skills endpoint following contracts/api-contract.yaml
- [X] T027 [P] Implement GET /skills/:id endpoint following contracts/api-contract.yaml
- [X] T028 [P] Implement POST /skills/execute endpoint following contracts/api-contract.yaml **(框架已实现，具体执行逻辑待完善)**
- [X] T029 [P] Add authentication middleware for API endpoints
- [X] T030 [P] Create API documentation following contracts/api-contract.yaml
- [X] T031 [P] Add error handling for API endpoints
- [X] T032 [P] Implement request validation for API endpoints
- [X] T033 [P] Add rate limiting for API endpoints

---

## Phase 4: JavaScript SDK Development (已完成)

### Story Goal
Create JavaScript SDK that allows developers to create and manage skills using JavaScript/TypeScript.

### Independent Test Criteria
Can create a skill using the JavaScript SDK and execute it via the runtime.

### Implementation Tasks
- [X] T034 [P] Create JavaScript SDK package structure
- [X] T035 [P] Implement defineSkill function for skill definition
- [X] T036 [P] Create getConfig utility for configuration management
- [X] T037 [P] Implement SkillRuntimeClient for API communication
- [X] T038 [P] Create CLI tool for npm skill commands
- [X] T039 [P] Implement skill installation command for JavaScript SDK
- [X] T040 [P] Add TypeScript type definitions
- [X] T041 [P] Create JavaScript SDK documentation
- [X] T042 [P] Implement configuration validation for JavaScript SDK
- [X] T043 [P] Add error handling for JavaScript SDK
- [X] T044 [P] Create usage examples for JavaScript SDK
- [X] T045 [P] Publish JavaScript SDK to npm registry **(@opencangjie/skills 已发布)**

---

## Phase 5: [US1] 安装并运行AI技能 (已完成)

### Story Goal
Enable users to install and run AI agent skills in a secure environment, allowing AI to execute external tasks like querying databases, managing infrastructure, and calling APIs.

### Independent Test Criteria
Can install a simple skill (e.g., hello-world skill) and successfully execute it in the runtime.

### Implementation Tasks
- [X] T049 [US1] Implement basic skill loading functionality from local files
- [X] T050 [US1] [P] Implement skill execution engine in apps/CangjieMagic/src/skill/execution_engine.cj **(框架已实现，具体执行逻辑待完善)**
- [X] T051 [US1] [P] Enhance skill manifest parser for SKILL.md files with uctoo-inspired features
- [X] T052 [US1] [P] Create skill validation service in apps/CangjieMagic/src/skill/validation_service.cj
- [X] T053 [US1] [P] Enhance skill-to-tool adapter with uctoo-inspired features in apps/CangjieMagic/src/skill/skill_to_tool_adapter.cj
- [X] T054 [US1] [P] Create skill execution context management
- [X] T055 [US1] [P] Implement parameter validation for skill execution
- [X] T056 [US1] [P] Create basic skill lifecycle management (load, execute, unload)
- [X] T057 [US1] [P] Implement API endpoint for skill execution (POST /skills/execute) **(框架已实现，具体执行逻辑待完善)**
- [X] T058 [US1] [P] Create hello-world skill example for testing
- [X] T059 [US1] [P] Implement error handling for skill execution failures
- [X] T060 [US1] [P] Add logging and monitoring for skill execution

---

## Phase 6: [US6] 技能安装管理 (已完成)

### Story Goal
Enable users to install skills through command-line interface, supporting installation from local paths and Git repositories.

### Independent Test Criteria
Can install skills from local path using `skill install --path` and from Git repository using `skill install --git`.

### Implementation Tasks
- [X] T064 [US6] [P] Implement SkillPackageManager in apps/CangjieMagic/src/skill/application/skill_package_manager.cj
- [X] T065 [US6] [P] Create CLI command for skill installation (`skill install`)
- [X] T066 [US6] [P] Implement local path installation functionality (`--path` option)
- [X] T067 [US6] [P] Implement Git repository installation functionality (`--git` option)
- [X] T068 [US6] [P] Add Git branch, tag, and commit support (`--branch`, `--tag`, `--commit` options)
- [X] T069 [US6] [P] Implement skill dependency resolution
- [X] T070 [US6] [P] Create skill registry for installed skills
- [X] T071 [US6] [P] Implement skill lifecycle management (install, update, uninstall)
- [X] T072 [US6] [P] Add API endpoint for skill installation (POST /skills/add)
- [X] T073 [US6] [P] Add API endpoint for skill deletion (POST /skills/del)
- [X] T074 [US6] [P] Implement skill version management
- [X] T075 [US6] [P] Add validation for installed skills

---

## Phase 7: [US3] 安全执行技能 (已完成)

### Story Goal
Ensure skills execute in a secure environment preventing malicious code from accessing sensitive data or system resources.

### Independent Test Criteria
A skill attempting to access restricted resources is prevented from doing so and the violation is logged.

### Implementation Tasks
- [X] T079 [US3] [P] Implement WASM-based security sandbox in apps/CangjieMagic/src/skill/security/wasm_sandbox.cj **(框架已实现，具体沙箱逻辑待完善)**
- [X] T080 [US3] [P] Create capability-based access control system
- [X] T081 [US3] [P] Implement resource quota management for CPU, memory, and I/O
- [X] T082 [US3] [P] Add scene-based hierarchical security mechanisms
- [X] T083 [US3] [P] Implement execution context isolation
- [X] T084 [US3] [P] Create security policy engine
- [X] T085 [US3] [P] Add capability validation for skill execution
- [X] T086 [US3] [P] Implement security monitoring and logging
- [X] T087 [US3] [P] Create security validation for skill installation
- [X] T088 [US3] [P] Add runtime security enforcement
- [X] T089 [US3] [P] Implement secure file system access controls
- [X] T090 [US3] [P] Add secure network access controls

---

## Phase 8: [US2] 搜索和发现技能 (已完成)

### Story Goal
Allow users to find appropriate skills through natural language search rather than remembering specific skill names.

### Independent Test Criteria
Inputting a natural language query (e.g., "manage kubernetes pods") returns relevant skills and tools.

### Implementation Tasks
- [X] T094 [US2] [P] Implement advanced RAG search pipeline in apps/CangjieMagic/src/skill/search/advanced_rag_search.cj
- [X] T095 [US2] [P] Create vector store for skill embeddings
- [X] T096 [US2] [P] Implement hybrid search with dense vectors + BM25 sparse search
- [X] T097 [US2] [P] Add RRF (Reciprocal Rank Fusion) algorithm for result fusion
- [X] T098 [US2] [P] Implement cross-encoder reranking for improved precision
- [X] T099 [US2] [P] Create query understanding module with intent classification
- [X] T100 [US2] [P] Add context compression for token-efficient output
- [X] T101 [US2] [P] Implement persistent indexing with content-hash change detection
- [X] T102 [US2] [P] Add semantic search with usage examples for better discovery
- [X] T103 [US2] [P] Create API endpoint for skill search (POST /skills/search)
- [X] T104 [US2] [P] Implement search result ranking and scoring
- [X] T105 [US2] [P] Add search analytics and monitoring

---

## Phase 9: [US4] 开发生命周期管理 (已完成)

### Story Goal
Provide a complete toolkit for developers to develop, test, distribute, and deploy skills.

### Independent Test Criteria
Can create a new skill, test it, package it, and successfully install it into the runtime.

### Implementation Tasks
- [X] T109 [US4] [P] Create skill development templates and scaffolding
- [X] T110 [US4] [P] Implement skill testing framework
- [X] T111 [US4] [P] Add skill packaging functionality
- [X] T112 [US4] [P] Create skill distribution mechanisms
- [X] T113 [US4] [P] Implement skill deployment tools
- [X] T114 [US4] [P] Add skill debugging and profiling tools
- [X] T115 [US4] [P] Create skill documentation generation
- [X] T116 [US4] [P] Implement skill version control integration
- [X] T117 [US4] [P] Add skill dependency management tools
- [X] T118 [US4] [P] Create skill marketplace integration
- [X] T119 [US4] [P] Implement continuous integration pipelines for skills
- [X] T120 [US4] [P] Add skill performance monitoring tools

---

## Phase 10: [US5] 跨平台兼容性 (已完成)

### Story Goal
Enable the runtime to run on different operating systems and architectures while maintaining consistent functionality.

### Independent Test Criteria
Same skill executes with consistent results on Windows, Linux, and macOS platforms.

### Implementation Tasks
- [X] T124 [US5] [P] Implement platform abstraction layer for system calls
- [X] T125 [US5] [P] Create cross-platform build configurations
- [X] T126 [US5] [P] Add platform-specific security implementations
- [X] T127 [US5] [P] Implement cross-platform file system abstractions
- [X] T128 [US5] [P] Create platform-specific resource management
- [X] T129 [US5] [P] Add cross-platform networking implementations
- [X] T130 [US5] [P] Implement platform-specific performance optimizations
- [X] T131 [US5] [P] Create platform compatibility testing framework
- [X] T132 [US5] [P] Add platform-specific packaging and distribution
- [X] T133 [US5] [P] Implement cross-platform CI/CD pipelines
- [X] T134 [US5] [P] Create platform-specific documentation
- [X] T135 [US5] [P] Add platform-specific troubleshooting guides

---

## Phase 11: Polish & Cross-Cutting Concerns (已完成)

### Story Goal
Complete integration with UCToo Admin platform, enhance CLI and web interfaces, and address cross-cutting concerns.

### Independent Test Criteria
All features work together seamlessly and the system meets performance and reliability requirements.

### Implementation Tasks
- [X] T136 Integrate with UCToo Admin management platform (Vue 3 + Ant Design Vue)
- [X] T137 [P] Enhance CLI with advanced commands (skill find, skill serve, skill enhance, skill setup, skill web, skill auth)
- [X] T138 [P] Implement web interface for skill management in apps/CangjieMagic/src/web/
- [X] T139 [P] Add HTTP streaming mode with embedded web UI for MCP server
- [X] T140 [P] Create comprehensive documentation following quickstart.md guidelines
- [X] T141 [P] Implement performance optimizations for 10,000+ concurrent executions
- [X] T142 [P] Add comprehensive monitoring and observability features
- [X] T143 [P] Implement backup and recovery mechanisms
- [X] T144 [P] Add internationalization support
- [X] T145 [P] Conduct security audit and penetration testing
- [X] T146 [P] Perform load testing to validate performance requirements
- [X] T147 [P] Create migration tools for upgrading existing installations

---

## Phase 12: 发布打包 (已完成)

### Story Goal
Create automated packaging scripts for releasing the runtime kernel with clean, optimized packages.

### Independent Test Criteria
Can build and package the runtime with a single command, producing a clean release package without examples/tests.

### Implementation Tasks
- [X] T148 [P] Create package_release script in src/scripts/package_release/main.cj
- [X] T149 [P] Implement automatic version detection from cjpm.toml
- [X] T150 [P] Implement automatic platform detection (win-x64, linux-x64, darwin-arm64)
- [X] T151 [P] Add filtering for unnecessary DLLs (examples, tests)
- [X] T152 [P] Add filtering for unnecessary directories (examples, tests, .build-logs)
- [X] T153 [P] Implement VERSION file generation with build metadata
- [X] T154 [P] Add project root detection for running from any subdirectory
- [X] T155 [P] Create tar.gz archive for distribution
- [X] T156 [P] Update README documentation with release packaging instructions
- [X] T157 [P] Update release_plan.md with actual implementation details
- [X] T158 [P] Update quickstart.md with installation from release package

---

# 当前阶段任务规划

> 以下任务基于设计文档 [skill_execution_design.md](./skill_execution_design.md) 规划，按照 MVP 优先原则。
> 重点完善已实现框架的具体功能逻辑。

---

## 阶段 0: MVP - 最小可行产品 (功能完善)

> 目标：完善已实现框架的具体执行逻辑，实现真正可运行技能的功能

### 0.1 核心执行引擎 (P0) - 功能完善 ✅ 已完成

#### 0.1.1 技能执行 API 端点完善 ✅
- **任务**: 完善 `POST /skills/execute` API 端点的实际执行逻辑
- **依赖**: 无
- **文件**: 
  - `src/api/api_router.cj` (修改)
  - `src/skill/skill_execution_engine.cj` (修改)
- **验收标准**:
  - [x] 接收技能执行请求并解析参数
  - [x] 调用 SkillExecutionEngine 真正执行技能
  - [x] 返回实际执行结果（非占位符）
  - [x] 完整的错误处理和日志记录
- **状态**: ✅ 已完成
- **完成日期**: 2026-02-21
- **实现说明**: 
  - 完善了 `handleExecuteSkill` 方法，实现了完整的请求解析、技能查找、参数转换
  - 集成了 SkillExecutionEngine 进行安全执行
  - 添加了超时解析、资源使用统计、执行时间记录
  - 完善了错误处理和日志记录

#### 0.1.2 技能执行引擎完善 ✅
- **任务**: 完善 SkillExecutionEngine 的执行流程
- **依赖**: 0.1.1
- **文件**: 
  - `src/skill/skill_execution_engine.cj`
- **验收标准**:
  - [x] 支持同步执行技能
  - [x] 支持超时控制
  - [x] 支持资源限制
  - [x] 执行状态追踪
  - [x] 实际调用大模型执行
- **状态**: ✅ 已完成
- **完成日期**: 2026-02-21
- **实现说明**:
  - 实现了 `_executeWithTimeout` 方法，使用 Future 和 ResultHolder 模式进行超时控制
  - 添加了资源使用追踪（CPU时间、内存峰值、网络IO、文件操作）
  - 实现了安全执行方法 `executeSkillSecurely`
  - 完善了异常处理和错误报告

#### 0.1.3 ReAct 执行器集成 ✅
- **任务**: 将 ReactExecutor 与技能执行完整集成
- **依赖**: 0.1.2
- **文件**: 
  - `src/agent_executor/react/react_executor.cj`
  - `src/skill/skill_execution_engine.cj`
  - `src/skill/composite_skill_tool_manager.cj`
  - `src/skill/skill_react_executor.cj` (新增)
- **验收标准**:
  - [x] 技能可作为工具被 ReAct 调用
  - [x] 支持多轮对话
  - [x] 支持工具选择
  - [x] 完整的执行链路
- **状态**: ✅ 已完成
- **完成日期**: 2026-02-21
- **实现说明**:
  - 创建了 `SkillReACTExecutor` 类，实现技能与 ReAct 执行器的集成
  - 实现了 `executeWithReACT` 方法，支持基于推理的技能执行
  - 添加了系统提示构建、工具管理器创建、迭代次数提取等功能
  - 完善了错误处理和结果转换

### 0.2 技能加载系统 (P0) - 功能完善 ✅ 已完成

#### 0.2.1 渐进式技能加载器完善 ✅
- **任务**: 完善 ProgressiveSkillLoader 实现
- **依赖**: 无
- **文件**: 
  - `src/skill/application/progressive_skill_loader.cj`
  - `src/skill/application/enhanced_progressive_skill_loader.cj`
  - `src/agent_executor/skill_aware/skill_aware_executor.cj` (新增)
- **验收标准**:
  - [x] 三阶段加载：元数据 → 描述 → 实现
  - [x] 支持延迟加载
  - [x] 支持缓存机制
  - [x] 实际加载技能内容
- **状态**: ✅ 已完成
- **完成日期**: 2026-02-21
- **实现说明**:
  - 创建了 `SkillAwareExecutor` 类，实现智能技能感知执行器
  - 实现了 `findRelevantSkills` 方法，基于关键词和语义匹配查找相关技能
  - 添加了关键词提取、停用词过滤、技能启用/禁用管理
  - 实现了直接执行和 Agent 执行两种模式
  - 支持技能热重载和列表查询

#### 0.2.2 技能解析服务完善 ✅
- **任务**: 完善 SKILL.md 解析
- **依赖**: 0.2.1
- **文件**: 
  - `src/skill/application/skill_parsing_service.cj`
  - `src/skill/application/default_skill_parsing_service.cj` (新增)
  - `src/skill/infrastructure/loaders/skill_md_loader.cj`
- **验收标准**:
  - [x] 解析 YAML frontmatter
  - [x] 解析技能描述
  - [x] 解析参数定义
  - [x] 解析执行指令
  - [x] 支持复杂 Markdown 内容
- **状态**: ✅ 已完成
- **完成日期**: 2026-02-21
- **实现说明**:
  - 创建了 `DefaultSkillParsingService` 类，实现 SkillParsingService 接口
  - 实现了完整的 YAML frontmatter 解析和 Markdown body 提取
  - 添加了参数定义解析功能，支持从 Markdown 参数章节和 YAML 元数据中提取参数
  - 支持中英文参数定义（Type/类型、Required/必填、Default/默认值、Description/描述）
  - 完善了技能目录检测（scripts、references、assets 目录）

#### 0.2.3 技能验证服务完善 ✅
- **任务**: 完善技能验证逻辑
- **依赖**: 0.2.2
- **文件**: 
  - `src/skill/application/skill_validation_service.cj`
  - `src/skill/application/enhanced_skill_validation_service.cj` (新增)
  - `src/skill/infrastructure/validators/skill_manifest_validator.cj`
- **验收标准**:
  - [x] 验证必填字段
  - [x] 验证参数类型
  - [x] 验证技能结构
  - [x] 返回详细错误信息
  - [x] 支持 AgentSkills 标准验证
- **状态**: ✅ 已完成
- **完成日期**: 2026-02-21
- **实现说明**:
  - 创建了 `EnhancedSkillValidationService` 类，提供全面的技能验证功能
  - 实现了参数验证：名称格式、类型有效性、描述完整性、重复参数检测
  - 添加了指令验证：检查指令长度、动作关键词检测
  - 支持验证结果分级：错误和警告分离，提供详细的错误信息
  - 支持中英文动作关键词检测

### 0.3 技能管理服务 (P0) - 功能完善 ✅ 已完成

#### 0.3.1 技能安装服务完善 ✅
- **任务**: 完善技能安装流程
- **依赖**: 无
- **文件**: 
  - `src/skill/application/skill_package_manager.cj`
- **验收标准**:
  - [x] 支持从 Git 仓库安装
  - [x] 支持从本地目录安装
  - [x] 支持版本管理
  - [x] 安装状态追踪
  - [x] Windows 长路径问题已解决
- **状态**: ✅ 已完成
- **完成日期**: 2026-02-21
- **预估工时**: 2 天

#### 0.3.2 技能搜索服务完善 ✅
- **任务**: 完善公网技能搜索
- **依赖**: 无
- **文件**: 
  - `src/skill/search/public_skill_search.cj`
- **验收标准**:
  - [x] 支持 GitHub 搜索
  - [x] 支持 AtomGit 搜索（需 Token）
  - [x] 支持 Gitee 搜索
  - [x] 搜索结果排序
- **状态**: ✅ 已完成
- **完成日期**: 2026-02-21
- **预估工时**: 1 天

#### 0.3.3 技能卸载服务完善 ✅
- **任务**: 完善技能卸载功能
- **依赖**: 0.3.1
- **文件**: 
  - `src/skill/application/skill_management_service.cj`
  - `apps/backend/src/app/controllers/uctoo/agent_skills/index.ts`
- **验收标准**:
  - [x] 删除技能文件
  - [x] 清理注册信息
  - [x] 更新数据库记录
  - [x] 前端界面同步更新
- **状态**: ✅ 已完成
- **完成日期**: 2026-02-21
- **预估工时**: 1 天

### 0.4 CLI 工具 (P0) - 功能完善 ✅ 已完成

#### 0.4.1 技能安装命令完善 ✅
- **任务**: 完善 `skill install` 命令
- **依赖**: 0.3.1
- **文件**: 
  - `src/cli/skill_cli.cj`
  - `sdk/javascript/src/index.ts`
- **验收标准**:
  - [x] 支持 `--git` 参数
  - [x] 支持 `--path` 参数
  - [x] 支持 `--branch` 参数
  - [x] 命令行输出友好
  - [x] 进度显示
- **状态**: ✅ 已完成
- **完成日期**: 2026-02-21
- **预估工时**: 1 天

#### 0.4.2 技能列表命令完善 ✅
- **任务**: 完善 `skill list` 命令
- **依赖**: 0.2.1
- **文件**: 
  - `src/cli/skill_cli.cj`
  - `sdk/javascript/src/index.ts`
- **验收标准**:
  - [x] 列出已安装技能
  - [x] 显示技能状态
  - [x] 支持过滤和排序
  - [x] 格式化输出
- **状态**: ✅ 已完成
- **完成日期**: 2026-02-21
- **预估工时**: 1 天

#### 0.4.3 技能执行命令完善 ✅
- **任务**: 完善 `skill run` 命令
- **依赖**: 0.1.1
- **文件**: 
  - `src/cli/skill_cli.cj`
  - `sdk/javascript/src/index.ts`
- **验收标准**:
  - [x] 指定技能 ID
  - [x] 传递参数
  - [x] 显示执行结果
  - [ ] 支持流式输出
- **状态**: ✅ 已完成（流式输出待后续优化）
- **完成日期**: 2026-02-21
- **预估工时**: 2 天

### 0.5 MVP 集成测试 (P0)

#### 0.5.1 端到端测试
- **任务**: 编写 MVP 功能的集成测试
- **依赖**: 0.1-0.4
- **文件**: 
  - `tests/integration/mvp_test.cj` (新建)
- **验收标准**:
  - [ ] 测试技能安装流程
  - [ ] 测试技能执行流程
  - [ ] 测试错误处理
  - [ ] 测试完整链路
- **状态**: 待开发
- **预估工时**: 3 天

#### 0.5.2 示例技能验证
- **任务**: 使用示例技能验证 MVP 功能
- **依赖**: 0.5.1
- **文件**: 
  - `src/examples/` 目录下的示例技能
- **验收标准**:
  - [ ] hello-world 技能可运行
  - [ ] find-skills 技能可运行
  - [ ] arkts-syntax-assistant 技能可运行
  - [ ] 所有示例技能通过验证
- **状态**: 待验证
- **预估工时**: 2 天

---

## 阶段 1: 核心能力完善

> 目标：完善核心功能，提升系统稳定性和可用性

### 1.1 技能门控系统 (P1) ✅ 已完成

#### 1.1.1 门控规则定义 ✅
- **任务**: 实现技能门控规则数据结构
- **依赖**: MVP 完成
- **文件**: 
  - `src/skill/domain/models/skill_gating.cj` (新建)
- **验收标准**:
  - [x] 定义 `requires.bins` 规则
  - [x] 定义 `requires.anyBins` 规则
  - [x] 定义 `requires.env` 规则
  - [x] 定义 `requires.config` 规则
  - [x] 定义 `os` 限制规则
- **状态**: ✅ 已完成
- **完成日期**: 2026-02-22
- **预估工时**: 2 天
- **实现说明**:
  - 定义了 `OSType` 枚举，支持 Windows/Linux/macOS
  - 定义了 `GatingRequirementType` 枚举，支持 Binary/Environment/Directory/File/Custom
  - 实现了 `GatingRequirement`、`GatingCheckResult`、`SkillGatingRules` 核心数据结构
  - 提供了 `createSimpleRequirement()` 工厂方法简化常用需求创建

#### 1.1.2 门控检查服务 ✅
- **任务**: 实现门控检查逻辑
- **依赖**: 1.1.1
- **文件**: 
  - `src/skill/application/skill_gating_service.cj` (新建)
- **验收标准**:
  - [x] 检查二进制文件存在性
  - [x] 检查环境变量
  - [x] 检查配置项
  - [x] 检查操作系统兼容性
  - [x] 返回详细的检查结果
- **状态**: ✅ 已完成
- **完成日期**: 2026-02-22
- **预估工时**: 3 天
- **实现说明**:
  - 实现了 `SkillGatingService` 静态服务类
  - 支持二进制文件检查（通过 PATH 环境变量搜索）
  - 支持环境变量检查和值匹配
  - 支持操作系统兼容性检查
  - 提供详细的检查结果和失败原因

#### 1.1.3 门控集成到加载流程
- **任务**: 将门控检查集成到技能加载流程
- **依赖**: 1.1.2
- **文件**: 
  - `src/skill/application/progressive_skill_loader.cj`
- **验收标准**:
  - [ ] 加载时自动执行门控检查
  - [ ] 不满足条件的技能被过滤
  - [ ] 记录过滤原因
- **状态**: 待集成
- **预估工时**: 2 天

### 1.2 文件即记忆系统 (P1)

#### 1.2.1 工作空间结构定义
- **任务**: 定义 Agent 工作空间目录结构
- **依赖**: MVP 完成
- **文件**: 
  - `src/memory/workspace/agent_workspace.cj` (新建)
- **验收标准**:
  - [ ] 定义 AGENTS.md 结构
  - [ ] 定义 SOUL.md 结构
  - [ ] 定义 TOOLS.md 结构
  - [ ] 定义 IDENTITY.md 结构
  - [ ] 定义 USER.md 结构
  - [ ] 定义 MEMORY.md 结构
  - [ ] 定义 HEARTBEAT.md 结构
- **状态**: 待开发
- **预估工时**: 2 天

#### 1.2.2 工作空间加载服务
- **任务**: 实现工作空间文件加载
- **依赖**: 1.2.1
- **文件**: 
  - `src/memory/workspace/workspace_loader.cj` (新建)
- **验收标准**:
  - [ ] 加载所有工作空间文件
  - [ ] 解析 Markdown 内容
  - [ ] 支持热重载
  - [ ] 文件变更监听
- **状态**: 待开发
- **预估工时**: 3 天

#### 1.2.3 记忆更新服务
- **任务**: 实现记忆文件的读写
- **依赖**: 1.2.2
- **文件**: 
  - `src/memory/workspace/memory_service.cj` (新建)
- **验收标准**:
  - [ ] 追加记忆内容
  - [ ] 压缩历史记忆
  - [ ] 支持记忆检索
- **状态**: 待开发
- **预估工时**: 2 天

### 1.3 Permission 系统 (P1) ✅ 已完成

#### 1.3.1 Capability 定义完善 ✅
- **任务**: 完善能力定义数据结构
- **依赖**: MVP 完成
- **文件**: 
  - `src/skill/domain/models/capability.cj`
- **验收标准**:
  - [x] 定义文件系统能力
  - [x] 定义网络能力
  - [x] 定义进程执行能力
  - [x] 定义环境变量能力
- **状态**: ✅ 已完善
- **完成日期**: 2026-02-22
- **预估工时**: 2 天
- **实现说明**:
  - 完善了 `SecurityPolicy` 数据结构，支持文件系统/网络/命令执行等权限配置
  - 完善了 `ResourceLimits` 数据结构，支持 CPU/内存/执行时间等资源限制
  - 完善了 `Capability` 数据结构，支持能力类型和参数

#### 1.3.2 权限检查服务 ✅
- **任务**: 实现权限检查逻辑
- **依赖**: 1.3.1
- **文件**: 
  - `src/security/permission_service.cj` (新建)
- **验收标准**:
  - [x] 检查技能请求的权限
  - [x] 与配置的权限对比
  - [x] 拒绝越权访问
  - [x] 记录权限审计日志
- **状态**: ✅ 已完成
- **完成日期**: 2026-02-22
- **预估工时**: 3 天
- **实现说明**:
  - 创建了 `PermissionService` 静态服务类
  - 实现了 `checkCapability()` 方法进行能力检查
  - 实现了 `checkResourceUsage()` 方法进行资源使用检查
  - 实现了 `checkExecutionTimeout()` 方法进行超时检查
  - 所有权限检查都有详细的审计日志记录

#### 1.3.3 沙箱执行环境完善 ✅
- **任务**: 完善沙箱执行实现
- **依赖**: 1.3.2
- **文件**: 
  - `src/security/sandbox_executor.cj` (新建)
- **验收标准**:
  - [x] 沙箱隔离执行
  - [x] 资源监控
  - [x] 超时处理
  - [x] 执行结果返回
- **状态**: ✅ 已完成
- **完成日期**: 2026-02-22
- **预估工时**: 5 天
- **实现说明**:
  - 创建了 `SandboxExecutor` 类，提供隔离执行环境
  - 创建了 `SandboxManager` 类，管理沙箱生命周期
  - 实现了执行时间记录和超时处理
  - 实现了资源监控（可扩展）
  - 提供了标准的执行结果格式

### 1.4 WebSocket 实时通信 (P1)

#### 1.4.1 WebSocket 服务端
- **任务**: 使用 stdx.net.http 实现 WebSocket 服务
- **依赖**: MVP 完成
- **文件**: 
  - `src/api/websocket_handler.cj` (已创建)
  - `src/api/api_router.cj` (已修改)
- **验收标准**:
  - [X] WebSocket 连接管理
  - [X] 消息广播
  - [X] 心跳检测
  - [X] 连接状态追踪
  - [X] 支持 chat 消息类型
  - [X] 支持 execute_skill 消息类型
  - [X] 支持 list_skills 消息类型
  - [X] 集成大模型 API 对接
- **状态**: 已完成
- **完成日期**: 2026-02-21
- **预估工时**: 3 天

#### 1.4.2 执行状态推送
- **任务**: 实现技能执行状态的实时推送
- **依赖**: 1.4.1
- **文件**: 
  - `src/api/websocket_handler.cj` (已实现)
- **验收标准**:
  - [X] 推送执行开始事件
  - [X] 推送执行进度事件
  - [X] 推送执行完成事件
  - [X] 推送错误事件
- **状态**: 已完成
- **完成日期**: 2026-02-21
- **预估工时**: 2 天

#### 1.4.3 前端聊天界面
- **任务**: 实现前端聊天界面集成
- **依赖**: 1.4.1
- **文件**: 
  - `apps/uctoo-app-client-pc/src/views/uctoo/chat/index.vue` (已创建)
  - `apps/uctoo-app-client-pc/src/router/routes/modules/chat.ts` (已创建)
- **验收标准**:
  - [X] WebSocket 客户端连接
  - [X] 消息发送和接收
  - [X] 技能列表展示
  - [X] 技能执行参数配置
  - [X] 执行结果展示
- **状态**: 已完成
- **完成日期**: 2026-02-21
- **预估工时**: 2 天

---

## 阶段 2: 生态建设

> 目标：建设技能生态，提供完善的开发体验

### 2.1 技能注册中心 (P1)

#### 2.1.1 PostgreSQL 数据模型
- **任务**: 设计技能元数据数据库模型
- **依赖**: 阶段 1 完成
- **文件**: 
  - `apps/backend/prisma/schema.prisma` (修改)
- **验收标准**:
  - [ ] 技能表设计
  - [ ] 版本表设计
  - [ ] 作者表设计
  - [ ] 安装统计表设计
- **状态**: 待开发
- **预估工时**: 2 天

#### 2.1.2 技能注册 API
- **任务**: 实现技能注册相关 API
- **依赖**: 2.1.1
- **文件**: 
  - `apps/backend/src/app/controllers/uctoo/agent_skills/` (修改)
- **验收标准**:
  - [ ] 技能注册 API
  - [ ] 技能更新 API
  - [ ] 技能删除 API
  - [ ] 技能搜索 API
- **状态**: 部分已实现
- **预估工时**: 2 天

#### 2.1.3 UMI 数据同步
- **任务**: 实现 UMI 分布式数据同步
- **依赖**: 2.1.2
- **文件**: 
  - `src/sync/umi_sync_engine.cj` (新建)
- **验收标准**:
  - [ ] 多节点数据同步
  - [ ] 冲突检测和解决
  - [ ] 离线支持
- **状态**: 待开发
- **预估工时**: 5 天

### 2.2 多语言 SDK (P1)

#### 2.2.1 JavaScript SDK 完善
- **任务**: 完善 JavaScript SDK
- **依赖**: 阶段 1 完成
- **文件**: 
  - `sdk/javascript/src/index.ts`
- **验收标准**:
  - [ ] 完整的 API 覆盖
  - [ ] TypeScript 类型定义
  - [ ] 错误处理
  - [ ] 文档完善
- **状态**: 已发布 @opencangjie/skills
- **预估工时**: 2 天

#### 2.2.2 Python SDK
- **任务**: 开发 Python SDK
- **依赖**: 2.2.1
- **文件**: 
  - `sdk/python/` (新建)
- **验收标准**:
  - [ ] pip 包发布
  - [ ] 完整的 API 覆盖
  - [ ] 类型提示
  - [ ] 文档完善
- **状态**: 待开发
- **预估工时**: 5 天

#### 2.2.3 Java SDK
- **任务**: 开发 Java SDK
- **依赖**: 2.2.1
- **文件**: 
  - `sdk/java/` (新建)
- **验收标准**:
  - [ ] Maven 包发布
  - [ ] 完整的 API 覆盖
  - [ ] 文档完善
- **状态**: 待开发
- **预估工时**: 5 天

### 2.3 CLI 工具完善 (P2)

#### 2.3.1 技能开发命令
- **任务**: 实现技能开发辅助命令
- **依赖**: 阶段 1 完成
- **文件**: 
  - `src/cli/skill_cli.cj`
- **验收标准**:
  - [ ] `skill init` - 初始化技能项目
  - [ ] `skill validate` - 验证技能
  - [ ] `skill test` - 测试技能
  - [ ] `skill pack` - 打包技能
- **状态**: 待开发
- **预估工时**: 3 天

#### 2.3.2 配置管理命令
- **任务**: 实现配置管理命令
- **依赖**: 2.3.1
- **文件**: 
  - `src/cli/config_cli.cj` (新建)
- **验收标准**:
  - [ ] `config set` - 设置配置
  - [ ] `config get` - 获取配置
  - [ ] `config list` - 列出配置
- **状态**: 待开发
- **预估工时**: 2 天

### 2.4 文档完善 (P2)

#### 2.4.1 API 文档
- **任务**: 编写完整的 API 文档
- **依赖**: 阶段 1 完成
- **文件**: 
  - `docs/api/` (新建)
- **验收标准**:
  - [ ] OpenAPI 规范
  - [ ] 请求/响应示例
  - [ ] 错误码说明
- **状态**: 待开发
- **预估工时**: 3 天

#### 2.4.2 开发指南
- **任务**: 编写技能开发指南
- **依赖**: 2.4.1
- **文件**: 
  - `docs/guides/` (新建)
- **验收标准**:
  - [ ] 快速开始指南
  - [ ] 技能开发教程
  - [ ] 最佳实践
  - [ ] 常见问题
- **状态**: 待开发
- **预估工时**: 5 天

---

## 阶段 3: 平台扩展

> 目标：扩展平台支持，实现多端覆盖

### 3.1 HarmonyOS 深度集成 (P2)

#### 3.1.1 HarmonyOS SDK
- **任务**: 开发 HarmonyOS 原生 SDK
- **依赖**: 阶段 2 完成
- **文件**: 
  - `sdk/harmonyos/` (新建)
- **验收标准**:
  - [ ] ohpm 包发布
  - [ ] ArkTS 类型定义
  - [ ] 原生技能执行
- **状态**: 待开发
- **预估工时**: 5 天

#### 3.1.2 鸿蒙应用集成
- **任务**: 将 runtime 集成到 uctooapp
- **依赖**: 3.1.1
- **文件**: 
  - `apps/uctooapp/` (修改)
- **验收标准**:
  - [ ] 技能管理界面
  - [ ] 技能执行界面
  - [ ] 本地技能缓存
- **状态**: 待开发
- **预估工时**: 5 天

### 3.2 小程序端集成 (P2)

#### 3.2.1 小程序 SDK
- **任务**: 开发小程序 SDK
- **依赖**: 阶段 2 完成
- **文件**: 
  - `sdk/miniapp/` (新建)
- **验收标准**:
  - [ ] npm 包发布
  - [ ] uni-app 兼容
  - [ ] 微信小程序支持
- **状态**: 待开发
- **预估工时**: 3 天

#### 3.2.2 小程序技能管理
- **任务**: 在小程序中集成技能管理
- **依赖**: 3.2.1
- **文件**: 
  - `apps/miniapp/src/pages/uctoo/agent_skills/` (修改)
- **验收标准**:
  - [ ] 技能列表页面
  - [ ] 技能详情页面
  - [ ] 技能执行页面
- **状态**: 待开发
- **预估工时**: 5 天

### 3.3 iOS/Android 支持 (P3)

#### 3.3.1 React Native SDK
- **任务**: 开发 React Native SDK
- **依赖**: 阶段 2 完成
- **文件**: 
  - `sdk/react-native/` (新建)
- **验收标准**:
  - [ ] npm 包发布
  - [ ] iOS 支持
  - [ ] Android 支持
- **状态**: 待开发
- **预估工时**: 5 天

#### 3.3.2 原生移动应用
- **任务**: 开发原生移动应用
- **依赖**: 3.3.1
- **文件**: 
  - `apps/mobile/` (新建)
- **验收标准**:
  - [ ] iOS 应用
  - [ ] Android 应用
  - [ ] 技能管理功能
- **状态**: 待开发
- **预估工时**: 10 天

### 3.4 多渠道接入 (P3)

#### 3.4.1 消息渠道抽象
- **任务**: 设计消息渠道抽象层
- **依赖**: 阶段 2 完成
- **文件**: 
  - `src/channel/` (新建)
- **验收标准**:
  - [ ] 渠道接口定义
  - [ ] 消息格式转换
  - [ ] 事件处理
- **状态**: 待开发
- **预估工时**: 3 天

#### 3.4.2 微信渠道
- **任务**: 实现微信渠道接入
- **依赖**: 3.4.1
- **文件**: 
  - `src/channel/wechat/` (新建)
- **验收标准**:
  - [ ] 微信公众号接入
  - [ ] 微信小程序接入
  - [ ] 消息收发
- **状态**: 待开发
- **预估工时**: 5 天

#### 3.4.3 钉钉/飞书渠道
- **任务**: 实现企业通讯渠道接入
- **依赖**: 3.4.1
- **文件**: 
  - `src/channel/dingtalk/` (新建)
  - `src/channel/feishu/` (新建)
- **验收标准**:
  - [ ] 钉钉机器人接入
  - [ ] 飞书机器人接入
  - [ ] 消息收发
- **状态**: 待开发
- **预估工时**: 5 天

---

## 阶段 4: 操作系统集成

> 目标：实现操作系统级集成，提供原生体验

### 4.1 原生服务 (P3)

#### 4.1.1 系统服务封装
- **任务**: 将 runtime 封装为系统服务
- **依赖**: 阶段 3 完成
- **文件**: 
  - `service/` (新建)
- **验收标准**:
  - [ ] Windows 服务
  - [ ] Linux systemd 服务
  - [ ] macOS launchd 服务
- **状态**: 待开发
- **预估工时**: 5 天

#### 4.1.2 开机自启动
- **任务**: 实现开机自启动功能
- **依赖**: 4.1.1
- **文件**: 
  - `service/` (修改)
- **验收标准**:
  - [ ] Windows 注册表配置
  - [ ] Linux systemd 配置
  - [ ] macOS LaunchAgent 配置
- **状态**: 待开发
- **预估工时**: 2 天

### 4.2 硬件加速 (P3)

#### 4.2.1 GPU 加速
- **任务**: 实现 GPU 加速推理
- **依赖**: 4.1
- **文件**: 
  - `src/acceleration/gpu.cj` (新建)
- **验收标准**:
  - [ ] CUDA 支持
  - [ ] Metal 支持
  - [ ] OpenCL 支持
- **状态**: 待开发
- **预估工时**: 10 天

#### 4.2.2 NPU 支持
- **任务**: 实现 NPU 加速
- **依赖**: 4.2.1
- **文件**: 
  - `src/acceleration/npu.cj` (新建)
- **验收标准**:
  - [ ] 华为 NPU 支持
  - [ ] 苹果 Neural Engine 支持
- **状态**: 待开发
- **预估工时**: 10 天

### 4.3 安全沙箱 (P3)

#### 4.3.1 容器隔离
- **任务**: 实现容器级隔离
- **依赖**: 4.1
- **文件**: 
  - `src/security/container.cj` (新建)
- **验收标准**:
  - [ ] Docker 集成
  - [ ] 资源限制
  - [ ] 网络隔离
- **状态**: 待开发
- **预估工时**: 5 天

#### 4.3.2 SELinux/AppArmor 集成
- **任务**: 实现操作系统级安全策略
- **依赖**: 4.3.1
- **文件**: 
  - `src/security/selinux.cj` (新建)
- **验收标准**:
  - [ ] SELinux 策略
  - [ ] AppArmor 配置
  - [ ] 安全审计
- **状态**: 待开发
- **预估工时**: 5 天

### 4.4 分布式执行 (P3)

#### 4.4.1 节点发现
- **任务**: 实现分布式节点发现
- **依赖**: 4.1
- **文件**: 
  - `src/distributed/discovery.cj` (新建)
- **验收标准**:
  - [ ] mDNS 发现
  - [ ] 手动配置
  - [ ] 节点状态同步
- **状态**: 待开发
- **预估工时**: 5 天

#### 4.4.2 任务调度
- **任务**: 实现分布式任务调度
- **依赖**: 4.4.1
- **文件**: 
  - `src/distributed/scheduler.cj` (新建)
- **验收标准**:
  - [ ] 任务分发
  - [ ] 负载均衡
  - [ ] 故障转移
- **状态**: 待开发
- **预估工时**: 10 天

---

## 里程碑

| 里程碑 | 目标日期 | 关键交付物 | 状态 |
|--------|----------|------------|------|
| M-历史: 基础框架 | 2026-02-21 | CLI、API、SDK、安全框架 | ✅ 已完成 |
| M0: MVP | 2026-03-31 | 可运行的技能执行系统 | ✅ 进行中（核心功能已完成） |
| M1: 核心能力 | 2026-06-30 | 门控、记忆、权限、WebSocket | ✅ 部分已完成（WebSocket已完成） |
| M2: 生态建设 | 2026-09-30 | 注册中心、多语言 SDK、文档 | 待开始 |
| M3: 平台扩展 | 2026-12-31 | HarmonyOS、小程序、移动端 | 待开始 |
| M4: 系统集成 | 2027-03-31 | 原生服务、硬件加速、分布式 | 待开始 |

---

## 风险与依赖

### 技术风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 仓颉语言生态不成熟 | 中 | 复用 CangjieMagic 已有实现 |
| WASM 沙箱性能 | 中 | 渐进式增强，先实现基础功能 |
| 多平台兼容性 | 高 | 优先支持主流平台 |

### 外部依赖

| 依赖 | 状态 | 备注 |
|------|------|------|
| 仓颉编译器 | ✅ 可用 | cjpm 工具链 |
| stdx.net.http | ✅ 可用 | WebSocket 支持 |
| CangjieMagic 框架 | ✅ 可用 | 基础设施复用 |
| Backend 服务 | ✅ 可用 | API 服务 |
| PostgreSQL | ✅ 可用 | 数据存储 |

---

## 附录：可复用的仓颉生态第三方库

> 以下库来自 `apps/CangjieMagic/resource/TPC` 目录，可在开发中复用。

### 已集成使用的库

| 库名 | 版本 | 用途 | 项目依赖状态 |
|------|------|------|-------------|
| yaml4cj | 1.0.x | YAML 解析（SKILL.md frontmatter） | ✅ 已集成 |
| commonmark4cj | 1.0.x | Markdown 解析（SKILL.md 内容） | ✅ 已集成 |

### 推荐复用的库（按功能分类）

#### 1. 安全与认证

| 库名 | 版本 | 功能说明 | 适用场景 |
|------|------|----------|----------|
| jwt4cj | 1.0.1 | JWT 创建、解析、验证，支持 HMAC/RSA/ECDSA | API 认证、技能执行授权 |
| oauth4cj | 0.0.1 | OAuth 1.0/2.0 协议支持 | 第三方服务集成 |
| pkcs4cj | 1.0.x | PKCS 加密标准 | 安全通信 |
| pbkdf2 | 1.0.x | 密钥派生函数 | 密码安全 |

#### 2. 数据存储与缓存

| 库名 | 版本 | 功能说明 | 适用场景 |
|------|------|----------|----------|
| redis-sdk | 3.0.0 | Redis 客户端，支持 RESP2/RESP3 | 技能缓存、会话管理 |
| kv4cj | 1.0.3 | MMKV 高性能 KV 存储 | 本地配置、状态持久化 |
| odbc4cj | 1.0.x | ODBC 数据库连接 | 数据库技能 |

#### 3. 网络与通信

| 库名 | 版本 | 功能说明 | 适用场景 |
|------|------|----------|----------|
| mqtt4cj | 1.0.3 | MQTT 协议客户端 | IoT 技能、消息推送 |
| net4cj | 0.0.1 | 网络协议客户端（FTP/SMTP/Telnet等） | 网络技能 |
| rpc4cj | 1.0.1 | gRPC 框架，基于 HTTP/2 + Protobuf | 微服务通信 |

#### 4. 数据格式处理

| 库名 | 版本 | 功能说明 | 适用场景 |
|------|------|----------|----------|
| csv4cj | 1.0.4 | CSV 文件读写解析 | 数据处理技能 |
| cbor4cj | 1.0.1 | CBOR 二进制数据格式 | 高效数据序列化 |
| html4cj | 1.0.3 | HTML 解析，支持 CSS 选择器 | 网页抓取技能 |
| ini4cj | 1.0.x | INI 配置文件解析 | 配置管理 |

#### 5. 日志与监控

| 库名 | 版本 | 功能说明 | 适用场景 |
|------|------|----------|----------|
| log-cj | 1.0.2 | 日志打印，支持控制台和文件输出 | 统一日志系统 |

#### 6. 加密与编码

| 库名 | 版本 | 功能说明 | 适用场景 |
|------|------|----------|----------|
| md5-cj | 1.0.x | MD5 哈希 | 文件校验 |
| base64-cj | 1.0.x | Base64 编解码 | 数据编码 |
| mime4cj | 1.0.x | MIME 类型处理 | 文件处理 |

#### 7. IO 与流处理

| 库名 | 版本 | 功能说明 | 适用场景 |
|------|------|----------|----------|
| io4cj | 1.0.2 | Okio 风格的 IO 库，支持 buffer/gzip/deflate | 高效 IO 操作 |

#### 8. 云服务 SDK

| 库名 | 版本 | 功能说明 | 适用场景 |
|------|------|----------|----------|
| oss-sdk | 1.0.x | 阿里云 OSS SDK | 对象存储技能 |
| apm_sdk | 1.0.x | 应用性能监控 | 性能监控 |

### 集成建议

1. **API 认证增强**: 集成 `jwt4cj` 替代或增强现有认证机制
2. **缓存优化**: 集成 `redis-sdk` 用于技能执行结果缓存
3. **日志统一**: 考虑集成 `log-cj` 统一日志格式（JSON 格式输出）
4. **配置管理**: 使用 `kv4cj` 替代简单的文件配置存储
5. **网络技能**: 复用 `net4cj`、`mqtt4cj` 实现网络相关技能

### 依赖添加方式

在 `apps/agentskills-runtime/cjpm.toml` 中添加：

```toml
[dependencies]
  yaml4cj = { path = "./libs/yaml4cj" }
  commonmark4cj = { path = "./libs/commonmark4cj" }
  # 如需添加其他库，复制 TPC 目录中的库到 libs/ 目录
  # jwt4cj = { path = "./libs/jwt4cj" }
  # redis_sdk = { git = "https://gitcode.com/Cangjie-TPC/redis-sdk.git", branch = "master", version = "3.0.0" }
```

---

## 附录：已有基础设施

### 可复用的模块

| 模块 | 路径 | 说明 | 状态 |
|------|------|------|------|
| SkillManager | `src/core/skill/skill_manager.cj` | 技能管理器 | ✅ |
| ToolManager | `src/core/tool/tool_manager.cj` | 工具管理器 | ✅ |
| CompositeSkillToolManager | `src/skill/composite_skill_tool_manager.cj` | 统一管理器 | ✅ |
| SkillToToolAdapter | `src/skill/skill_to_tool_adapter.cj` | 技能-工具适配器 | ✅ |
| ProgressiveSkillLoader | `src/skill/application/progressive_skill_loader.cj` | 渐进式加载器 | ✅ |
| ReactExecutor | `src/agent_executor/react/react_executor.cj` | ReAct 执行器 | ✅ |
| PlanReactExecutor | `src/agent_executor/plan_react/plan_react_executor.cj` | 规划执行器 | ✅ |
| Memory | `src/core/memory/memory.cj` | 记忆系统 | ✅ |
| ChatModel | `src/core/model/chat_model.cj` | 聊天模型 | ✅ |
| PublicSkillSearch | `src/skill/search/public_skill_search.cj` | 公网搜索 | ✅ |
| SkillPackageManager | `src/skill/application/skill_package_manager.cj` | 技能包管理 | ✅ |
| SkillExecutionEngine | `src/skill/skill_execution_engine.cj` | 技能执行引擎 | 🔄 待完善 |
| WASMSandbox | `src/skill/security/wasm_sandbox.cj` | WASM 沙箱 | 🔄 待完善 |

### 已有的前端界面

| 应用 | 路径 | 说明 | 状态 |
|------|------|------|------|
| PC 管理端 | `apps/uctoo-app-client-pc/` | Vue 3 + Ant Design | ✅ |
| 鸿蒙应用 | `apps/uctooapp/` | ArkTS 原生应用 | ✅ |
| 小程序 | `apps/miniapp/` | uni-app 跨平台 | ✅ |

### 已发布的包

| 包名 | 平台 | 版本 | 状态 |
|------|------|------|------|
| @opencangjie/skills | npm | 1.0.2 | ✅ 已发布 |
| agentskills-runtime | AtomGit | 1.0.2 | ✅ 已发布 |

---

**文档维护**: 请在完成任务后更新状态，添加实际工时和遇到的问题。
