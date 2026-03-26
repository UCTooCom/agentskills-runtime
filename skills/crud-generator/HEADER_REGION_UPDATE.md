# CRUD Generator 头部保留区域更新说明

## 更新概述

为所有模板添加了头部自定义引入区域，确保自定义的import语句不会被代码生成覆盖。

## 更新内容

### 1. 模板文件更新 ✅

所有模板文件都添加了两层保护机制：

#### 更新前
```cangjie
/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.{DATABASE_NAME}.{TABLE_NAME}

import magic.app.core.http.{HttpRequest, HttpResponse}
// ... 标准import ...

public class {TABLE_NAME_PASCAL}Controller {
    //#region AutoCreateCode
    // ... 自动生成代码 ...
    //#endregion AutoCreateCode
}
```

#### 更新后
```cangjie
/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.{DATABASE_NAME}.{TABLE_NAME}

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import magic.app.core.http.{HttpRequest, HttpResponse}
// ... 标准import ...

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

public class {TABLE_NAME_PASCAL}Controller {
    //#region AutoCreateCode
    // ... 自动生成代码 ...
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
```

### 2. 更新的模板文件

- ✅ `templates/controller-full.cj.tpl` - Controller模板
- ✅ `templates/model-full.cj.tpl` - Model模板
- ✅ `templates/dao-full.cj.tpl` - DAO模板
- ✅ `templates/service-full.cj.tpl` - Service模板
- ✅ `templates/route-full.cj.tpl` - Route模板

### 3. 生成脚本更新 ✅

更新了 `scripts/generate-from-template.ts` 中的 `writeFileSync` 函数，支持：

1. **检测头部自定义引入区域**
2. **保留自定义import语句**
3. **检测尾部定制开发区域**
4. **保留自定义方法实现**

### 4. 文档更新 ✅

更新了 `SKILL.md`，添加了：
- 两层保护机制说明
- 头部引入区域使用示例
- 重新生成行为详细说明
- 各层标识支持情况表格

## 两层保护机制

### 第一层：头部自定义引入区域

**标识符**：
```cangjie
// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========
```

**用途**：保护自定义的import引入语句

**位置**：在package声明之后，标准import之前

**示例**：
```cangjie
// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import magic.app.utils.CustomUtils
import magic.app.services.external.ExternalService
import magic.app.models.custom.CustomModel

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
```

### 第二层：尾部定制开发区域

**标识符**：
```cangjie
//#region AutoCreateCode
// ... 自动生成代码 ...
//#endregion AutoCreateCode

// ========== 定制开发方法（在此区域添加自定义方法）==========
```

**用途**：保护自定义的方法实现

**位置**：在类定义内部

**示例**：
```cangjie
//#endregion AutoCreateCode

// ========== 定制开发方法（在此区域添加自定义方法）==========

public func customMethod(param: String): Result {
    // 自定义业务逻辑
}
```

## 使用场景

### 场景1：添加自定义工具类

```cangjie
// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import magic.app.utils.{StringUtils, DateUtils}
import magic.app.services.external.ExternalApiService

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
```

### 场景2：引入第三方库

```cangjie
// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import third.party.library.{HttpClient, JsonParser}
import external.sdk.{ApiClient, Config}

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
```

### 场景3：引入其他模块

```cangjie
// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import magic.app.models.other.{OtherModel, RelatedEntity}
import magic.app.services.cross.CrossModuleService

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
```

## 重新生成行为

当使用crud-generator重新生成代码时：

1. **首次生成**：
   - 创建包含完整标识区的新文件
   - 包含标准import和标准CRUD代码

2. **重新生成**：
   - 检测并保留头部自定义引入区域
   - 检测并保留尾部定制开发区域
   - 只更新自动生成代码区域

3. **保护机制**：
   - 自定义import不会被覆盖
   - 自定义方法不会被覆盖
   - 只更新标准CRUD代码

## 各层支持情况

| 层级 | 头部引入区 | 尾部方法区 | 说明 |
|------|-----------|-----------|------|
| Model | ✅ | ❌ | 支持自定义import，字段变更时需要整体更新 |
| DAO | ✅ | ✅ | 支持自定义import和查询方法 |
| Service | ✅ | ✅ | 支持自定义import和业务逻辑 |
| Controller | ✅ | ✅ | 支持自定义import和接口方法 |
| Route | ✅ | ✅ | 支持自定义import和路由配置 |

## 参考实现

本更新参考了backend v3版本的模板实现：

- `apps/backend/src/app/services/uctoo/db_entity.ts.tpl`
- `apps/backend/src/app/controllers/uctoo/entity/db_index.ts.tpl`
- `apps/backend/src/app/routes/uctoo/entity/db_index.ts.tpl`

这些模板都使用了 `//#region AutoCreateCode` 标识符来保护自动生成代码区域。

## 优势

1. **更灵活的定制**：支持在头部添加自定义import
2. **更安全的生成**：两层保护机制确保定制代码不被覆盖
3. **更好的可维护性**：清晰的标识区划分，易于理解
4. **向后兼容**：保留原有的尾部定制开发区域功能

## 总结

通过添加头部自定义引入区域，crud-generator现在提供了完整的两层保护机制：

- **头部保护**：保护自定义import语句
- **尾部保护**：保护自定义方法实现

这使得开发者可以安全地添加自定义依赖和业务逻辑，而不用担心被代码生成器覆盖。
