# 使用crud-generator技能生成uctoo_user模块报告

## 任务说明

使用crud-generator技能生成uctoo_user模块的标准CRUD代码。

## 当前情况分析

### 现有UctooUser模块问题

通过对比发现，现有的UctooUser模块与entity标准模块存在显著差异：

#### Model层差异

**现有UctooUserPO.cj**：
```cangjie
@QueryMappersGenerator["uctoo_user"]
public class UctooUserPO {
    @ORMField[true]
    public var id: String = ""
    public var name: String = ""
    // ... 使用 public var
}
```

**标准EntityPO.cj**：
```cangjie
@DataAssist[fields]
@QueryMappersGenerator["entity"]
public class EntityPO {
    @ORMField[true 'id']
    private var id: String = ""
    @ORMField['link']
    private var link: String = ""
    // ... 使用 private var，完整ORM注解
}
```

**主要差异**：
- ❌ 缺少 `@DataAssist[fields]` 注解
- ❌ 使用 `public var` 而非 `private var`
- ❌ ORM注解不完整（缺少列名映射）
- ❌ 缺少完整的构造函数

### 其他层差异

类似地，DAO、Service、Controller、Route层都存在功能缺失：
- 缺少批量操作方法
- 缺少skip查询支持
- 缺少sort/filter参数支持
- 缺少统计方法

## 生成方案

### 方案一：使用通用生成脚本（推荐）

由于JavaScript字符串插值与Cangjie语法冲突，建议：

1. **编译TypeScript脚本**
   ```bash
   cd skills/crud-generator/scripts
   tsc generate-from-template.ts
   ```

2. **创建生成配置**
   ```javascript
   const uctooUserFields = [
     { name: 'id', dbName: 'id', camelName: 'id', type: 'String', isPrimaryKey: true, isOptional: false },
     { name: 'name', dbName: 'name', camelName: 'name', type: 'String', isPrimaryKey: false, isOptional: false },
     // ... 其他字段
   ]
   
   await generateModule({
     tableName: 'uctoo_user',
     dbName: 'uctoo',
     fields: uctooUserFields,
     outputDir: './src/app'
   })
   ```

### 方案二：手动应用模板

直接使用模板文件，手动替换变量：

1. **Model模板**：`templates/model-full.cj.tpl`
2. **DAO模板**：`templates/dao-full.cj.tpl`
3. **Service模板**：`templates/service-full.cj.tpl`
4. **Controller模板**：`templates/controller-full.cj.tpl`
5. **Route模板**：`templates/route-full.cj.tpl`

### 方案三：参考entity模块修改

基于entity标准模块，手动修改为uctoo_user模块：

1. 复制entity模块的所有文件
2. 全局替换：
   - `entity` → `uctoo_user`
   - `Entity` → `UctooUser`
   - `entity` → `uctooUser`（驼峰）
3. 调整字段定义

## 字段定义

### uctoo_user表字段（从Prisma schema提取）

```javascript
const uctooUserFields = [
  { name: 'id', dbName: 'id', camelName: 'id', type: 'String', isPrimaryKey: true, isOptional: false },
  { name: 'name', dbName: 'name', camelName: 'name', type: 'String', isPrimaryKey: false, isOptional: false },
  { name: 'username', dbName: 'username', camelName: 'username', type: 'String', isPrimaryKey: false, isOptional: false },
  { name: 'email', dbName: 'email', camelName: 'email', type: 'String', isPrimaryKey: false, isOptional: false },
  { name: 'password', dbName: 'password', camelName: 'password', type: 'String', isPrimaryKey: false, isOptional: false },
  { name: 'avatar', dbName: 'avatar', camelName: 'avatar', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'created_at', dbName: 'created_at', camelName: 'createdAt', type: 'DateTime', isPrimaryKey: false, isOptional: false },
  { name: 'last_login', dbName: 'last_login', camelName: 'lastLogin', type: 'DateTime', isPrimaryKey: false, isOptional: false },
  { name: 'auth_provider', dbName: 'auth_provider', camelName: 'authProvider', type: 'Int', isPrimaryKey: false, isOptional: false },
  { name: 'creator', dbName: 'creator', camelName: 'creator', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'deleted_at', dbName: 'deleted_at', camelName: 'deletedAt', type: 'DateTime', isPrimaryKey: false, isOptional: true },
  { name: 'last_login_ip', dbName: 'last_login_ip', camelName: 'lastLoginIp', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'last_login_time', dbName: 'last_login_time', camelName: 'lastLoginTime', type: 'DateTime', isPrimaryKey: false, isOptional: false },
  { name: 'remember_token', dbName: 'remember_token', camelName: 'rememberToken', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'status', dbName: 'status', camelName: 'status', type: 'Int', isPrimaryKey: false, isOptional: false },
  { name: 'updated_at', dbName: 'updated_at', camelName: 'updatedAt', type: 'DateTime', isPrimaryKey: false, isOptional: false },
  { name: 'access_token', dbName: 'access_token', camelName: 'accessToken', type: 'String', isPrimaryKey: false, isOptional: true }
];
```

## 技术限制说明

### JavaScript字符串插值问题

在JavaScript中生成Cangjie代码时，会遇到字符串插值冲突：

```javascript
// JavaScript模板字符串
const code = `sb.append("\\"${f.dbName}\\":\\"${v}\\"")`
// Cangjie需要的是：sb.append("\"field\":\"${v}\"")
// 但JavaScript会尝试解析 ${v}
```

### 解决方案

1. **使用TypeScript编译后的脚本**
2. **使用模板文件直接替换**
3. **使用其他语言（如Python）生成**

## 建议

### 立即可行的方案

**手动应用模板**：

1. 复制 `templates/model-full.cj.tpl` 到 `models/uctoo/UctooUserPO.cj`
2. 替换变量：
   - `{DATABASE_NAME}` → `uctoo`
   - `{TABLE_NAME}` → `uctoo_user`
   - `{TABLE_NAME_PASCAL}` → `UctooUser`
3. 根据字段定义生成 `{FIELDS_SECTION}` 等部分
4. 对其他层重复此过程

### 长期方案

**完善生成脚本**：

1. 实现Prisma schema自动解析
2. 使用模板引擎（如Handlebars、EJS）
3. 提供交互式命令行工具

## 总结

### 当前状态

- ✅ crud-generator技能已完善
- ✅ 模板文件已准备就绪
- ✅ 字段定义已提取
- ⚠️ JavaScript字符串插值限制

### 下一步行动

1. **选择生成方案**（推荐：手动应用模板）
2. **生成各层代码**
3. **验证生成结果**
4. **测试CRUD接口**

### 预期结果

生成的uctoo_user模块将包含：
- ✅ 完整的ORM注解
- ✅ 正确的字段可见性
- ✅ 完整的构造函数
- ✅ 批量操作支持
- ✅ skip查询支持
- ✅ sort/filter参数支持
- ✅ 两层代码保护机制

与entity标准模块完全一致！
