# CRUD代码生成器重构规范

## 1. 问题分析

### 1.1 当前问题
- 当前crudgen生成的代码与标准CRUD模块代码完全不一致
- 生成的字段重复、类型错误、格式混乱
- 缺乏模板机制,代码生成逻辑不可控

### 1.2 根本原因
- 没有使用模板文件作为代码生成基础
- 字段映射逻辑错误,导致重复生成
- 类型推断不准确
- 缺少对标准CRUD模块代码格式的严格遵循

## 2. 解决方案

### 2.1 核心思路
采用**模板变量替换方案**,参考backend v3的`batchCreateModuleFromDb.ts`实现:

1. **模板文件**: 为每个层(Model/DAO/Service/Controller/Route)创建标准模板文件
2. **变量替换**: 使用占位符(如`{{tableName}}`, `{{fields}}`)进行变量替换
3. **增量更新**: 保留自定义代码区域,只更新`AutoCreateCode`区域

### 2.2 技术架构

```
crudgen/
├── templates/              # 模板文件目录
│   ├── Model.cj.tpl       # Model层模板
│   ├── DAO.cj.tpl         # DAO层模板
│   ├── Service.cj.tpl     # Service层模板
│   ├── Controller.cj.tpl  # Controller层模板
│   └── Route.cj.tpl       # Route层模板
├── CrudGenerator.cj       # 核心生成器
├── TemplateEngine.cj      # 模板引擎
├── FieldMapper.cj         # 字段映射器
└── crudgen.cj            # 命令行入口
```

## 3. 详细设计

### 3.1 模板文件设计

#### 3.1.1 Model模板 (Model.cj.tpl)
```cangjie
/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.models.{{dbName}}

//#region AutoCreateCode

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_data.macros.DataAssist
import f_data.{ObjectData, Data, DataConversionFlag, ObjectFields, MutableField, DataObject, f_data_tryFromData}
import f_orm.*
import json4cj.JsonValueSerializable
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull}

/**
 * {{className}}PO - {{tableName}}表持久化对象
 * 
 * 对应数据库表: {{tableName}}
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["{{tableName}}"]
public class {{className}}PO {
{{fields}}
    
    public init() {}
    
    public init(
{{constructorParams}}
    ) {
{{constructorAssignments}}
    }
    
    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
{{toJsonMappings}}
        return JsonObject(map)
    }
    
    /// 辅助方法：将 Option<T> 转换为 JsonValue
    private static func optionToJsonValue<T>(opt: Option<T>): JsonValue where T <: JsonValueSerializable<T> {
        if (let Some(v) <- opt) {
            return v.toJsonValue()
        } else {
            return JsonNull()
        }
    }
    
    /// 序列化为 JSON 字符串
    public func toJson(): String {
        return this.toJsonValue().toString()
    }
    
//#endregion AutoCreateCode
}
```

#### 3.1.2 DAO模板 (DAO.cj.tpl)
基于标准EntityDAO.cj创建模板,包含:
- 插入操作
- 单条查询
- 更新操作
- 列表查询
- 软删除操作

#### 3.1.3 Service模板 (Service.cj.tpl)
基于标准EntityService.cj创建模板,包含:
- 创建记录
- 单条查询
- 更新记录
- 列表查询
- 软删除记录

#### 3.1.4 Controller模板 (Controller.cj.tpl)
基于标准EntityController.cj创建模板,包含:
- 创建记录
- 获取记录
- 更新记录
- 获取记录列表
- 删除记录

#### 3.1.5 Route模板 (Route.cj.tpl)
基于标准EntityRoute.cj创建模板,包含:
- 路由配置
- 中间件应用

### 3.2 字段映射规则

#### 3.2.1 数据库类型到仓颉类型映射
```cangjie
func mapDataType(dbType: String, isNullable: String): String {
    let baseType = match (dbType.toLowerCase()) {
        case "uuid" => "String"
        case "text" => "String"
        case "character varying" => "String"
        case "varchar" => "String"
        case "integer" => "Int32"
        case "smallint" => "Int32"
        case "bigint" => "Int64"
        case "numeric" => "Float64"
        case "real" => "Float32"
        case "double precision" => "Float64"
        case "boolean" => "Bool"
        case "timestamp with time zone" => "DateTime"
        case "timestamp" => "DateTime"
        case "date" => "DateTime"
        case "time" => "DateTime"
        case "json" => "String"
        case "jsonb" => "String"
        case _ => "String"
    }
    
    // 处理可空性
    if (isNullable == "YES") {
        return "Option<${baseType}>"
    } else {
        return baseType
    }
}
```

#### 3.2.2 默认值生成规则
```cangjie
func getDefaultValue(dbType: String, isNullable: String): String {
    if (isNullable == "YES") {
        return "None<${mapDataType(dbType, isNullable)}>()"
    } else {
        match (dbType.toLowerCase()) {
            case "integer" | "smallint" => "0"
            case "bigint" => "0"
            case "numeric" | "real" | "double precision" => "0.0"
            case "boolean" => "false"
            case "timestamp" | "date" | "time" => "DateTime.now()"
            case _ => "\"\""
        }
    }
}
```

### 3.3 模板变量

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `{{dbName}}` | 数据库名 | uctoo |
| `{{tableName}}` | 表名 | entity |
| `{{className}}` | 类名(帕斯卡命名) | Entity |
| `{{fields}}` | 字段定义代码块 | 见下方详细说明 |
| `{{constructorParams}}` | 构造函数参数 | 见下方详细说明 |
| `{{constructorAssignments}}` | 构造函数赋值 | 见下方详细说明 |
| `{{toJsonMappings}}` | JSON映射代码 | 见下方详细说明 |

