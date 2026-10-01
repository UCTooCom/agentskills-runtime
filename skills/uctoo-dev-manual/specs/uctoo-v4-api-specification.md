# V4 API 规范

> 本文档是 V4 API 规范的快速参考。完整规范见 `docs/uctoo-v4/uctoo-v4-api-specification.md`。

## 列表键名约定（§8.2）

**列表数据的键名为表名加 `s`（复数形式）**：

| 表名 | 列表键名 | 示例 |
|------|----------|------|
| `entity` | `entitys` | `{"entitys": [...]}` |
| `codelabs` | `codelabss` | `{"codelabss": [...]}` |

## V4 列表格式

```json
{
    "currentPage": 1,
    "totalCount": 56,
    "totalPage": 6,
    "entitys": [...]
}
```

## V4 API 端点（以 codelabs 为例）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/uctoo/codelabs/:limit/:page` | 分页列表 |
| GET | `/api/v1/uctoo/codelabs/:id` | 单条查询 |
| POST | `/api/v1/uctoo/codelabs/add` | 创建 |
| POST | `/api/v1/uctoo/codelabs/edit` | 更新（含批量/恢复） |
| POST | `/api/v1/uctoo/codelabs/del` | 删除（含批量/硬删） |
| POST | `/api/v1/uctoo/codelabs/empty-recycle-bin` | 清空回收站 |

## 筛选与回收站

Web 前端通过 `filter` 查询参数区分普通模式与回收站模式：

- 普通模式：`filter={"deleted_at":null}` → WHERE `deleted_at IS NULL`
- 回收站模式：`filter={"deleted_at":{"not":null}}` → WHERE `deleted_at IS NOT NULL`

## 错误码格式

```json
{
    "errno": 40001,
    "errmsg": "提交数据格式错误"
}
```

## 完整规范文档

- [V4 API 规范](../../../docs/uctoo-v4/uctoo-v4-api-specification.md)
- [V4 架构规范](../../../docs/uctoo-v4/uctoo-v4-architecture.md)
- [V4 模块开发规范](../../../docs/uctoo-v4/uctoo-v4-module-development.md)
- [V4 ORM 规范](../../../docs/uctoo-v4/uctoo-v4-orm-specification.md)
- [V4 中间件指南](../../../docs/uctoo-v4/uctoo-v4-middleware-guide.md)
- [数据库设计规范](../../../docs/uctoo-v4/uctoo-database-design-specification.md)
- [权限体系规范](../../../docs/uctoo-v4/user-permission-system.md)
- [行级权限系统](../../../docs/uctoo-v4/row-level-permission-system.md)
