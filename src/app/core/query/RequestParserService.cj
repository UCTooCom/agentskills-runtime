/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.core.query

import std.collection.{ArrayList, HashMap, Map}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import magic.log.LogUtils

/**
 * 查询参数解析服务
 * 对应 uctoo v3 的 RequestParserService
 * 
 * 功能：
 * 1. 解析 filter 参数（JSON 字符串 → CompositeFilter 对象）
 * 2. 解析 sort 参数（逗号分隔字符串 → SortCondition 数组）
 * 3. 计算分页参数
 */
public class RequestParserService {
    
    /**
     * 解析查询参数
     * @param filterStr filter 参数字符串（JSON 格式）
     * @param sortStr sort 参数字符串（逗号分隔）
     * @param page 页码
     * @param pageSize 每页大小
     * @return 解析后的查询对象
     */
    public func parseQuery(
        filterStr: String,
        sortStr: String,
        page: Int32,
        pageSize: Int32
    ): ParsedQuery {
        let query = ParsedQuery()
        query.page = page
        query.pageSize = pageSize
        
        // 解析 filter
        if (!filterStr.isEmpty()) {
            query.filter = parseFilter(filterStr)
        }
        
        // 解析 sort
        if (!sortStr.isEmpty()) {
            query.sort = parseSort(sortStr)
        }
        
        return query
    }
    
    /**
     * 解析 filter 参数
     * 支持格式: {"name":{"contains":"test"},"status":{"equals":"active"}}
     * 
     * @param filterStr JSON 格式的 filter 字符串
     * @return 组合过滤条件
     */
    private func parseFilter(filterStr: String): ?CompositeFilter {
        try {
            LogUtils.info("RequestParserService", "Parsing filter: ${filterStr}")
            
            let jsonValue = JsonValue.fromStr(filterStr)
            if (!(jsonValue is JsonObject)) {
                LogUtils.info("RequestParserService", "Filter is not a JSON object")
                return None<CompositeFilter>
            }
            
            let jsonObj = jsonValue.asObject()
            let composite = CompositeFilter()
            composite.logic = "AND"
            
            // 遍历 JSON 对象的每个字段
            for ((field, value) in jsonObj.getFields()) {
                // 解析字段条件
                if (value is JsonObject) {
                    let conditionObj = value.asObject()
                    for ((op, opValue) in conditionObj.getFields()) {
                        let condition = FilterCondition()
                        condition.field = field
                        condition.op = op
                        condition.value = jsonValueToAny(opValue)
                        composite.conditions.add(condition)
                        
                        LogUtils.info("RequestParserService", "Added condition: ${field} ${op}")
                    }
                }
            }
            
            LogUtils.info("RequestParserService", "Parsed ${composite.conditions.size} conditions")
            return Some<CompositeFilter>(composite)
        } catch (e: Exception) {
            LogUtils.error("RequestParserService", "Failed to parse filter: ${e.message}")
            return None<CompositeFilter>
        }
    }
    
    /**
     * 解析 sort 参数
     * 支持格式: "-created_at,name" (负号表示降序)
     * 
     * @param sortStr 逗号分隔的 sort 字符串
     * @return 排序条件数组
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
                condition.field = trimmed[1..]  // 从索引1开始到结尾
                condition.direction = "desc"
            } else {
                condition.field = trimmed
                condition.direction = "asc"
            }
            
            sortList.add(condition)
            LogUtils.info("RequestParserService", "Added sort: ${condition.field} ${condition.direction}")
        }
        
        return sortList
    }
    
    /**
     * JSON 值转换为 Any
     * 支持 String, Int, Float, Bool, Array
     * 
     * @param value JSON 值
     * @return Any 类型的值
     */
    private func jsonValueToAny(value: JsonValue): Any {
        if (value is JsonString) {
            return value.asString().getValue()
        } else if (value is JsonInt) {
            return value.asInt().getValue()
        } else if (value is JsonFloat) {
            return value.asFloat().getValue()
        } else if (value is JsonBool) {
            return value.asBool().getValue()
        } else if (value is JsonArray) {
            // 处理 in 操作符的数组
            let arr = value.asArray()
            let list = ArrayList<Any>()
            for (item in arr.getItems()) {
                list.add(jsonValueToAny(item))
            }
            return list
        } else {
            return ""
        }
    }
}
