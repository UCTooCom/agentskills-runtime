# UCToo V4 基于Agent Skills的AI原生代码生成引擎设计方案

**文档版本**: 1.0.0  
**创建日期**: 2026-03-16  
**目标**: 基于agentskills开放标准设计轻量级AI原生代码生成引擎

---

## 一、方案背景与目标

### 1.1 设计理念

**核心理念**: 代码生成是开发环境功能,不应集成到运行时内核中

**关键决策**:
- ✅ 使用Agent Skills方案实现代码生成
- ✅ 保持agentskills-runtime内核轻量级
- ✅ 代码生成功能仅在开发环境使用
- ✅ 复用V3 backend和Prisma生态基础设施

**优势**:
- 🎯 运行时零开销
- 🎯 开发环境功能独立
- 🎯 易于维护和升级
- 🎯 可复用现有生态

### 1.2 Agent Skills开放标准

**Skill结构**:
```
skill-name/
├── SKILL.md (必需)
│   ├── YAML frontmatter (name, description)
│   └── Markdown指令
└── Bundled Resources (可选)
    ├── scripts/    - 可执行脚本(TypeScript/Python)
    ├── references/ - 参考文档
    └── assets/     - 模板文件
```

**三级加载机制**:
1. **Metadata** (name + description) - 始终在上下文中 (~100字)
2. **SKILL.md body** - skill触发时加载 (<500行)
3. **Bundled resources** - 按需加载 (无限制)

---

## 二、整体架构设计

### 2.1 架构概览

```
┌─────────────────────────────────────────────────────────┐
│              UCToo V4 代码生成系统                        │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │         crud-generator Skill (Agent Skill)        │  │
│  ├──────────────────────────────────────────────────┤  │
│  │  SKILL.md - AI指令和生成流程                      │  │
│  │  scripts/ - TypeScript生成器脚本                 │  │
│  │  references/ - Prisma schema和模板参考            │  │
│  │  assets/ - 代码模板文件                           │  │
│  └──────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │         复用的基础设施                            │  │
│  ├──────────────────────────────────────────────────┤  │
│  │  Prisma ORM - Schema分析和类型生成               │  │
│  │  V3 Backend - 模板文件和生成逻辑                 │  │
│  │  TypeScript - 生成器脚本语言                     │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### 2.2 核心组件

#### 2.2.1 crud-generator Skill

**功能**: 生成标准的CRUD模块代码

**目录结构**:
```
crud-generator/
├── SKILL.md                          # Skill主文件
├── scripts/
│   ├── generate-crud.ts             # 主生成器脚本
│   ├── schema-analyzer.ts           # Schema分析器
│   ├── template-engine.ts           # 模板引擎
│   ├── code-optimizer.ts            # AI代码优化器
│   └── utils.ts                     # 工具函数
├── references/
│   ├── prisma-schema-guide.md       # Prisma Schema指南
│   ├── uctoo-api-spec.md            # UCToo API规范
│   └── code-templates-guide.md      # 代码模板指南
└── assets/
    ├── templates/
    │   ├── model.cj.tpl             # Model模板
    │   ├── service.cj.tpl           # Service模板
    │   ├── controller.cj.tpl        # Controller模板
    │   └── route.cj.tpl             # Route模板
    └── examples/
        └── agent_skills_example/    # 示例模块
```

---

## 三、SKILL.md设计

### 3.1 YAML Frontmatter

```yaml
---
name: crud-generator
description: Generate standard CRUD modules for UCToo V4. Use this skill when the user wants to create a new CRUD module, scaffold database entities, or generate boilerplate code for database operations. The skill analyzes Prisma schema, generates type-safe Model, Service, Controller, and Route files, and applies AI-driven optimizations. Trigger when user mentions "generate CRUD", "create module", "scaffold entity", "code generation", or asks to create database operations for a table.
---
```

### 3.2 核心指令

```markdown
# CRUD Generator Skill

Generate standard CRUD modules for UCToo V4 with AI-driven optimizations.

## When to Use

Use this skill when:
- User wants to create a new CRUD module
- User needs to scaffold database entities
- User asks to generate boilerplate code for database operations
- User mentions "generate CRUD", "create module", "scaffold entity"

## Generation Workflow

