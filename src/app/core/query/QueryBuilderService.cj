/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.core.query

import std.collection.ArrayList
import std.core.StringBuilder
import magic.log.LogUtils

/**
 * SQL 查询构建服务
 * 将 FilterCondition 转换为 SQL WHERE 子句
 * 
 * 功能：
 * 1. 构建 WHERE 子句（支持参数化查询）
 * 2. 构建 ORDER BY 子句
 * 3. 支持 Prisma 风格的操作符
 */
public class QueryBuilderService {
    
    /**
     * 构建 WHERE 子句
     * 
     * @param filter 过滤条件
     * @param args SQL 参数列表（输出参数）
     * @return WHERE 子句字符串（不包含 WHERE 关键字）
     * 
     * 示例：
     * 输入: CompositeFilter { logic: "AND", conditions: [FilterCondition { field: "name", operator: "contains", value: "test" }] }
     * 输出: "name like ?" (args: ["%test%"])
     */
    public func buildWhereClause(
        filter: CompositeFilter,
        args: ArrayList<Any>
    ): String {
        let sb = StringBuilder()
        
        let conditions = filter.conditions
        let size = conditions.size
        
        for (i in 0..size) {
            let condition = conditions[i]
            let clause = buildConditionClause(condition, args)
            
            if (!clause.isEmpty()) {
                if (sb.size > 0) {
                    sb.append(" ${filter.logic} ")
                }
                sb.append(clause)
            }
        }
        
        // 处理嵌套的组合条件
        let composites = filter.composites
        for (composite in composites) {
            let nestedClause = buildWhereClause(composite, args)
            if (!nestedClause.isEmpty()) {
                if (sb.size > 0) {
                    sb.append(" ${filter.logic} ")
                }
                sb.append("(${nestedClause})")
            }
        }
        
        return sb.toString()
    }
    
    /**
     * 构建单个条件子句
     * 
     * @param condition 过滤条件
     * @param args SQL 参数列表（输出参数）
     * @return SQL 条件子句
     * 
     * 支持的操作符：
     * - equals: 等于 (=)
     * - not: 不等于 (!=)
     * - lt: 小于 (<)
     * - lte: 小于等于 (<=)
     * - gt: 大于 (>)
     * - gte: 大于等于 (>=)
     * - contains: 包含 (like)
     * - in: 在列表中 (in)
     * - isSet: 字段是否设置 (is null / is not null)
     */
    private func buildConditionClause(
        condition: FilterCondition,
        args: ArrayList<Any>
    ): String {
        let field = condition.field
        let op = condition.op
        
        if (let Some(value) <- condition.value) {
            // equals: 等于
            if (op == "equals") {
                args.add(value)
                return "${field} = ?"
            }
            
            // not: 不等于
            if (op == "not") {
                args.add(value)
                return "${field} != ?"
            }
            
            // lt: 小于
            if (op == "lt") {
                args.add(value)
                return "${field} < ?"
            }
            
            // lte: 小于等于
            if (op == "lte") {
                args.add(value)
                return "${field} <= ?"
            }
            
            // gt: 大于
            if (op == "gt") {
                args.add(value)
                return "${field} > ?"
            }
            
            // gte: 大于等于
            if (op == "gte") {
                args.add(value)
                return "${field} >= ?"
            }
            
            // contains: 包含（模糊查询）
            if (op == "contains") {
                let strOpt = value as String
                if (let Some(str) <- strOpt) {
                    args.add("%${str}%")
                    return "${field} like ?"
                }
                return ""
            }
            
            // in: 在列表中
            if (op == "in") {
                let listOpt = value as ArrayList<Any>
                if (let Some(list) <- listOpt) {
                    let sb = StringBuilder()
                    let size = list.size
                    for (i in 0..size) {
                        args.add(list[i])
                        if (i > 0) {
                            sb.append(", ")
                        }
                        sb.append("?")
                    }
                    let inClause = sb.toString()
                    return "${field} in (${inClause})"
                }
                return ""
            }
            
            // isSet: 字段是否设置
            if (op == "isSet") {
                let boolOpt = value as Bool
                if (let Some(bool) <- boolOpt) {
                    if (bool) {
                        return "${field} is not null"
                    } else {
                        return "${field} is null"
                    }
                }
                return ""
            }
            
            // 未知操作符
            LogUtils.info("QueryBuilderService", "Unknown operator: ${op}")
            return ""
        }
        
        return ""
    }
    
    /**
     * 构建 ORDER BY 子句
     * 
     * @param sort 排序条件列表
     * @return ORDER BY 子句字符串（不包含 ORDER BY 关键字）
     * 
     * 示例：
     * 输入: [SortCondition { field: "created_at", direction: "desc" }, SortCondition { field: "name", direction: "asc" }]
     * 输出: "created_at desc, name asc"
     */
    public func buildOrderByClause(sort: ArrayList<SortCondition>): String {
        if (sort.isEmpty()) {
            return "created_at desc"  // 默认排序
        }
        
        let sb = StringBuilder()
        let size = sort.size
        
        for (i in 0..size) {
            let condition = sort[i]
            if (sb.size > 0) {
                sb.append(", ")
            }
            sb.append("${condition.field} ${condition.direction}")
        }
        
        return sb.toString()
    }
}
