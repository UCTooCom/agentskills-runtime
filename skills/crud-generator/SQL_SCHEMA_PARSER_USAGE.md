# SQL Schema Parser 使用说明

## 概述

SQL Schema Parser 用于从 `uctooDB.sql` 文件解析 PostgreSQL 表结构，替代之前从 Prisma schema 读取表结构的方式。

## 为什么改用 SQL 解析

1. **uctoo v4 不再依赖 Prisma**：uctoo v4 使用仓颉语言和 Fountain ORM，不再使用 Prisma
2. **统一数据源**：`uctooDB.sql` 是 uctoo v3 和 v4 统一使用的数据库结构文件
3. **更准确**：直接解析 SQL 定义，避免 Prisma schema 与实际数据库的差异

## 文件位置

- **SQL文件**：`apps/agentskills-runtime/sql/uctooDB.sql`
- **解析器**：`apps/agentskills-runtime/skills/crud-generator/scripts/sql-schema-parser.js`

## API

### 1. 解析单个表

```javascript
import { parseTable } from './scripts/sql-schema-parser.js'

// 解析 entity 表
const tableSchema = parseTable('entity')

console.log(tableSchema)
// {
//   tableName: 'entity',
//   database: 'uctoo',
//   primaryKey: 'id',
//   fields: [
//     {
//       name: 'id',
//       dbName: 'id',
//       camelName: 'id',
//       type: 'String',
//       isOptional: false,
//       isPrimaryKey: true,
//       defaultValue: 'gen_random_uuid()',
//       comment: '主键UUID'
//     },
//     // ... 其他字段
//   ]
// }
```

### 2. 获取所有表名

```javascript
import { listAllTables } from './scripts/sql-schema-parser.js'

const tables = listAllTables()
console.log(tables) // ['admin_applet', 'agent_runtime_status', ...]
console.log(`共 ${tables.length} 张表`) // 共 150 张表
```

### 3. 批量解析多个表

```javascript
import { parseMultipleTables } from './scripts/sql-schema-parser.js'

const tables = ['entity', 'uctoo_user', 'permissions']
const schemas = parseMultipleTables(null, tables)

schemas.forEach(schema => {
  console.log(`${schema.tableName}: ${schema.fields.length} 个字段`)
})
```

### 4. 使用自定义 SQL 文件路径

```javascript
import { parseTableFromSQL } from './scripts/sql-schema-parser.js'

const tableSchema = parseTableFromSQL('/path/to/custom.sql', 'my_table')
```

## PostgreSQL 类型映射

| PostgreSQL 类型 | 通用类型 | 说明 |
|----------------|---------|------|
| uuid | String | UUID 主键 |
| text | String | 文本 |
| varchar | String | 变长字符串 |
| int4 | Int | 32位整数 |
| int8 | Int | 64位整数 |
| float8 | Float | 64位浮点 |
| bool | Boolean | 布尔值 |
| timestamptz | DateTime | 带时区时间戳 |
| timestamp | DateTime | 时间戳 |
| date | DateTime | 日期 |
| jsonb | String | JSON二进制 |
| json | String | JSON文本 |

## 字段解析结果

每个字段包含以下信息：

```javascript
{
  name: 'created_at',        // 数据库字段名
  dbName: 'created_at',      // 数据库字段名（同name）
  camelName: 'createdAt',    // 驼峰命名
  type: 'DateTime',          // 通用类型
  isOptional: false,         // 是否可空
  isPrimaryKey: false,       // 是否主键
  defaultValue: 'CURRENT_TIMESTAMP',  // 默认值
  comment: '创建时间'        // 字段注释
}
```

## 使用示例

### 生成 CRUD 模块

```javascript
import { parseTable } from './scripts/sql-schema-parser.js'
import { generateModule } from './scripts/generate-from-template-v2.js'

// 1. 从 SQL 解析表结构
const tableSchema = parseTable('entity')

// 2. 生成 CRUD 模块
await generateModule({
  tableName: tableSchema.tableName,
  dbName: tableSchema.database,
  fields: tableSchema.fields,
  outputDir: './src/app'
})

console.log('✅ CRUD 模块生成完成')
```

### 命令行使用

```bash
# 查看所有表
node scripts/generate-from-sql-example.js

# 生成指定表的 CRUD
node scripts/generate-from-sql-example.js entity
node scripts/generate-from-sql-example.js uctoo_user
```

## 测试

运行测试脚本验证解析器：

```bash
node scripts/test-sql-parser.js
```

测试内容：
1. ✅ 获取所有表名（150张表）
2. ✅ 解析 entity 表（21个字段）
3. ✅ 解析 uctoo_user 表（17个字段）
4. ✅ 批量解析多张表

## 与 Prisma Schema 的对比

### 之前（Prisma）

```javascript
// 读取 apps/backend/prisma/uctoo/schema.prisma
model entity {
  id            String     @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  link          String     @db.VarChar
  privacy_level Int        @default(0)
  // ...
}
```

### 现在（SQL）

```javascript
// 读取 apps/agentskills-runtime/sql/uctooDB.sql
CREATE TABLE "public"."entity" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "link" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "privacy_level" int4 NOT NULL DEFAULT 0,
  // ...
);
```

## 注意事项

1. **SQL 文件格式**：必须是 Navicat 导出的标准 PostgreSQL 格式
2. **字段注释**：从 `COMMENT ON COLUMN` 语句提取
3. **主键识别**：从 `PRIMARY KEY` 约束提取
4. **默认值解析**：支持 `gen_random_uuid()`, `CURRENT_TIMESTAMP` 等 PostgreSQL 函数

## 更新日志

- **2026-03-28**：创建 SQL Schema Parser，替代 Prisma schema 解析
- 支持 150 张表的解析
- 支持 PostgreSQL 特有类型映射
- 支持字段注释提取
