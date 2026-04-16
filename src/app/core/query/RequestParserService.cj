/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.core.query

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull}
import magic.log.LogUtils

/**
 * 查询参数解析服务
 * 
 * 解析 Prisma 风格的查询参数，支持：
 * - filter: JSON 格式的过滤条件
 * - sort: 逗号分隔的排序字段
 * - page: 页码
 * - pageSize: 每页大小
 */
public class RequestParserService {
    
    /**
     * 解析查询参数
     * 
     * @param filterStr filter 参数字符串（JSON 格式）
     * @param sortStr sort 参数字符串（逗号分隔）
     * @param page 页码
     * @param pageSize 每页大小
     * @return 解析后的查询对象
     */
    public func parseQuery(
        filterStr: String,
        sortStr: String,
        page: Int64,
        pageSize: Int64
    ): ParsedQuery {
        let query = ParsedQuery()
        query.page = page
        query.pageSize = pageSize
        
        // 解析 filter
        if (!filterStr.isEmpty()) {
            try {
                query.filter = parseFilter(filterStr)
            } catch (e: Exception) {
                LogUtils.error("RequestParserService", "Failed to parse filter: ${e.message}")
            }
        }
        
        // 解析 sort
        if (!sortStr.isEmpty()) {
            query.sort = parseSort(sortStr)
        }
        
        return query
    }
    
    /**
     * 解析 filter 参数
     * 
     * 支持格式:
     * - 简单条件: {"name": {"contains": "test"}}
     * - 多个条件: {"name": {"contains": "test"}, "status": {"equals": "active"}}
     * - AND 条件: {"AND": [{"name": {"contains": "test"}}, {"status": {"equals": "active"}}]}
     * - OR 条件: {"OR": [{"name": {"contains": "test"}}, {"status": {"equals": "active"}}]}
     * - NOT 条件: {"NOT": {"status": {"equals": "deleted"}}}
     */
    private func parseFilter(filterStr: String): ?CompositeCondition {
        try {
            // 直接使用filterStr，因为在控制器中已经处理了URL解码
            LogUtils.info("RequestParserService", "Raw filter: ${filterStr}")
            
            let jsonValue = JsonValue.fromStr(filterStr)
            if (!(jsonValue is JsonObject)) {
                LogUtils.info("RequestParserService", "Filter is not a JSON object")
                return None<CompositeCondition>
            }
            
            let jsonObj = jsonValue.asObject()
            return parseJsonObject(jsonObj)
        } catch (e: Exception) {
            LogUtils.error("RequestParserService", "Failed to parse filter JSON: ${e.message}")
            return None<CompositeCondition>
        }
    }
    
    /**
     * 解析 JSON 对象为组合条件
     */
    private func parseJsonObject(jsonObj: JsonObject): CompositeCondition {
        let composite = CompositeCondition()
        composite.logic = LogicOperator.And  // 默认为 AND
        
        // 遍历 JSON 对象的每个字段
        for ((key, value) in jsonObj.getFields()) {
            // 检查是否是逻辑操作符
            if (key == "AND" || key == "OR" || key == "NOT") {
                // 解析逻辑组合条件
                let logicOp = if (key == "AND") {
                    LogicOperator.And
                } else if (key == "OR") {
                    LogicOperator.Or
                } else {
                    LogicOperator.Not
                }
                
                let nestedComposite = parseLogicCondition(value, logicOp)
                if (!nestedComposite.isEmpty()) {
                    composite.addCompositeCondition(nestedComposite)
                }
            } else {
                // 解析字段条件
                let fieldCondition = parseFieldCondition(key, value)
                if (let Some(condition) <- fieldCondition) {
                    composite.addFieldCondition(condition)
                }
            }
        }
        
        return composite
    }
    
    /**
     * 解析逻辑组合条件
     */
    private func parseLogicCondition(value: JsonValue, logic: LogicOperator): CompositeCondition {
        let composite = CompositeCondition(logic)
        
        if (value is JsonArray) {
            // AND/OR 条件通常是数组
            let arr = value.asArray()
            for (item in arr.getItems()) {
                if (item is JsonObject) {
                    let nestedComposite = parseJsonObject(item.asObject())
                    if (!nestedComposite.isEmpty()) {
                        composite.addCompositeCondition(nestedComposite)
                    }
                }
            }
        } else if (value is JsonObject) {
            // NOT 条件通常是单个对象
            let nestedComposite = parseJsonObject(value.asObject())
            if (!nestedComposite.isEmpty()) {
                composite.addCompositeCondition(nestedComposite)
            }
        }
        
        return composite
    }
    
