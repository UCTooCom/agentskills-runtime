/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.core.query

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull}
import magic.log.LogUtils

/**
 * 查询操作符枚举
 * 对应 Prisma 风格的查询操作符
 */
public enum QueryOperator <: ToString {
    | Equals      // 等于
    | Not         // 不等于
    | Lt          // 小于
    | Lte         // 小于等于
    | Gt          // 大于
    | Gte         // 大于等于
    | Contains    // 包含（模糊查询）
    | StartsWith  // 以...开始
    | EndsWith    // 以...结束
    | In          // 在列表中
    | NotIn       // 不在列表中
    | IsSet       // 字段是否设置（null 检查）
    | Between     // 在范围内
    | NotBetween  // 不在范围内
    
    public func toString(): String {
        match (this) {
            case Equals => "equals"
            case Not => "not"
            case Lt => "lt"
            case Lte => "lte"
            case Gt => "gt"
            case Gte => "gte"
            case Contains => "contains"
            case StartsWith => "startsWith"
            case EndsWith => "endsWith"
            case In => "in"
            case NotIn => "notIn"
            case IsSet => "isSet"
            case Between => "between"
            case NotBetween => "notBetween"
        }
    }
}

/**
 * 逻辑操作符枚举
 */
public enum LogicOperator <: ToString {
    | And  // 与
    | Or   // 或
    | Not  // 非
    
    public func toString(): String {
        match (this) {
            case And => "AND"
            case Or => "OR"
            case Not => "NOT"
        }
    }
}

/**
 * 查询条件值
 * 支持多种数据类型
 */
public class QueryValue {
    public var stringValue: ?String = None<String>
    public var intValue: ?Int64 = None<Int64>
    public var floatValue: ?Float64 = None<Float64>
    public var boolValue: ?Bool = None<Bool>
    public var arrayValue: ?ArrayList<QueryValue> = None<ArrayList<QueryValue>>
    
    public init() {}
    
    public init(value: String) {
        this.stringValue = Some<String>(value)
    }
    
    public init(value: Int64) {
        this.intValue = Some<Int64>(value)
    }
    
    public init(value: Float64) {
        this.floatValue = Some<Float64>(value)
    }
    
    public init(value: Bool) {
        this.boolValue = Some<Bool>(value)
    }
    
    public init(value: ArrayList<QueryValue>) {
        this.arrayValue = Some<ArrayList<QueryValue>>(value)
    }
    
    /**
     * 判断是否为 null 值
     */
    public func isNull(): Bool {
        stringValue.isNone() && intValue.isNone() && floatValue.isNone() && boolValue.isNone() && arrayValue.isNone()
    }
    
    /**
     * 转換為字符串表示（用于日志）
     */
    public func toString(): String {
        if (let Some(v) <- stringValue) {
            return "\"${v}\""
        } else if (let Some(v) <- intValue) {
            return "${v}"
        } else if (let Some(v) <- floatValue) {
            return "${v}"
        } else if (let Some(v) <- boolValue) {
            return "${v}"
        } else if (let Some(v) <- arrayValue) {
            let sb = StringBuilder()
            sb.append("[")
            let size = v.size
            for (i in 0..size) {
                if (i > 0) {
                    sb.append(", ")
                }
                sb.append(v[i].toString())
            }
            sb.append("]")
            return sb.toString()
        } else {
            return "null"
        }
    }
}

/**
 * 单个查询条件
 * 格式: { "field": { "op": value } }
 * 例如: { "name": { "contains": "test" } }
 */
public class FieldCondition {
    public var field: String = ""
    public var op: QueryOperator = QueryOperator.Equals
    public var value: QueryValue = QueryValue()
    
    public init() {}
    
    public init(field: String, op: QueryOperator, value: QueryValue) {
        this.field = field
        this.op = op
        this.value = value
    }
    
    public func toString(): String {
        "${field} ${op} ${value.toString()}"
    }
}

/**
 * 组合查询条件
 * 支持 AND、OR、NOT 逻辑组合
 */
public class CompositeCondition {
    public var logic: LogicOperator = LogicOperator.And
    public var fieldConditions: ArrayList<FieldCondition> = ArrayList<FieldCondition>()
    public var compositeConditions: ArrayList<CompositeCondition> = ArrayList<CompositeCondition>()
    
    public init() {}
    
    public init(logic: LogicOperator) {
        this.logic = logic
    }
    
    /**
     * 添加字段条件
     */
    public func addFieldCondition(condition: FieldCondition): CompositeCondition {
        fieldConditions.add(condition)
        return this
    }
    
    /**
     * 添加组合条件
     */
    public func addCompositeCondition(condition: CompositeCondition): CompositeCondition {
        compositeConditions.add(condition)
        return this
    }
    
    /**
     * 判断是否为空
     */
    public func isEmpty(): Bool {
        fieldConditions.isEmpty() && compositeConditions.isEmpty()
    }
    
    public func toString(): String {
        let sb = StringBuilder()
        sb.append("(")
        sb.append("${logic}")
        
        if (!fieldConditions.isEmpty()) {
            sb.append(" [")
            let size = fieldConditions.size
            for (i in 0..size) {
                if (i > 0) {
                    sb.append(", ")
                }
                sb.append(fieldConditions[i].toString())
            }
            sb.append("]")
        }
        
        if (!compositeConditions.isEmpty()) {
            sb.append(" [")
            let size = compositeConditions.size
            for (i in 0..size) {
                if (i > 0) {
                    sb.append(", ")
                }
                sb.append(compositeConditions[i].toString())
            }
            sb.append("]")
        }
        
        sb.append(")")
        return sb.toString()
    }
}

/**
 * 排序条件
 */
public class SortCondition {
    public var field: String = ""
    public var ascending: Bool = true  // true: ASC, false: DESC
    
    public init() {}
    
    public init(field: String, ascending: Bool) {
        this.field = field
        this.ascending = ascending
    }
    
    public func toString(): String {
        "${field} ${if (ascending) { "ASC" } else { "DESC" }}"
    }
}

/**
 * 解析后的查询对象
 */
public class ParsedQuery {
    public var page: Int64 = 1
    public var pageSize: Int64 = 10
    public var filter: ?CompositeCondition = None<CompositeCondition>
    public var sort: ArrayList<SortCondition> = ArrayList<SortCondition>()
    
    public init() {}
    
    public func toString(): String {
        let sb = StringBuilder()
        sb.append("ParsedQuery(page=${page}, pageSize=${pageSize}")
        
        if (let Some(f) <- filter) {
            sb.append(", filter=${f.toString()}")
        }
        
        if (!sort.isEmpty()) {
            sb.append(", sort=[")
            let size = sort.size
            for (i in 0..size) {
                if (i > 0) {
                    sb.append(", ")
                }
                sb.append(sort[i].toString())
            }
            sb.append("]")
        }
        
        sb.append(")")
        return sb.toString()
    }
}
