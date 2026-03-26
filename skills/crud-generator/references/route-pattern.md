# Route Pattern Reference

Route layer pattern for UCToo V4, following the EntityRoute implementation.

## Overview

The Route layer provides:
- URL path registration
- HTTP method mapping
- Controller instantiation
- Middleware configuration

## File Structure

```
src/app/routes/{database}/{table}/{Table}Route.cj
```

## Basic Template

```cangjie
package magic.app.routes.{database}.{table}

import magic.app.core.router.Router
import magic.app.controllers.{database}.{table}.{Table}Controller
import magic.app.services.{database}.{Table}Service

/**
 * {Table}Route - {表描述}路由注册
 */
public class {Table}Route {
    public static func register(router: Router): Unit {
        let service = {Table}Service()
        let controller = {Table}Controller(service)
        
        // POST /api/v1/{database}/{table}/add - 新增
        router.post("/api/v1/{database}/{table}/add", controller.add)
        
        // POST /api/v1/{database}/{table}/edit - 编辑
        router.post("/api/v1/{database}/{table}/edit", controller.edit)
        
        // POST /api/v1/{database}/{table}/del - 删除
        router.post("/api/v1/{database}/{table}/del", controller.delete)
        
        // GET /api/v1/{database}/{table}/:id - 查询单条
        router.get("/api/v1/{database}/{table}/:id", controller.getSingle)
        
        // GET /api/v1/{database}/{table}/:limit/:page - 分页查询
        router.get("/api/v1/{database}/{table}/:limit/:page", controller.getManyWithPathParams)
    }
}
```

## Standard Routes

| Method | Path | Handler | Description |
|--------|------|---------|-------------|
| POST | /add | controller.add | 创建记录 |
| POST | /edit | controller.edit | 更新/恢复记录 |
| POST | /del | controller.delete | 删除记录 |
| GET | /:id | controller.getSingle | 查询单条 |
| GET | /:limit/:page | controller.getManyWithPathParams | 分页查询 |

## Route Registration

### In main.cj

```cangjie
import magic.app.routes.{database}.{table}.{Table}Route

main() {
    let router = Router()
    
    // Register all routes
    {Table}Route.register(router)
    
    // Start server
    let server = HTTPServer(router)
    server.start(8080)
}
```

### Multiple Routes

```cangjie
import magic.app.routes.uctoo.entity.EntityRoute
import magic.app.routes.uctoo.link.LinkRoute
import magic.app.routes.uctoo.group.GroupRoute

main() {
    let router = Router()
    
    // Register all module routes
    EntityRoute.register(router)
    LinkRoute.register(router)
    GroupRoute.register(router)
    
    let server = HTTPServer(router)
    server.start(8080)
}
```

## Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| :id | String | Record UUID |
| :limit | Int32 | Page size (max 100) |
| :page | Int32 | Page number (1-based) |

## URL Examples

```
POST   /api/v1/uctoo/entity/add              # Create
POST   /api/v1/uctoo/entity/edit             # Update
POST   /api/v1/uctoo/entity/del              # Delete
GET    /api/v1/uctoo/entity/abc-123-def      # Get by ID
GET    /api/v1/uctoo/entity/10/1             # Page 1, 10 items
GET    /api/v1/uctoo/entity/20/2             # Page 2, 20 items
```

## Middleware (Optional)

Add authentication middleware if required:

```cangjie
import magic.app.middlewares.auth.requireUser

public class {Table}Route {
    public static func register(router: Router): Unit {
        let service = {Table}Service()
        let controller = {Table}Controller(service)
        
        // Public routes (no auth)
        router.get("/api/v1/{database}/{table}/:id", controller.getSingle)
        router.get("/api/v1/{database}/{table}/:limit/:page", controller.getManyWithPathParams)
        
        // Protected routes (require auth)
        router.post("/api/v1/{database}/{table}/add", requireUser, controller.add)
        router.post("/api/v1/{database}/{table}/edit", requireUser, controller.edit)
        router.post("/api/v1/{database}/{table}/del", requireUser, controller.delete)
    }
}
```

## pkg.cj Export

Create export file for the route:

```cangjie
// src/app/routes/{database}/pkg.cj
public import magic.app.routes.{database}.{table}.{Table}Route
```

## Design Principles

1. **Static register method**: Consistent interface for all routes
2. **Instantiate dependencies**: Service and Controller created in register
3. **Use path parameters**: :id, :limit, :page for dynamic values
4. **Follow REST conventions**: POST for mutations, GET for queries
5. **Group by module**: One Route class per table

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Class name | PascalCase + Route | EntityRoute |
| File name | PascalCase + Route.cj | EntityRoute.cj |
| Directory | lowercase table name | entity/ |
| URL path | lowercase | /api/v1/uctoo/entity |
