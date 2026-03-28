/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_bean

/**
 * 配置项满足条件时on返回true
 */
public enum ConfCond <: BeanCondition {
    /**
     * 忽略配置条件
     */
    | IgnoreConf
    /**
     * 存在配置项时返回true
     */
    | Exists(String)
    /**
     * 不存在配置项时返回true
     */
    | NotExists(String)
    /**
     * 存在配置项且配置项的值满足StringCond，如果StringCond.IgnoreCond相当于Exists(String)
     */
    | Value(String, StringCond)

    public func on(_: BeanFactory): Bool {
        match (this) {
            case IgnoreConf => true
            case Exists(key) => Config.getString(key).isSome()
            case NotExists(key) => Config.getString(key).isNone()
            case Value(key, val) => match (Config.getString(key)) {
                case Some(x) => val.on(x)
                case _ => false
            }
        }
    }
    public func toString(): String {
        match(this){
            case IgnoreConf => "IgnoreConf"
            case Exists(key) => "Exists(${key})"
            case NotExists(key) => "NotExists(${key})"
            case Value(key, val) => "Value(${key}, ${val})"
        }
    }
}
