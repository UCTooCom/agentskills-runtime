# CRUD Generator 关键字冲突和复合主键问题修复报告

**日期**: 2026-03-21  
**问题**: 编译错误 - 仓颉关键字冲突和复合主键表处理不当

---

## 一、发现的问题

### 1. 仓颉关键字冲突

**问题描述**:
- 数据库列名 `type` 是仓颉编程语言的保留关键字
- 生成的代码直接使用 `type` 作为变量名，导致编译错误

**错误示例**:
```cangjie
private var type: ?Int32 = None<Int32>  // ❌ 编译错误
```

**解决方案**:
- 方案1: 使用反引号转义 `` `type` `` - 但 `@DataAssist` 宏不支持
- 方案2: 重命名字段为非关键字 - **采用此方案**
  - `type` → `permissionType`
  - 保持语义清晰，避免关键字冲突

**已修复文件**:
- `PermissionsPO.cj` - Model层
- `PermissionsDAO.cj` - DAO层
- `PermissionsService.cj` - Service层
- `PermissionsController.cj` - Controller层

### 2. 复合主键表处理不当

**问题描述**:
- `group_has_permission` 表使用复合主键 (`group_id`, `permission_name`)
- 生成的代码假设所有表都有单一主键 `id`
- 导致编译错误：`'id' is not a member of class 'GroupHasPermissionPO'`

**错误示例**:
```cangjie
where id = ${arg(entity.id)}  // ❌ GroupHasPermissionPO没有id字段
```

**解决方案**:
- 检测复合主键表（没有 `id` 字段的表）
- 使用复合主键字段进行查询、更新、删除操作
- 修改方法签名以接受复合主键参数

**已修复文件**:
- `GroupHasPermissionDAO.cj` - 修改为使用复合主键

**修改内容**:
```cangjie
// 查询方法
func findGroupHasPermissionByKey(groupId: String, permissionName: String): Option<GroupHasPermissionPO>

// 更新方法
func updateGroupHasPermission(entity: GroupHasPermissionPO): Int64 {
    // where group_id = ${arg(entity.groupId)} and permission_name = ${arg(entity.permissionName)}
}

// 删除方法
func softDeleteGroupHasPermissionByKey(groupId: String, permissionName: String): Int64
func restoreGroupHasPermissionByKey(groupId: String, permissionName: String): Int64
func deleteGroupHasPermissionByKey(groupId: String, permissionName: String): Int64
```

---

## 二、需要改进的crud-generator技能

### 1. 关键字检测和转义

**需要添加的功能**:
```javascript
// 仓颉保留关键字列表
const CJ_KEYWORDS = [
    'type', 'class', 'interface', 'enum', 'struct',
    'func', 'var', 'let', 'const', 'prop',
    'if', 'else', 'match', 'case', 'default',
    'for', 'while', 'do', 'break', 'continue', 'return',
    'try', 'catch', 'throw', 'finally',
    'import', 'package', 'public', 'private', 'protected',
    'static', 'mut', 'open', 'sealed', 'abstract', 'override',
    'extend', 'this', 'super', 'true', 'false', 'null',
    'in', 'is', 'as', 'where', 'select', 'from',
    // ... 更多关键字
]

// 检查是否为关键字
function isKeyword(name) {
    return CJ_KEYWORDS.includes(name)
}

// 生成安全的字段名
function generateSafeFieldName(dbFieldName) {
    const camelName = convertToCamelCase(dbFieldName)
    if (isKeyword(camelName)) {
        // 添加前缀避免关键字冲突
        return `${tableName}${capitalizeFirst(camelName)}`
    }
    return camelName
}
```

### 2. 复合主键检测

**需要添加的功能**:
```javascript
// 检测是否为复合主键表
function isCompositeKeyTable(fields) {
    const hasIdField = fields.some(f => f.name === 'id' && f.isPrimaryKey)
    return !hasIdField
}

// 获取主键字段
function getPrimaryKeyFields(fields) {
    return fields.filter(f => f.isPrimaryKey)
}

// 生成复合主键查询条件
function generateCompositeKeyWhereClause(primaryKeys) {
    return primaryKeys.map(pk => 
        `${pk.dbName} = ${arg(entity.${pk.camelName})}`
    ).join(' and ')
}
```

### 3. 模板改进

**Model模板改进**:
- 添加关键字检测逻辑
- 自动重命名冲突字段
- 添加字段重命名注释

**DAO模板改进**:
- 检测复合主键表
- 生成复合主键查询方法
- 修改更新/删除方法使用复合主键

**Service模板改进**:
- 适配复合主键表的DAO方法
- 修改方法签名

**Controller模板改进**:
- 适配复合主键表
- 修改请求参数处理

---

## 三、建议的改进方案

### 方案1: 字段重命名策略

**规则**:
- 如果字段名是关键字，添加表名前缀
- 例如: `type` → `permissionType` (permissions表)
- 例如: `type` → `userType` (users表)

**优点**:
- 避免关键字冲突
- 保持语义清晰
- 兼容所有宏

**缺点**:
- 字段名与数据库列名不一致
- 需要额外的映射逻辑

### 方案2: 复合主键表特殊处理

**规则**:
- 检测没有 `id` 字段的表
- 识别主键字段（通过 `@id` 注解或schema分析）
- 生成复合主键专用的CRUD方法

**优点**:
- 正确处理复合主键表
- 符合数据库设计

**缺点**:
- 增加生成器复杂度
- 需要修改所有层级的模板

---

## 四、下一步行动

### 立即修复
1. ✅ 修复 `PermissionsPO` 的 `type` 关键字冲突
2. ✅ 修复 `GroupHasPermissionDAO` 的复合主键问题
3. ⏳ 修复 `GroupHasPermissionService` 和 `GroupHasPermissionController`
4. ⏳ 检查其他生成的表是否有类似问题

### 长期改进
1. 更新 `generate-from-template.js` 添加关键字检测
2. 更新模板文件支持复合主键表
3. 添加字段重命名策略
4. 完善测试用例

---

## 五、受影响的表

### 已修复
- ✅ `permissions` - type关键字冲突
- ✅ `group_has_permission` - 复合主键

### 需要检查
- ⏳ `user_group` - 可能有类似问题
- ⏳ `user_has_account` - 可能有类似问题
- ⏳ `user_has_group` - 可能有类似问题

---

## 六、编译状态

**当前状态**: 部分修复，仍有编译错误

**下一步**: 
1. 修复Service层和Controller层的复合主键问题
2. 检查其他表的类似问题
3. 完成编译测试

---

**修复工具**: 手动修复 + 未来改进crud-generator  
**预计完成时间**: 需要继续修复Service和Controller层