    /**
     * 解析字段条件
     * 
     * 格式: { "operator": value }
     * 例如: { "contains": "test" }
     */
    private func parseFieldCondition(field: String, value: JsonValue): ?FieldCondition {
        if (!(value is JsonObject)) {
            // 简单值，默认为 equals 操作符
            let queryValue = jsonValueToQueryValue(value)
            if (let Some(v) <- queryValue) {
                return Some<FieldCondition>(FieldCondition(field, QueryOperator.Equals, v))
            }
            return None<FieldCondition>
        }
        
        let conditionObj = value.asObject()
        
        // 遍历操作符
        for ((op, opValue) in conditionObj.getFields()) {
            let queryOp = parseOperator(op)
            if (let Some(parsedOp) <- queryOp) {
                let queryValue = jsonValueToQueryValue(opValue)
                if (let Some(v) <- queryValue) {
                    return Some<FieldCondition>(FieldCondition(field, parsedOp, v))
                }
            }
        }
        
        return None<FieldCondition>
    }
    
    /**
     * 解析操作符字符串
     */
    private func parseOperator(opStr: String): ?QueryOperator {
        match (opStr) {
            case "equals" => return Some<QueryOperator>(QueryOperator.Equals)
            case "not" => return Some<QueryOperator>(QueryOperator.Not)
            case "lt" => return Some<QueryOperator>(QueryOperator.Lt)
            case "lte" => return Some<QueryOperator>(QueryOperator.Lte)
            case "gt" => return Some<QueryOperator>(QueryOperator.Gt)
            case "gte" => return Some<QueryOperator>(QueryOperator.Gte)
            case "contains" => return Some<QueryOperator>(QueryOperator.Contains)
            case "startsWith" => return Some<QueryOperator>(QueryOperator.StartsWith)
            case "endsWith" => return Some<QueryOperator>(QueryOperator.EndsWith)
            case "in" => return Some<QueryOperator>(QueryOperator.In)
            case "notIn" => return Some<QueryOperator>(QueryOperator.NotIn)
            case "isSet" => return Some<QueryOperator>(QueryOperator.IsSet)
            case "between" => return Some<QueryOperator>(QueryOperator.Between)
            case "notBetween" => return Some<QueryOperator>(QueryOperator.NotBetween)
            case _ => return None<QueryOperator>
        }
    }
    
    /**
     * JSON 值转换为 QueryValue
     */
    private func jsonValueToQueryValue(value: JsonValue): ?QueryValue {
        if (value is JsonString) {
            return Some<QueryValue>(QueryValue(value.asString().getValue()))
        } else if (value is JsonInt) {
            return Some<QueryValue>(QueryValue(value.asInt().getValue()))
        } else if (value is JsonFloat) {
            return Some<QueryValue>(QueryValue(value.asFloat().getValue()))
        } else if (value is JsonBool) {
            return Some<QueryValue>(QueryValue(value.asBool().getValue()))
        } else if (value is JsonNull) {
            return Some<QueryValue>(QueryValue())  // null 值
        } else if (value is JsonArray) {
            // 处理数组（用于 in、notIn、between 操作符）
            let arr = value.asArray()
            let queryValues = ArrayList<QueryValue>()
            for (item in arr.getItems()) {
                if (let Some(v) <- jsonValueToQueryValue(item)) {
                    queryValues.add(v)
                }
            }
            return Some<QueryValue>(QueryValue(queryValues))
        } else {
            return None<QueryValue>
        }
    }
    
    /**
     * 解析 sort 参数
     * 
     * 支持格式: "-created_at,name"
     * - 负号表示降序
     * - 逗号分隔多个字段
     */
    private func parseSort(sortStr: String): ArrayList<SortCondition> {
        let sortList = ArrayList<SortCondition>()
        
        let parts = sortStr.split(",")
        for (part in parts) {
            let trimmed = part.trimAscii()
            if (trimmed.isEmpty()) {
                continue
            }
            
            let condition = SortCondition()
            if (trimmed.startsWith("-")) {
                condition.field = trimmed[1..]
                condition.ascending = false
            } else {
                condition.field = trimmed
                condition.ascending = true
            }
            
            sortList.add(condition)
        }
        
        return sortList
    }
}
