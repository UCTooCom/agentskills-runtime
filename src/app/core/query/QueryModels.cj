/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.core.query

import std.collection.{ArrayList, HashMap}

/**
 * 过滤条件模型
 * 对应 Prisma 的 WHERE 条件
 * 
 * 示例: {"name": {"contains": "test"}}
 * 转换为: FilterCondition { field: "name", op: "contains", value: "test" }
 */
public class FilterCondition {
    public var field: String = ""
    public var op: String = ""  // equals, not, lt, lte, gt, gte, contains, in, isSet
    public var value: ?Any = None<Any>
    
    public init() {}
    
    public init(field: String, op: String, value: Any) {
        this.field = field
        this.op = op
        this.value = Some<Any>(value)
    }
}

/**
 * 组合过滤条件（支持 AND/OR）
 * 
 * 示例: {"classify": {"equals": "dev"}, "name": {"contains": "API"}}
 * 转换为: CompositeFilter { logic: "AND", conditions: [...] }
 */
public class CompositeFilter {
    public var logic: String = "AND"  // AND, OR
    public var conditions: ArrayList<FilterCondition> = ArrayList<FilterCondition>()
    public var composites: ArrayList<CompositeFilter> = ArrayList<CompositeFilter>()
    
    public init() {}
    
    public init(logic: String) {
        this.logic = logic
    }
}

/**
 * 排序条件
 * 
 * 示例: "-created_at,name"
 * 转换为: [SortCondition { field: "created_at", direction: "desc" }, SortCondition { field: "name", direction: "asc" }]
 */
public class SortCondition {
    public var field: String = ""
    public var direction: String = "asc"  // asc, desc
    
    public init() {}
    
    public init(field: String, direction: String) {
        this.field = field
        this.direction = direction
    }
}

/**
 * 解析后的查询对象
 * 包含分页、过滤和排序信息
 */
public class ParsedQuery {
    public var page: Int32 = 1
    public var pageSize: Int32 = 10
    public var filter: ?CompositeFilter = None<CompositeFilter>
    public var sort: ArrayList<SortCondition> = ArrayList<SortCondition>()
    
    public init() {}
}
