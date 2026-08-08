---
name: loaddbinfo
description: 数据库信息加载技能。将数据库表结构信息加载到db_info表中，供crud-generator等代码生成工具读取。当用户需要同步数据库结构、更新db_info表、或在使用crudgen前准备数据时使用。触发词："加载数据库信息"、"同步表结构"、"loaddbinfo"、"load db info"。
version: 1.0.0
author: OpenCangjie Team
inputs:
  - name: database
    type: string
    required: true
    description: 要加载数据库信息的数据库名称
  - name: tables
    type: string[]
    required: false
    description: 指定要加载的表名列表（为空则加载全部表）
outputs:
  - name: loaded_tables
    type: string[]
    description: 成功加载的表名列表
  - name: table_count
    type: integer
    description: 加载的表数量
  - name: column_count
    type: integer
    description: 加载的列数量
dependencies: []
---

# LoadDbInfo 技能

## 概述

将数据库表结构信息加载到db_info表中，供crud-generator等代码生成工具读取使用。

## 核心功能

1. **数据库结构同步**: 读取数据库中所有表的结构信息（表名、列名、类型、约束等）
2. **db_info表写入**: 将结构信息写入db_info表，供crudgen读取
3. **增量更新**: 仅更新有变化的表结构信息

## 使用方式

### 通过RESTful API调用

```
POST /api/loaddbinfo
{
  "database": "uctoo",
  "tables": []  // 空数组表示加载全部表
}
```

### 通过CLI工具调用

```bash
# 加载指定数据库的全部表结构
magic.app.tools.loaddbinfo.exe --db uctoo

# 加载指定表
magic.app.tools.loaddbinfo.exe --db uctoo --tables entity,user,role
```

## 实现位置

- **LoadDbInfoService**: `src/app/tools/loaddbinfo/LoadDbInfoService.cj`
- **CLI入口**: `src/app/tools/loaddbinfo/loaddbinfo.cj`

## 工作原理

1. 连接到指定数据库
2. 读取information_schema获取表结构
3. 将结构信息写入db_info表
4. 返回加载结果统计

## 注意事项

- 加载前需确保数据库连接配置正确
- db_info表需提前创建
- 加载操作是幂等的，重复执行不会产生重复数据