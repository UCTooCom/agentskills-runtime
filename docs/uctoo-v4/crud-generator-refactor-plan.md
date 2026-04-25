# CRUD 生成器重构计划

## 问题分析

### 现象复述
- 使用 crudgen 生成 db_connection 模块后，项目编译失败，出现 `extend SqlExecutor <: EntityDAO { }` 错误
- 但在代码中找不到该错误语句的实际位置
- 删除生成的 db_connection 模块后，项目编译成功

### 根本原因分析

#### 1. 代码生成模板问题
- **模板变量替换不完整**：DAO.cj.tpl 模板中可能存在变量替换逻辑问题
- **方法名冲突**：生成的方法名与其他模块产生冲突
- **字段名处理**：关键字字段（如 `type`）的处理不当

#### 2. 依赖关系问题
- **循环依赖**：生成的模块可能与其他模块产生循环依赖
- **类型冲突**：不同模块中定义的类型可能产生冲突

#### 3. 编译缓存问题
- **缓存污染**：编译缓存可能包含旧的错误信息
- **增量编译问题**：增量编译时可能保留了错误的编译状态

#### 4. 关键字处理问题
- **type 字段**：db_connection 表中的 `type` 字段是仓颉语言关键字，生成的代码未正确处理
- **其他关键字**：可能还有其他数据库字段名是仓颉关键字

---

## 解决方案对比

### 旧版本 crud-generator 方案（JavaScript）

| 特性 | 实现方式 |
|------|----------|
| 代码生成 | JavaScript 脚本 + 模板变量替换 |
| 关键字处理 | 70个官方关键字自动检测和重命名 |
| 模板格式 | `{TABLE_NAME}`, `{INSERT_FIELDS}` 等占位符 |
| 生成验证 | 与标准模块逐行对比验证 |
| 依赖 | Node.js 环境 |

**优点**：
- 确定性代码生成，结果可预测
- 完整的关键字检测机制
- 与标准模块完全一致
- 已验证可用

**缺点**：
- 需要 Node.js 环境
- 混合技术栈（JS + Cangjie）

### 新版本 crudgen 方案（Cangjie）

| 特性 | 实现方式 |
|------|----------|
| 代码生成 | 纯 Cangjie 实现 |
| 关键字处理 | 不完整 |
| 模板格式 | 变量替换逻辑可能有问题 |
| 生成验证 | 未完善 |
| 依赖 | 仅 Cangjie 运行时 |

**问题**：
- 关键字处理不完善
- 模板变量替换逻辑有缺陷
- 生成的代码可能与现有代码冲突
- 编译错误难以追踪

---

## 推荐方案：混合架构

### 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                    crudgen 主入口                          │
│              (Cangjie CLI 工具入口点)                       │
├─────────────────────────────────────────────────────────────┤
│                    代码生成引擎                              │
│  ┌─────────────────┐    ┌─────────────────┐              │
│  │ 旧版本 JS 方案   │    │ 新版本 Cangjie   │              │
│  │ (确定性生成)     │    │ 方案 (扩展功能)   │              │
│  └─────────────────┘    └─────────────────┘              │
├─────────────────────────────────────────────────────────────┤
│                    共享配置层                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  - 关键字列表 (70个官方关键字)                        │   │
│  │  - 标准模块模板 (EntityDAO, EntityService etc.)      │   │
│  │  - SQL Schema 解析器                                 │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    输出层                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  - Model / DAO / Service / Controller / Route        │   │
│  │  - 权限节点生成                                      │   │
│  │  - 路由自动注册                                      │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 实施策略

#### 阶段一：修复旧版本 JS 生成器（推荐先完成）

1. **复用现有 JS 生成器**
   - 使用 `scripts/generate-from-template-v2.js`
   - 完善关键字处理机制
   - 确保与标准 entity 模块完全一致

2. **修复 db_connection 生成**
   - 检测 `type` 字段 → 重命名为 `connType`
   - 使用正确的模板变量替换
   - 验证生成的代码

3. **添加权限节点生成**
   - 在 JS 生成器中添加权限节点生成逻辑
   - 查询 `permission_name = 'database'` 的节点作为父节点
   - 使用父节点的 `creator` 字段值