### Step 1: Gather Requirements

Ask the user for:
1. **Table name** - The database table to generate code for
2. **Database name** - Default is "uctoo"
3. **Module options**:
   - Require authentication? (default: true)
   - Enable caching? (default: false)
   - Generate tests? (default: true)
   - AI optimization level? (none/basic/advanced)

### Step 2: Analyze Schema

1. **Locate Prisma schema**:
   - Check `prisma/{database}/schema.prisma`
   - Or ask user for schema file path

2. **Run schema analyzer**:
   ```bash
   npx ts-node scripts/schema-analyzer.ts \
     --table {table_name} \
     --database {database_name} \
     --output analysis.json
   ```

3. **Review analysis results**:
   - Field types and constraints
   - Relations and indexes
   - Primary keys and foreign keys

### Step 3: Generate Code

1. **Run main generator**:
   ```bash
   npx ts-node scripts/generate-crud.ts \
     --table {table_name} \
     --database {database_name} \
     --options {options_json} \
     --output {output_dir}
   ```

2. **Generated files**:
   - `models/{database}/{TableName}PO.cj`
   - `services/{database}/{TableName}Service.cj`
   - `controllers/{database}/{table_name}/{TableName}Controller.cj`
   - `routes/{database}/{table_name}/{TableName}Route.cj`
   - `tests/{database}/{table_name}/{TableName}Test.cj` (if enabled)

### Step 4: AI Optimization (Optional)

If AI optimization is enabled:

1. **Performance optimization**:
   - Detect N+1 query patterns
   - Suggest caching strategies
   - Optimize database queries

2. **Security optimization**:
   - Check for SQL injection risks
   - Validate input sanitization
   - Add permission checks

3. **Code quality**:
   - Remove code duplication
   - Improve naming conventions
   - Add documentation

### Step 5: Review and Apply

1. **Show generated code** to user
2. **Explain key decisions**:
   - Type mappings
   - Permission setup
   - Caching strategy
3. **Apply changes** on user confirmation

## Code Templates

### Model Template (model.cj.tpl)

Read from `assets/templates/model.cj.tpl`:
- Uses fountain ORM annotations
- Type-safe field definitions
- Includes helper methods

### Service Template (service.cj.tpl)

Read from `assets/templates/service.cj.tpl`:
- CRUD operations (Create, Read, Update, Delete)
- Pagination support
- Caching integration
- Permission checks

### Controller Template (controller.cj.tpl)

Read from `assets/templates/controller.cj.tpl`:
- RESTful API endpoints
- Request validation
- Response formatting
- Error handling

### Route Template (route.cj.tpl)

Read from `assets/templates/route.cj.tpl`:
- Route registration
- Middleware configuration
- Permission setup

## Integration with V3 Backend

### Reusable Components

1. **Prisma Schema Analysis**:
   - Reuse V3's `loadDbInfo` logic
   - Leverage Prisma's introspection

2. **Template Files**:
   - Adapt V3's `.tpl` files to Cangjie
   - Maintain same generation logic

3. **Type Conversions**:
   - Reuse V3's `typeConversion` function
   - Map SQL types to Cangjie types

### Migration Path

1. **Phase 1**: Use V3 backend for schema analysis
2. **Phase 2**: Port TypeScript scripts to Cangjie
3. **Phase 3**: Full Cangjie implementation

## Example Usage

**User**: "Generate CRUD for agent_skills table"

**Your response**:
1. Ask for database name (default: uctoo)
2. Ask for options (auth, cache, tests)
3. Run schema analyzer
4. Generate code
5. Show generated files
6. Apply on confirmation

## Error Handling

- **Schema not found**: Ask user for schema path
- **Table not found**: List available tables
- **Type mapping error**: Suggest manual override
- **Generation failure**: Show detailed error and suggest fixes

## Best Practices

1. **Always validate schema** before generation
2. **Show preview** before applying changes
3. **Generate tests** for quality assurance
4. **Use AI optimization** for better code quality
5. **Follow UCToo API specification** strictly
```

---

## 四、生成器脚本设计

### 4.1 主生成器脚本 (generate-crud.ts)

```typescript
// scripts/generate-crud.ts
import { Command } from 'commander';
import { SchemaAnalyzer } from './schema-analyzer';
import { TemplateEngine } from './template-engine';
import { CodeOptimizer } from './code-optimizer';
import * as fs from 'fs';
import * as path from 'path';

