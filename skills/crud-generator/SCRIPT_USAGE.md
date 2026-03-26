# CRUD Generator 脚本使用说明

## 脚本结构

### 核心脚本

**`scripts/generate-from-template.ts`** - 通用生成脚本

这是核心的代码生成脚本，提供了完整的CRUD模块生成功能。

#### 功能特性

- ✅ 模板变量替换
- ✅ 字段动态生成
- ✅ 两层代码保护机制
- ✅ 支持所有5层代码生成（Model、DAO、Service、Controller、Route）

#### 使用方式

**方式一：作为模块导入**

```javascript
import { generateModule } from './scripts/generate-from-template.js'

const fields = [
  { name: 'id', dbName: 'id', camelName: 'id', type: 'String', isPrimaryKey: true, isOptional: false },
  // ... 其他字段
]

await generateModule({
  tableName: 'your_table',
  dbName: 'uctoo',
  fields: fields,
  outputDir: './src/app'
})
```

**方式二：命令行运行**

```bash
node scripts/generate-from-template.ts <tableName> <dbName> [outputDir]
```

注意：命令行方式需要实现Prisma schema解析功能。

### 辅助脚本

**`scripts/example-generate-entity.js`** - 示例脚本

展示了如何使用通用生成脚本来生成entity模块。

```bash
node scripts/example-generate-entity.js
```

**`scripts/verify-entity-generation.js`** - 验证脚本

验证生成的entity模块与原entity模块是否完全一致。

```bash
node scripts/verify-entity-generation.js
```

## 为什么不需要test-generate-entity.js？

### 问题

之前创建了 `test-generate-entity.js`，这导致：

1. **代码重复**：与通用生成脚本功能重复
2. **维护困难**：需要同时维护两个脚本
3. **违反DRY原则**：Don't Repeat Yourself

### 解决方案

使用单一的通用生成脚本 `generate-from-template.ts`：

1. **统一入口**：所有生成都通过这个脚本
2. **易于维护**：只需维护一个脚本
3. **灵活使用**：可以作为模块导入或命令行运行

## 正确的使用流程

### 步骤1：准备字段定义

从Prisma schema中提取表的字段信息：

```javascript
const fields = [
  { 
    name: 'id',           // 字段名
    dbName: 'id',         // 数据库列名
    camelName: 'id',      // 驼峰命名
    type: 'String',       // Prisma类型
    isPrimaryKey: true,   // 是否主键
    isOptional: false     // 是否可选
  },
  // ... 其他字段
]
```

### 步骤2：配置生成参数

```javascript
const config = {
  tableName: 'your_table',    // 表名
  dbName: 'uctoo',            // 数据库名
  fields: fields,             // 字段定义
  outputDir: './src/app'      // 输出目录
}
```

### 步骤3：调用生成函数

```javascript
import { generateModule } from './scripts/generate-from-template.js'

await generateModule(config)
```

### 步骤4：验证生成结果

```bash
node scripts/verify-entity-generation.js
```

## 技能使用方式

### 通过技能交互

当用户说"为xxx表生成CRUD"时，技能会：

1. 分析Prisma schema
2. 提取字段定义
3. 调用 `generateModule()` 函数
4. 显示生成结果

### 直接使用脚本

开发者可以直接运行示例脚本：

```bash
node scripts/example-generate-entity.js
```

## 未来改进

### Prisma Schema自动解析

目前需要手动提供字段定义，未来可以实现：

```javascript
import { parsePrismaSchema } from './prisma-parser.js'

const fields = await parsePrismaSchema('entity', 'uctoo')
await generateModule({ tableName: 'entity', dbName: 'uctoo', fields, outputDir })
```

### 交互式命令行工具

```bash
node scripts/generate-from-template.ts --interactive

? 输入表名: entity
? 输入数据库名: uctoo
? 输入输出目录: ./src/app
? 是否生成测试: Yes

✅ 开始生成...
✅ 生成完成！
```

## 总结

**核心原则**：使用单一的通用生成脚本，避免代码重复

**推荐方式**：
1. 作为模块导入使用（最灵活）
2. 使用示例脚本（最简单）
3. 通过技能交互（最智能）

**不推荐方式**：
- ❌ 创建重复的测试脚本
- ❌ 复制粘贴生成逻辑
- ❌ 为每个表创建单独的生成脚本