#### 阶段二：优化新版本 Cangjie 生成器

1. **修复模板系统**
   - 修复 DAO.cj.tpl 模板变量替换逻辑
   - 确保所有变量正确替换
   - 添加关键字检测机制

2. **添加编译缓存清理**
   - 在生成前自动清理编译缓存
   - 提供手动清理命令

3. **完善权限节点生成**
   - 改进权限节点查询逻辑
   - 确保权限节点生成失败不影响代码生成

---

## 技术实现方案

### 1. 关键字处理（70个官方关键字）

```javascript
// scripts/keyword-handler.js

const KEYWORDS = [
    // 类型关键字
    'Bool', 'Rune', 'Float16', 'Float32', 'Float64',
    'Int8', 'Int16', 'Int32', 'Int64', 'IntNative',
    'UInt8', 'UInt16', 'UInt32', 'UInt64', 'UIntNative',
    'Nothing', 'Unit', 'VArray', 'This',
    // 定义关键字
    'class', 'interface', 'enum', 'struct', 'type', 'func', 'init', 'main', 'operator', 'macro', 'prop',
    // 访问控制关键字
    'public', 'private', 'protected', 'open', 'static',
    // 继承扩展关键字
    'extend', 'abstract', 'override', 'redef', 'super',
    // 控制流关键字
    'if', 'else', 'match', 'case', 'for', 'while', 'do', 'break', 'continue', 'return', 'where',
    // 异常处理关键字
    'try', 'catch', 'throw', 'finally',
    // 包和导入关键字
    'import', 'package', 'foreign',
    // 其他关键字
    'as', 'const', 'false', 'finally', 'in', 'is', 'let', 'mut', 'quote', 'spawn', 'synchronized', 'unsafe', 'var', 'true'
];

function isKeyword(name) {
    return KEYWORDS.includes(name);
}

function handleKeywordField(tableName, fieldName) {
    if (isKeyword(fieldName)) {
        // 字段重命名策略：添加表名前缀（单数形式）
        const prefix = tableName.replace(/_([a-z])/g, (_, c) => c.toUpperCase()).replace(/s$/, '');
        const newName = prefix + fieldName.charAt(0).toUpperCase() + fieldName.slice(1);
        return {
            dbName: fieldName,        // 数据库列名保持不变
            cangjieName: newName,    // 仓颉字段名重命名
            renamed: true
        };
    }
    return {
        dbName: fieldName,
        cangjieName: fieldName,
        renamed: false
    };
}
```

### 2. 标准模板变量

```javascript
// templates/model-full.cj.tpl 变量
{
  '{DATABASE_NAME}': 'uctoo',
  '{TABLE_NAME}': 'db_connection',
  '{TABLE_NAME_CAMEL}': 'dbConnection',
  '{TABLE_NAME_PASCAL}': 'DbConnection',
  '{FIELDS_SECTION}': '...',       // 生成的字段定义
  '{CONSTRUCTOR_FIELDS}': '...',   // 构造函数参数
  '{TO_JSON_FIELDS}': '...',       // toJson 字段序列化
  '{INSERT_FIELDS}': '...',        // INSERT 字段列表
  '{INSERT_VALUES}': '...',        // INSERT 值列表
  '{UPDATE_SETS}': '...',          // UPDATE SET 部分
  '{MAP_TO_ENTITY_METHOD}': '...'  // mapToEntity 方法
}
```

### 3. 权限节点生成

