# CRUD Generator 关键字检测机制改进报告

**改进日期**: 2026-03-21  
**改进版本**: v2.0  
**状态**: ✅ 已完成

---

## 一、改进目标

完善crud-generator技能，添加仓颉关键字检测机制，支持包含仓颉关键字的表的代码自动生成。

---

## 二、关键字冲突规律研究

### 1. 冲突类型分析

**类型1: 字段名冲突**
- 数据库列名是仓颉保留关键字
- 例如：`type` 列 → 生成 `var type: ?Int32` → 编译错误

**类型2: 局部变量名冲突**
- Controller的mapToEntity方法中的局部变量名是关键字
- 例如：`if (let Some(type) <- map.get("type"))` → 编译错误

### 2. 解决方案

**字段重命名策略**:
- 检测关键字 → 添加表名前缀
- 例如：`type` → `permissionType` (permissions表)
- 保持数据库列名不变（通过@ORMField注解）

**局部变量重命名策略**:
- 检测关键字 → 添加Value后缀
- 例如：`type` → `typeValue`

---

## 三、实现的改进

### 1. 仓颉保留关键字列表

定义了完整的仓颉保留关键字集合（共50+个）：

```javascript
const CJ_KEYWORDS = new Set([
    // 类型定义关键字
    'type', 'class', 'interface', 'enum', 'struct', 'unit',
    // 函数和变量关键字
    'func', 'var', 'let', 'const', 'prop', 'mut',
    // 访问控制关键字
    'public', 'private', 'protected', 'internal', 'open', 'sealed',
    // 继承和扩展关键字
    'extend', 'abstract', 'override', 'redef', 'super', 'this',
    // 控制流关键字
    'if', 'else', 'match', 'case', 'default', 'when',
    'for', 'while', 'do', 'break', 'continue', 'return',
    // 异常处理关键字
    'try', 'catch', 'throw', 'finally',
    // 包和导入关键字
    'import', 'package', 'from',
    // 布尔和空值关键字
    'true', 'false', 'null', 'None', 'Some',
    // 类型操作关键字
    'in', 'is', 'as', 'where',
    // 其他关键字
    'static', 'defer', 'spawn', 'sync', 'unsafe',
    // 查询关键字
    'select', 'from', 'order', 'by', 'asc', 'desc',
    // 常用但可能冲突的关键字
    'value', 'key', 'data', 'result', 'error', 'status'
])
```

### 2. 关键字检测函数

```javascript
/**
 * 检查是否为仓颉保留关键字
 */
function isKeyword(name) {
    return CJ_KEYWORDS.has(name)
}
```

### 3. 安全字段名生成

```javascript
/**
 * 生成安全的字段名（避免关键字冲突）
 * 策略：如果是关键字，添加表名单数前缀
 * 例如：type → permissionType (permissions表)
 */
function generateSafeFieldName(dbFieldName, tableName) {
    const camelName = convertToCamelCase(dbFieldName)
    
    if (isKeyword(camelName)) {
        // 移除表名中的下划线并转为驼峰，然后移除复数形式
        let tablePrefix = convertToCamelCase(tableName)
        // 移除复数s：permissions → permission
        if (tablePrefix.endsWith('s') && tablePrefix.length > 1) {
            tablePrefix = tablePrefix.slice(0, -1)
        }
        // 添加表名前缀：type → permissionType
        return `${tablePrefix}${capitalizeFirst(camelName)}`
    }
    
    return camelName
}
```

### 4. 安全局部变量名生成

```javascript
/**
 * 生成安全的局部变量名（用于Controller的mapToEntity方法）
 * 策略：如果是关键字，添加Value后缀
 * 例如：type → typeValue
 */
function generateSafeLocalVarName(fieldName) {
    if (isKeyword(fieldName)) {
        return `${fieldName}Value`
    }
    return fieldName
}
```

### 5. 字段处理流程

```javascript
/**
 * 处理字段列表，添加安全名称信息
 */
function processFields(fields, tableName) {
    return fields.map(field => {
        const safeName = generateSafeFieldName(field.name, tableName)
        const isRenamed = safeName !== field.camelName
        
        return {
            ...field,
            safeName: safeName,           // 安全字段名
            isRenamed: isRenamed,          // 是否被重命名
            localVarName: generateSafeLocalVarName(field.camelName)  // 局部变量名
        }
    })
}
```

---

## 四、生成的代码改进

### 1. Model层改进

**生成的字段定义**:
```cangjie
// 注意: 数据库列名 'type' 是关键字，已重命名为 'permissionType'
@ORMField['type']  // 数据库列名保持 'type'
private var permissionType: ?Int32 = None<Int32>  // 仓颉字段名改为 permissionType
```

**改进点**:
- 添加重命名注释，说明原因
- @ORMField注解保持数据库列名不变
- 字段名使用安全名称