interface GeneratorOptions {
  table: string;
  database: string;
  output: string;
  requireAuth: boolean;
  enableCache: boolean;
  generateTests: boolean;
  aiOptimization: 'none' | 'basic' | 'advanced';
}

export class CRUDGenerator {
  private schemaAnalyzer: SchemaAnalyzer;
  private templateEngine: TemplateEngine;
  private codeOptimizer: CodeOptimizer;

  constructor() {
    this.schemaAnalyzer = new SchemaAnalyzer();
    this.templateEngine = new TemplateEngine();
    this.codeOptimizer = new CodeOptimizer();
  }

  async generate(options: GeneratorOptions): Promise<void> {
    console.log(`🚀 Generating CRUD module for ${options.table}...`);

    // 1. 分析Schema
    const schema = await this.schemaAnalyzer.analyze(
      options.table,
      options.database
    );

    // 2. 生成代码
    const generatedCode = {
      model: this.templateEngine.render('model', schema, options),
      service: this.templateEngine.render('service', schema, options),
      controller: this.templateEngine.render('controller', schema, options),
      route: this.templateEngine.render('route', schema, options),
    };

    // 3. AI优化
    if (options.aiOptimization !== 'none') {
      generatedCode.model = await this.codeOptimizer.optimize(
        generatedCode.model,
        'model',
        options.aiOptimization
      );
      generatedCode.service = await this.codeOptimizer.optimize(
        generatedCode.service,
        'service',
        options.aiOptimization
      );
    }

    // 4. 写入文件
    await this.writeFiles(generatedCode, options);

    // 5. 生成测试
    if (options.generateTests) {
      await this.generateTests(schema, options);
    }

    console.log(`✅ CRUD module generated successfully!`);
  }

  private async writeFiles(
    code: any,
    options: GeneratorOptions
  ): Promise<void> {
    const baseDir = options.output;

    // Model
    const modelDir = path.join(baseDir, 'models', options.database);
    await fs.promises.mkdir(modelDir, { recursive: true });
    await fs.promises.writeFile(
      path.join(modelDir, `${this.toPascalCase(options.table)}PO.cj`),
      code.model
    );

    // Service
    const serviceDir = path.join(baseDir, 'services', options.database);
    await fs.promises.mkdir(serviceDir, { recursive: true });
    await fs.promises.writeFile(
      path.join(serviceDir, `${this.toPascalCase(options.table)}Service.cj`),
      code.service
    );

    // Controller
    const controllerDir = path.join(
      baseDir,
      'controllers',
      options.database,
      options.table
    );
    await fs.promises.mkdir(controllerDir, { recursive: true });
    await fs.promises.writeFile(
      path.join(controllerDir, `${this.toPascalCase(options.table)}Controller.cj`),
      code.controller
    );

    // Route
    const routeDir = path.join(
      baseDir,
      'routes',
      options.database,
      options.table
    );
    await fs.promises.mkdir(routeDir, { recursive: true });
    await fs.promises.writeFile(
      path.join(routeDir, `${this.toPascalCase(options.table)}Route.cj`),
      code.route
    );
  }

  private toPascalCase(str: string): string {
    return str
      .split('_')
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join('');
  }
}

// CLI入口
const program = new Command();
program
  .option('-t, --table <name>', 'Table name')
  .option('-d, --database <name>', 'Database name', 'uctoo')
  .option('-o, --output <dir>', 'Output directory', './src/app')
  .option('--require-auth', 'Require authentication', true)
  .option('--enable-cache', 'Enable caching', false)
  .option('--generate-tests', 'Generate tests', true)
  .option(
    '--ai-optimization <level>',
    'AI optimization level (none/basic/advanced)',
    'basic'
  )
  .parse(process.argv);

const generator = new CRUDGenerator();
generator.generate(program.opts());
```

### 4.2 Schema分析器 (schema-analyzer.ts)

```typescript
// scripts/schema-analyzer.ts
import { PrismaClient } from '@prisma/client';
import * as fs from 'fs';

