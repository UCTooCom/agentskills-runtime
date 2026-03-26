# CRUD Generator 改进方案

## 问题概述

通过对比entity标准模块和uctoo_user生成模块,发现crud-generator生成的代码与标准实现存在显著差异,导致生成的代码功能不完整、规范性不足。

## 详细差异分析

### 1. Controllers层差异

#### 缺失功能
- ❌ **批量操作支持**: 缺少批量编辑(`ids`参数)、批量删除、批量恢复功能
- ❌ **getManyWithSkip方法**: 缺少支持skip参数的查询方法
- ❌ **sort和filter参数**: `getManyWithPathParams`不支持排序和过滤
- ❌ **日志记录**: 缺少LogUtils日志记录
- ❌ **字段命名兼容**: 不支持snake_case和camelCase双命名支持

#### 代码质量问题
- 错误消息不够具体
- 缺少详细的注释说明
- parseIdsArray方法缺失

### 2. Models层差异

#### ORM注解问题
- ❌ **@ORMField注解不完整**: 只有部分字段有注解
- ❌ **缺少@DataAssist注解**: 缺少`@DataAssist[fields]`注解
- ❌ **字段可见性错误**: 使用`public var`而非`private var`
- ❌ **构造函数缺失**: 缺少完整的带参构造函数

#### JSON序列化问题
- toJson方法混合使用camelCase和snake_case
- 缺少对Optional字段的正确处理

### 3. Services层差异

#### 缺失方法
- ❌ **批量操作**: `updateMultiple`, `deleteMultiple`, `restoreMultiple`
- ❌ **高级查询**: `getListWithSkip`, `getAllList`, `searchByCondition`, `getByGroupId`, `getByIds`
- ❌ **状态管理**: `updateStatus`方法
- ❌ **统计方法**: `countByUser`, `countAll`

#### 功能缺失
- sort和filter参数支持
- 详细的日志记录

### 4. DAO层差异

#### 接口设计问题
- ❌ **未继承RootDAO**: UctooUserDAO不继承RootDAO接口
- ❌ **查询方法不足**: 缺少`findByLink`, `findByCreatorPage`, `findByConditionPage`, `findByGroupId`, `findByIds`
- ❌ **更新方法不足**: 缺少`updateStatus`专门方法
- ❌ **统计方法不足**: 缺少`countByCreator`方法

### 5. Routes层差异

#### 路由设计问题
- ❌ **注册方式不一致**: 使用静态方法而非实例方法
- ❌ **skip路由缺失**: 缺少`/:limit/:page/:skip`路由
- ❌ **路由顺序注释缺失**: 缺少单条查询必须在列表查询之前的说明

## 改进方案

### 方案一: 增强模板完整性(推荐)

参考batchCreateModuleFromDb.ts的实现思路,采用模板替换方式生成完整代码:

#### 1. 创建完整模板文件

为每一层创建包含所有标准功能的完整模板:

```
skills/crud-generator/templates/
├── controller-full.cj.tpl      # 包含批量操作、skip、sort/filter的完整controller
├── model-full.cj.tpl           # 包含完整注解、构造函数的model
├── service-full.cj.tpl         # 包含所有批量、统计方法的service
├── dao-full.cj.tpl             # 包含所有查询、统计方法的dao
└── route-full.cj.tpl           # 包含skip路由的route
```

#### 2. 模板变量替换策略

参考batchCreateModuleFromDb.ts的replaceService/replaceController/replaceRouter函数:

```typescript
// 关键替换变量
{TABLE_NAME}        // 表名 (如: uctoo_user)
{TABLE_NAME_CAMEL}  // 驼峰表名 (如: uctooUser)
{TABLE_NAME_PASCAL} // 帕斯卡表名 (如: UctooUser)
{DATABASE_NAME}     // 数据库名 (如: uctoo)
{FIELDS_SECTION}    // 字段定义部分(动态生成)
{INSERT_FIELDS}     // INSERT语句字段列表
{INSERT_VALUES}     // INSERT语句值列表
{UPDATE_SETS}       // UPDATE语句SET部分
{MAP_TO_ENTITY}     // mapToEntity方法字段映射
{TO_JSON_FIELDS}    // toJson方法字段序列化
```

#### 3. 字段动态生成逻辑

根据Prisma schema动态生成各部分的字段代码:

```typescript
// 字段类型映射
const typeMapping = {
  'String': { cjType: 'String', defaultValue: '""', optional: '?String', optionalDefault: 'None<String>' },
  'Int': { cjType: 'Int32', defaultValue: '0', optional: '?Int32', optionalDefault: 'None<Int32>' },
  'Float': { cjType: 'Float64', defaultValue: '0.0', optional: '?Float64', optionalDefault: 'None<Float64>' },
  'Boolean': { cjType: 'Bool', defaultValue: 'false', optional: '?Bool', optionalDefault: 'None<Bool>' },
  'DateTime': { cjType: 'DateTime', defaultValue: 'DateTime.now()', optional: '?DateTime', optionalDefault: 'None<DateTime>' }
};

// 生成Model字段
function generateModelFields(fields) {
  return fields.map(f => {
    const type = typeMapping[f.type];
    const annotation = f.isPrimaryKey 
      ? `@ORMField[true '${f.dbName}']` 
      : `@ORMField['${f.dbName}']`;
    const fieldType = f.isOptional ? type.optional : type.cjType;
    const defaultValue = f.isOptional ? type.optionalDefault : type.defaultValue;
    
    return `    ${annotation}
    private var ${f.camelName}: ${fieldType} = ${defaultValue}`;
  }).join('\n\n');
}

// 生成INSERT字段列表
function generateInsertFields(fields) {
  const nonIdFields = fields.filter(f => f.name !== 'id');
  return nonIdFields.map(f => f.dbName).join(', ');
}

// 生成INSERT值列表
function generateInsertValues(fields, entityVar) {
  const nonIdFields = fields.filter(f => f.name !== 'id');
  return nonIdFields.map(f => `\${arg(${entityVar}.${f.camelName})}`).join(', ');
}

// 生成mapToEntity方法
function generateMapToEntity(fields, entityName) {
  const mappings = fields.map(f => {
    if (f.type === 'DateTime') {
      return `        // ${f.camelName} is DateTime type, handled by database`;
    }
    const type = typeMapping[f.type];
    const castType = f.type === 'Int' ? 'Int32' : (f.type === 'Float' ? 'Float64' : type.cjType);
    const optionalWrap = f.isOptional ? `Some<${type.cjType}>` : '';
    
    return `        if (let Some(${f.camelName}) <- map.get("${f.dbName}")) {
            let ${f.camelName}${castType === 'String' ? 'Str' : castType} = ${f.camelName} as ${castType}
            if (let Some(v) <- ${f.camelName}${castType === 'String' ? 'Str' : castType}) {
                entity.${f.camelName} = ${f.isOptional ? `${optionalWrap}(v)` : 'v'}
            }
        }`;
  }).join('\n');
  
  return mappings;
}
```

#### 4. 代码区域标识处理

参考batchCreateModuleFromDb.ts的区域标识处理逻辑:

```typescript
const autoCodeStartStr = "//#region AutoCreateCode"
const autoCodeEndStr = "//#endregion AutoCreateCode"

function processExistingFile(targetPath, templateData) {
  if (fs.existsSync(targetPath)) {
    const targetData = fs.readFileSync(targetPath, 'utf8');
    const targetStart = targetData.indexOf(autoCodeStartStr);
    const targetEnd = targetData.indexOf(autoCodeEndStr);
    
    if (targetStart > -1 && targetEnd > targetStart) {
      // 保留定制代码,只更新自动生成区域
      const headStr = targetData.slice(0, targetStart);
      const footStr = targetData.slice(targetEnd);
      
      const tplStart = templateData.indexOf(autoCodeStartStr);
      const tplEnd = templateData.indexOf(autoCodeEndStr);
      const middleStr = templateData.slice(tplStart, tplEnd);
      
      return `${headStr}${middleStr}${footStr}`;
    }
  }
  return templateData;
}
```

### 方案二: 参考模板增强

在现有references基础上,创建更详细的参考模板:

#### 1. 增强controller-pattern.md

添加以下内容:
- 批量操作完整示例
- getManyWithSkip方法示例
- sort和filter参数处理示例
- parseIdsArray方法实现
- 字段双命名支持示例

#### 2. 增强model-pattern.md

添加以下内容:
- @DataAssist注解使用说明
- 完整构造函数示例
- 字段可见性最佳实践
- toJson方法规范

#### 3. 增强service-pattern.md

添加以下内容:
- 批量操作方法示例
- 高级查询方法示例
- 统计方法示例
- sort和filter参数处理

#### 4. 增强dao-pattern.md

添加以下内容:
- RootDAO继承说明
- 完整查询方法示例
- 条件查询构建示例
- 统计方法示例

#### 5. 增强route-pattern.md

添加以下内容:
- 实例方法注册模式
- skip路由配置
- 路由顺序最佳实践

## 实施步骤

### 阶段一: 创建完整模板(优先级: 高)

1. 创建`templates/`目录
2. 基于EntityController.cj创建`controller-full.cj.tpl`
3. 基于EntityPO.cj创建`model-full.cj.tpl`
4. 基于EntityService.cj创建`service-full.cj.tpl`
5. 基于EntityDAO.cj创建`dao-full.cj.tpl`
6. 基于EntityRoute.cj创建`route-full.cj.tpl`

### 阶段二: 实现生成脚本(优先级: 高)

1. 创建`scripts/generate-from-template.ts`
2. 实现Prisma schema解析
3. 实现字段动态生成逻辑
4. 实现模板变量替换
5. 实现代码区域标识处理

### 阶段三: 更新SKILL.md(优先级: 中)

1. 更新生成流程说明
2. 添加模板使用说明
3. 更新字段类型映射表
4. 添加批量操作说明

### 阶段四: 测试验证(优先级: 高)

1. 使用改进后的generator重新生成uctoo_user模块
2. 对比生成代码与entity模块的一致性
3. 测试所有CRUD功能
4. 测试批量操作功能
5. 测试sort和filter功能

## 预期效果

### 代码一致性

- ✅ 生成的代码与entity标准模块完全一致
- ✅ 所有标准功能完整实现
- ✅ 代码风格和注释规范统一

### 功能完整性

- ✅ 支持批量操作(编辑、删除、恢复)
- ✅ 支持skip参数查询
- ✅ 支持sort和filter参数
- ✅ 完整的统计方法
- ✅ 详细的日志记录

### 可维护性

- ✅ 代码区域标识清晰
- ✅ 定制代码不会被覆盖
- ✅ 模板易于理解和修改
- ✅ 生成过程可追溯

## 参考资源

- Entity标准模块: `src/app/models/uctoo/EntityPO.cj`等
- batchCreateModuleFromDb.ts: `apps/backend/src/app/helpers/batchCreateModuleFromDb.ts`
- Fountain ORM文档: ORM注解和查询方法
- UCTOO V4规范: API设计和代码规范

## 下一步行动

1. **立即执行**: 创建完整模板文件
2. **本周完成**: 实现生成脚本
3. **下周完成**: 测试验证和文档更新