### 2. DAO层改进

**INSERT语句**:
```cangjie
insert into permissions(
    type,  // 数据库列名
    ...
) values(
    ${arg(entity.permissionType)},  // 使用安全字段名
    ...
)
```

**UPDATE语句**:
```cangjie
update permissions set
    type = ${arg(entity.permissionType)},  // 使用安全字段名
    ...
```

### 3. Service层改进

**字段合并逻辑**:
```cangjie
if (entity.permissionType.isSome()) {
    existingEntity.permissionType = entity.permissionType
}
```

### 4. Controller层改进

**mapToEntity方法**:
```cangjie
if (let Some(typeValue) <- map.get("type")) {  // 局部变量使用安全名称
    let typeValueInt64 = typeValue as Int64
    if (let Some(s) <- typeValueInt64) {
        entity.permissionType = Some<Int32>(Int32(s))  // 字段使用安全名称
    }
}
```

---

## 五、测试验证

### 测试用例: permissions表

**输入**:
- 表名: permissions
- 冲突字段: type (仓颉关键字)

**输出**:
```
⚠️  检测到关键字冲突，已自动重命名字段：
   type → permissionType (数据库列: type)
```

**生成的文件**:
- ✅ PermissionsPO.cj - 字段重命名为 permissionType
- ✅ PermissionsDAO.cj - SQL参数使用 entity.permissionType
- ✅ PermissionsService.cj - 字段访问使用 permissionType
- ✅ PermissionsController.cj - 局部变量使用 typeValue，字段使用 permissionType
- ✅ PermissionsRoute.cj - 无需修改

**编译验证**: ✅ 编译成功

---

## 六、使用说明

### 1. 使用新版本生成器

```javascript
import { generateModule } from './generate-from-template-v2.js'

await generateModule({
    tableName: 'permissions',
    dbName: 'uctoo',
    fields: fields,
    outputDir: './src/app'
})
```

### 2. 自动检测和重命名

生成器会自动：
1. 检测字段名是否为仓颉关键字
2. 自动重命名字段（添加表名前缀）
3. 在Model中添加重命名注释
4. 在所有层级使用安全字段名
5. 在Controller中使用安全局部变量名

### 3. 输出提示

如果检测到关键字冲突，会输出：
```
⚠️  检测到关键字冲突，已自动重命名字段：
   type → permissionType (数据库列: type)
```

---

## 七、支持的关键字列表

### 完整列表（50+个）

**类型定义**: type, class, interface, enum, struct, unit  
**函数变量**: func, var, let, const, prop, mut  
**访问控制**: public, private, protected, internal, open, sealed  
**继承扩展**: extend, abstract, override, redef, super, this  
**控制流**: if, else, match, case, default, when, for, while, do, break, continue, return  
**异常处理**: try, catch, throw, finally  
**包导入**: import, package, from  
**布尔空值**: true, false, null, None, Some  
**类型操作**: in, is, as, where  
**其他**: static, defer, spawn, sync, unsafe  
**查询**: select, from, order, by, asc, desc  
**常用**: value, key, data, result, error, status

---

## 八、改进效果

### 1. 自动化程度

- ✅ 自动检测关键字冲突
- ✅ 自动生成安全字段名
- ✅ 自动添加重命名注释
- ✅ 自动更新所有层级的代码

### 2. 代码质量

- ✅ 避免编译错误
- ✅ 保持数据库列名不变
- ✅ 保持语义清晰
- ✅ 添加详细注释

### 3. 开发效率

- ✅ 无需手动修复关键字冲突
- ✅ 一键生成包含关键字的表
- ✅ 减少人工错误
- ✅ 提高开发效率

---

## 九、后续改进建议

### 1. 扩展关键字列表

根据仓颉语言发展，持续更新关键字列表。

### 2. 支持自定义重命名策略

允许用户配置自定义的重命名策略，例如：
- 添加前缀
- 添加后缀
- 完全自定义映射

### 3. 支持复合主键表

当前版本仍不支持复合主键表，需要进一步改进。

### 4. 生成重命名映射文档

自动生成字段重命名映射文档，方便开发者查阅。

---

## 十、总结

### 成果

✅ 完整的仓颉关键字检测机制  
✅ 自动字段重命名策略  
✅ 自动局部变量重命名  
✅ 详细的注释和提示  
✅ 测试验证通过

### 文件

- `generate-from-template-v2.js` - 改进版生成脚本
- `test-keyword-detection.js` - 测试脚本

### 效果

- 支持包含仓颉关键字的表的自动生成
- 无需手动修复编译错误
- 提高开发效率和代码质量

---

**改进工具**: crud-generator v2.0  
**测试状态**: ✅ 通过  
**可用性**: ✅ 可直接使用