interface FieldSchema {
  name: string;
  type: string;
  isNullable: boolean;
  isPrimaryKey: boolean;
  isForeignKey: boolean;
  defaultValue?: any;
  relation?: {
    table: string;
    field: string;
  };
}

interface TableSchema {
  tableName: string;
  database: string;
  fields: FieldSchema[];
  relations: any[];
  indexes: any[];
}

export class SchemaAnalyzer {
  private prisma: PrismaClient;

  constructor() {
    this.prisma = new PrismaClient();
  }

  async analyze(tableName: string, database: string): Promise<TableSchema> {
    // 1. 从Prisma schema读取表结构
    const schemaPath = `prisma/${database}/schema.prisma`;
    const schemaContent = await fs.promises.readFile(schemaPath, 'utf-8');

    // 2. 解析字段
    const fields = await this.parseFields(tableName, schemaContent);

    // 3. 分析关系
    const relations = await this.parseRelations(tableName, schemaContent);

    // 4. 获取索引
    const indexes = await this.getIndexes(tableName);

    return {
      tableName,
      database,
      fields,
      relations,
      indexes,
    };
  }

  private async parseFields(
    tableName: string,
    schemaContent: string
  ): Promise<FieldSchema[]> {
    // 复用V3 backend的loadDbInfo逻辑
    const fields = await this.prisma.db_info.findMany({
      where: { table_name: tableName },
      orderBy: { ordinal_position: 'asc' },
    });

    return fields.map((field) => ({
      name: field.column_name,
      type: this.mapType(field.data_type),
      isNullable: field.is_nullable === 'YES',
      isPrimaryKey: field.column_key === 'PRI',
      isForeignKey: field.column_key === 'MUL',
      defaultValue: field.column_default,
    }));
  }

  private mapType(dbType: string): string {
    // 复用V3 backend的typeConversion逻辑
    const typeMap: Record<string, string> = {
      integer: 'Int32',
      bigint: 'Int64',
      varchar: 'String',
      text: 'String',
      timestamp: 'DateTime',
      datetime: 'DateTime',
      boolean: 'Bool',
      float: 'Float64',
      double: 'Float64',
      uuid: 'String',
      json: 'String',
    };

    return typeMap[dbType.toLowerCase()] || 'String';
  }

  private async parseRelations(
    tableName: string,
    schemaContent: string
  ): Promise<any[]> {
    // 解析Prisma schema中的关系
    // TODO: 实现关系解析逻辑
    return [];
  }

  private async getIndexes(tableName: string): Promise<any[]> {
    // 获取表索引信息
    // TODO: 实现索引查询逻辑
    return [];
  }
}
```

### 4.3 模板引擎 (template-engine.ts)

```typescript
// scripts/template-engine.ts
import * as fs from 'fs';
import * as path from 'path';
import * as ejs from 'ejs';

export class TemplateEngine {
  private templateDir: string;

  constructor() {
    this.templateDir = path.join(__dirname, '../assets/templates');
  }

  render(
    templateName: string,
    schema: any,
    options: any
  ): string {
    const templatePath = path.join(
      this.templateDir,
      `${templateName}.cj.tpl`
    );
    const templateContent = fs.readFileSync(templatePath, 'utf-8');

    // 使用EJS模板引擎
    return ejs.render(templateContent, {
      schema,
      options,
      helpers: {
        toPascalCase: this.toPascalCase,
        toCamelCase: this.toCamelCase,
        toSnakeCase: this.toSnakeCase,
      },
    });
  }

  private toPascalCase(str: string): string {
    return str
      .split('_')
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join('');
  }

  private toCamelCase(str: string): string {
    const pascal = this.toPascalCase(str);
    return pascal.charAt(0).toLowerCase() + pascal.slice(1);
  }