### 3.4 代码生成流程

```
1. 读取db_info表获取表结构信息
   ↓
2. 解析字段信息,生成字段映射
   ↓
3. 加载对应层的模板文件
   ↓
4. 执行变量替换生成代码
   ↓
5. 检查目标文件是否存在
   ├─ 存在: 保留自定义代码,只更新AutoCreateCode区域
   └─ 不存在: 直接写入完整代码
   ↓
6. 写入目标文件
```

### 3.5 增量更新机制

参考backend v3的实现:
```cangjie
func updateFile(targetPath: String, newContent: String): Unit {
    let autoCodeStart = "//#region AutoCreateCode"
    let autoCodeEnd = "//#endregion AutoCreateCode"
    
    if (fileExists(targetPath)) {
        let existingContent = readFile(targetPath)
        let startIdx = existingContent.indexOf(autoCodeStart)
        let endIdx = existingContent.indexOf(autoCodeEnd)
        
        if (startIdx > 0 && endIdx > startIdx) {
            // 保留头部和尾部自定义代码
            let header = existingContent.substring(0, startIdx)
            let footer = existingContent.substring(endIdx)
            
            // 提取新生成的代码中间部分
            let newStartIdx = newContent.indexOf(autoCodeStart)
            let newEndIdx = newContent.indexOf(autoCodeEnd)
            let newMiddle = newContent.substring(newStartIdx, newEndIdx)
            
            // 组合: 头部 + 新代码 + 尾部
            let finalContent = header + newMiddle + footer
            writeFile(targetPath, finalContent)
        } else {
            // 没有AutoCreateCode标记,直接覆盖
            writeFile(targetPath, newContent)
        }
    } else {
        // 文件不存在,直接写入
        writeFile(targetPath, newContent)
    }
}
```

## 4. 实现步骤

### 4.1 第一阶段: 创建模板文件
1. 从标准CRUD模块代码提取模板
2. 创建5个模板文件(Model/DAO/Service/Controller/Route)
3. 验证模板文件的正确性

### 4.2 第二阶段: 实现模板引擎
1. 实现变量替换功能
2. 实现字段映射功能
3. 实现增量更新功能

### 4.3 第三阶段: 重构生成器
1. 重构CrudGenerator.cj使用模板引擎
2. 移除旧的代码生成逻辑
3. 确保生成的代码与标准模块完全一致

### 4.4 第四阶段: 测试验证
1. 使用entity表测试生成
2. 对比生成的代码与标准代码
3. 确保完全一致

## 5. 质量保证

### 5.1 代码一致性检查
- 生成的代码必须与标准CRUD模块代码格式完全一致
- 字段顺序必须与db_info表中的ordinal_position一致
- 类型映射必须准确无误
- 命名规范必须统一(驼峰/帕斯卡)

### 5.2 功能完整性检查
- 所有CRUD操作必须完整实现
- 软删除功能必须正确实现
- 分页查询必须正确实现
- JSON序列化必须正确实现

### 5.3 编译验证
- 生成的代码必须能够编译通过
- 生成的代码必须能够正常运行
- 生成的代码必须能够正确访问数据库

## 6. 预期成果

### 6.1 功能目标
- 运行`crudgen --db uctoo --table entity`生成的代码与标准Entity模块代码完全一致
- 支持增量更新,保留自定义代码
- 支持所有标准CRUD操作

### 6.2 质量目标
- 代码格式100%一致
- 字段映射100%准确
- 编译通过率100%
- 功能完整性100%

## 7. 风险控制

### 7.1 技术风险
- 模板文件格式错误 → 使用标准代码作为模板基础
- 变量替换逻辑错误 → 充分测试各种场景
- 增量更新逻辑错误 → 严格遵循backend v3实现

### 7.2 兼容性风险
- 新旧代码格式不兼容 → 完全重构,不保留旧代码
- 数据库结构变化 → 从db_info表动态读取,自动适应

## 8. 时间规划

- 第一阶段: 创建模板文件 (1天)
- 第二阶段: 实现模板引擎 (1天)
- 第三阶段: 重构生成器 (1天)
- 第四阶段: 测试验证 (0.5天)

总计: 3.5天

## 9. 验收标准

### 9.1 必须满足
1. 生成的EntityPO.cj与标准EntityPO.cj完全一致
2. 生成的EntityDAO.cj与标准EntityDAO.cj完全一致
3. 生成的EntityService.cj与标准EntityService.cj完全一致
4. 生成的EntityController.cj与标准EntityController.cj完全一致
5. 生成的EntityRoute.cj与标准EntityRoute.cj完全一致

### 9.2 验证方法
```bash
# 生成代码
crudgen --db uctoo --table entity

# 对比文件
diff src/app/models/uctoo/EntityPO.cj D:\UCT\products\gitcode\agentskills-runtime\src\app\models\uctoo\EntityPO.cj
diff src/app/dao/uctoo/EntityDAO.cj D:\UCT\products\gitcode\agentskills-runtime\src\app\dao\uctoo\EntityDAO.cj
diff src/app/services/uctoo/EntityService.cj D:\UCT\products\gitcode\agentskills-runtime\src\app\services\uctoo\EntityService.cj
diff src/app/controllers/uctoo/entity/EntityController.cj D:\UCT\products\gitcode\agentskills-runtime\src\app\controllers\uctoo\entity\EntityController.cj
diff src/app/routes/uctoo/entity/EntityRoute.cj D:\UCT\products\gitcode\agentskills-runtime\src\app\routes\uctoo\entity\EntityRoute.cj

# 所有diff应该无差异
```

---

**请审核此规范方案,审核通过后我将开始实施重构。**