```javascript
// scripts/generate-permission.js

async function generatePermissionNode(dbName, tableName, executor) {
    try {
        // 1. 查询 database 权限节点作为父节点
        const parentNode = await executor.query(`
            SELECT id, creator FROM permissions
            WHERE permission_name = 'database'
            AND deleted_at IS NULL
        `);

        if (!parentNode) {
            console.warn('未找到 database 权限节点，跳过权限节点生成');
            return true;
        }

        const parentId = parentNode.id;
        const creator = parentNode.creator;

        // 2. 检查是否已存在
        const existing = await executor.query(`
            SELECT id FROM permissions
            WHERE permission_name = '${dbName}.${tableName}'
            AND deleted_at IS NULL
        `);

        if (existing) {
            console.log(`权限节点 ${dbName}.${tableName} 已存在`);
            return true;
        }

        // 3. 插入新权限节点
        await executor.query(`
            INSERT INTO permissions(
                permission_name, display_name, parent_id, level,
                is_menu, menu_icon, menu_order,
                creator, created_at, updated_at, deleted_at
            ) VALUES (
                '${dbName}.${tableName}',
                '${tableName}',
                '${parentId}',
                3,
                false,
                '',
                0,
                '${creator}',
                NOW(),
                NOW(),
                NULL
            )
        `);

        console.log(`权限节点 ${dbName}.${tableName} 生成成功`);
        return true;
    } catch (error) {
        console.error(`生成权限节点失败: ${error.message}`);
        return false; // 失败不影响代码生成
    }
}
```

### 4. Cangjie 版本模板修复

```cangjie
// templates/DAO.cj.tpl 片段

// 关键字处理示例
// 如果字段名是 type，则在 SQL 中使用 type，仓颉变量名改为 connType
func insert{TABLE_NAME_PASCAL}(entity: {TABLE_NAME_PASCAL}PO): String {
    executor.setSql('''
        insert into {TABLE_NAME}(
            {INSERT_COLUMNS}
            type  // 保持数据库列名
        ) values(
            {INSERT_VALUES}
            ${arg(entity.connType)}  // 使用重命名后的字段名
        )
        returning id
    ''').singleFirst<String>() ?? ""
}
```

---

## 实施步骤

### 步骤 1：验证现有 entity 模块

```bash
# 对比生成的 entity 模块与标准 entity 模块
node scripts/example-generate-entity.js
diff -r src/app/models/uctoo/EntityPO.cj generated/entity/models/uctoo/EntityPO.cj
```

### 步骤 2：修复 db_connection 生成

```bash
# 使用修复后的生成器生成 db_connection
node scripts/generate-from-template-v2.js --table db_connection --db uctoo

# 验证生成结果
diff -r src/app/dao/uctoo/DbConnectionDAO.cj expected/DbConnectionDAO.cj
```

### 步骤 3：编译验证

```bash
# 清理编译缓存
Remove-Item -Path ".cjpm/build" -Recurse -Force
Remove-Item -Path ".cjpm/cache" -Recurse -Force

# 重新编译
cjpm build
```

### 步骤 4：运行测试

```bash
# 测试 CRUD 操作
.\target\release\bin\magic.app.tools.crudgen.exe --db uctoo --table entity
```

---

## 预期效果

| 阶段 | 目标 | 验证方式 |
|------|------|----------|
| 阶段一 | 旧版本 JS 生成器正常生成 db_connection | diff 对比 + 编译通过 |
| 阶段二 | 权限节点正确生成 | 数据库查询验证 |
| 阶段三 | 新版本 Cangjie 生成器修复 | 编译通过 + 功能测试 |

---

## 风险评估

| 风险 | 等级 | 应对措施 |
|------|------|----------|
| JS 生成器与 Cangjie 环境冲突 | 低 | 保持两套生成器独立运行 |
| 关键字处理遗漏 | 中 | 增加测试用例覆盖 70 个关键字 |
| 权限节点生成失败 | 中 | 确保失败不影响代码生成 |
| 模板变量替换错误 | 高 | 使用 diff 工具严格验证生成结果 |
| 编译缓存污染 | 低 | 提供缓存清理命令 |

---

## 结论

通过采用混合架构方案，结合旧版本 JavaScript 生成器的确定性代码生成能力和新版本 Cangjie 生成器的扩展性，可以有效解决当前 crudgen 存在的问题。推荐首先使用经过验证的 JS 生成器生成 db_connection 模块，确保与标准 entity 模块完全一致，然后再逐步完善 Cangjie 版本生成器。

---

## 参考文档

- [旧版本 crud-generator 技能](./skills/crud-generator/SKILL.md)
- [EntityDAO 标准实现](../dao/uctoo/EntityDAO.cj)
- [EntityService 标准实现](../services/uctoo/EntityService.cj)
- [EntityController 标准实现](../controllers/uctoo/entity/EntityController.cj)