  private toSnakeCase(str: string): string {
    return str.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`);
  }
}
```

### 4.4 AI代码优化器 (code-optimizer.ts)

```typescript
// scripts/code-optimizer.ts
import axios from 'axios';

export class CodeOptimizer {
  private aiEndpoint: string;

  constructor() {
    this.aiEndpoint = process.env.AI_OPTIMIZER_ENDPOINT || 'http://localhost:8080/optimize';
  }

  async optimize(
    code: string,
    type: 'model' | 'service' | 'controller' | 'route',
    level: 'basic' | 'advanced'
  ): Promise<string> {
    if (level === 'none') {
      return code;
    }

    try {
      const response = await axios.post(this.aiEndpoint, {
        code,
        type,
        level,
        language: 'cangjie',
      });

      return response.data.optimizedCode;
    } catch (error) {
      console.error('AI optimization failed, returning original code');
      return code;
    }
  }
}
```

---

## 五、代码模板设计

### 5.1 Model模板 (model.cj.tpl)

```cj
package magic.app.models.<%= schema.database %>

import f_orm.*
import f_orm.macros.*
import std.datetime.DateTime

@TableName("<%= schema.tableName %>")
public class <%= helpers.toPascalCase(schema.tableName) %>PO <: Entity {
<%_ schema.fields.forEach(function(field) { _%>
    @Column(name: "<%= field.name %>"<% if (field.isPrimaryKey) { %>, isPrimaryKey = true, isGenerated = true<% } %><% if (field.isNullable) { %>)
    public var <%= helpers.toCamelCase(field.name) %>: ?<%= field.type %> = None<<%= field.type %>>
<% } else { %>)
    public var <%= helpers.toCamelCase(field.name) %>: <%= field.type %> = <%= field.type === 'String' ? '""' : (field.type === 'Int32' ? '0' : (field.type === 'Bool' ? 'false' : 'DateTime.now()')) %>
<% } _%>
<%_ }); _%>
    
    public init() {}
}
```

### 5.2 Service模板 (service.cj.tpl)

```cj
package magic.app.services.<%= schema.database %>

import magic.app.models.<%= schema.database %>.<%= helpers.toPascalCase(schema.tableName) %>PO
import f_orm.*
import std.datetime.DateTime

public class <%= helpers.toPascalCase(schema.tableName) %>Service {
    private let db: Database
    
    public init(db: Database) {
        this.db = db
    }
    
    // Create
    public func create(data: <%= helpers.toPascalCase(schema.tableName) %>PO): ?<%= helpers.toPascalCase(schema.tableName) %>PO {
        try {
            data.createdAt = DateTime.now()
            data.updatedAt = DateTime.now()
            return db.insert(data)
        } catch {
            return None<<%= helpers.toPascalCase(schema.tableName) %>PO>
        }
    }
    
    // Read by ID
    public func findById(id: String): ?<%= helpers.toPascalCase(schema.tableName) %>PO {
        return db.findById<<%= helpers.toPascalCase(schema.tableName) %>PO>(id)
    }
    
    // Read with pagination
    public func findWithPagination(limit: Int32, offset: Int32): Array<<%= helpers.toPascalCase(schema.tableName) %>PO> {
        return db.findMany<<%= helpers.toPascalCase(schema.tableName) %>PO>(
            where: { "status": 1 },
            orderBy: { "created_at": "desc" },
            limit: limit,
            offset: offset
        )
    }
    
    // Update
    public func update(id: String, data: <%= helpers.toPascalCase(schema.tableName) %>PO): Bool {
        try {
            data.updatedAt = DateTime.now()
            db.update<<%= helpers.toPascalCase(schema.tableName) %>PO>(id, data)
            return true
        } catch {
            return false
        }
    }
    
    // Delete
    public func delete(id: String): Bool {
        try {
            db.delete<<%= helpers.toPascalCase(schema.tableName) %>PO>(id)
            return true
        } catch {
            return false
        }
    }
}
```

---

## 六、与V3 Backend集成

### 6.1 复用V3基础设施

**1. Prisma Schema分析**:
- 复用 `loadDbInfo` 逻辑
- 使用Prisma introspection功能
- 保持与V3相同的schema分析能力

**2. 模板文件**:
- 将V3的 `.tpl` 文件转换为Cangjie模板
- 保持相同的生成逻辑
- 适配仓颉语法

**3. 类型转换**:
- 复用 `typeConversion` 函数
- 映射SQL类型到Cangjie类型
- 保持类型安全

### 6.2 迁移路径

**阶段一: TypeScript脚本 (当前)**:
- 使用TypeScript编写生成器脚本
- 复用V3 backend的基础设施
- 通过Node.js执行

**阶段二: 混合模式**:
- 部分脚本迁移到Cangjie
- 保持TypeScript作为主要生成器
- 逐步替换关键组件

**阶段三: 完全Cangjie**:
- 所有脚本使用Cangjie编写
- 完全独立于V3 backend
- 原生仓颉生态

---

## 七、使用示例

### 7.1 基本使用

**用户**: "Generate CRUD for agent_skills table"

**AI响应**:
```
我将为 agent_skills 表生成CRUD模块。

请确认以下选项:
- 数据库: uctoo (默认)
- 需要认证: 是
- 启用缓存: 否
- 生成测试: 是
- AI优化级别: basic

确认后我将:
1. 分析Prisma schema
2. 生成Model, Service, Controller, Route文件
3. 应用AI优化
4. 显示生成的代码供您审查
```

### 7.2 高级使用

**用户**: "Generate CRUD for agent_skills with advanced AI optimization and caching"

**AI响应**:
```
我将为 agent_skills 表生成CRUD模块,启用高级AI优化和缓存。

正在执行:
1. ✅ 分析Prisma schema
2. ✅ 生成基础代码
3. 🔄 应用高级AI优化...
   - 性能优化: 检测到N+1查询风险,已添加预加载
   - 安全优化: 添加了输入验证和权限检查
   - 代码质量: 优化了命名和结构
4. ✅ 生成完成

生成的文件:
- models/uctoo/AgentSkillsPO.cj
- services/uctoo/AgentSkillsService.cj
- controllers/uctoo/agent_skills/AgentSkillsController.cj
- routes/uctoo/agent_skills/AgentSkillsRoute.cj
- tests/uctoo/agent_skills/AgentSkillsTest.cj

是否应用这些更改?
```

---

## 八、优势总结

### 8.1 相比V3模板替换方案

| 维度 | V3 模板替换 | V4 Agent Skills方案 |
|-----|-----------|-------------------|
| **运行时开销** | 无 | 无 |
| **开发环境集成** | 独立脚本 | Agent Skill集成 |
| **AI优化** | 无 | 支持多级优化 |
| **可维护性** | 中等 | 高(模块化) |
| **扩展性** | 低 | 高(Skill生态) |
| **复用性** | 低 | 高(复用V3生态) |

### 8.2 相比仓颉原生方案

| 维度 | 仓颉原生方案 | Agent Skills方案 |
|-----|------------|----------------|
| **运行时开销** | 有(元编程) | 无 |
| **内核复杂度** | 高 | 低 |
| **开发效率** | 中等 | 高 |
| **生态复用** | 低 | 高 |
| **维护成本** | 高 | 低 |

---

## 九、实施计划

### 9.1 阶段划分

**阶段一: 基础Skill实现 (1-2周)**:
- [ ] 创建crud-generator skill目录结构
- [ ] 编写SKILL.md主文件
- [ ] 实现基础TypeScript生成器脚本
- [ ] 创建代码模板文件

**阶段二: Schema分析集成 (1周)**:
- [ ] 集成Prisma schema分析
- [ ] 复用V3 backend的loadDbInfo
- [ ] 实现类型转换逻辑

**阶段三: AI优化集成 (1-2周)**:
- [ ] 实现基础AI优化器
- [ ] 添加性能优化规则
- [ ] 添加安全优化规则

**阶段四: 测试和文档 (1周)**:
- [ ] 编写测试用例
- [ ] 完善文档
- [ ] 创建使用示例

### 9.2 技术栈

**必需组件**:
- Node.js + TypeScript
- Prisma ORM
- EJS模板引擎
- Agent Skills运行时

**可选组件**:
- AI优化服务
- 代码格式化工具
- 静态分析工具

---

## 十、总结

UCToo V4基于Agent Skills的AI原生代码生成引擎方案具有以下优势:

1. **轻量级**: 不增加运行时开销
2. **智能化**: AI驱动的代码优化
3. **可复用**: 充分复用V3 backend和Prisma生态
4. **易维护**: 模块化设计,易于升级
5. **可扩展**: 基于Agent Skills生态,易于扩展

该方案完美平衡了功能性和轻量级需求,是UCToo V4代码生成的最佳选择。

---

**文档版本**: 1.0.0  
**创建日期**: 2026-03-16  
**最后更新**: 2026-03-16  
**文档状态**: 设计完成
