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
 * 两个bean初始化条件都是true时本条件才是true。
 */
public class AndCond <: BeanCondition {
    public const AndCond(public let left: BeanCondition, public let right: BeanCondition) {}
    public func on(factory: BeanFactory): Bool {
        left.on(factory) && right.on(factory)
    }
    public func toString(): String {
        '(${left} && ${right})'
    }
}
/**
 * 两个bean初始化条件有一个是true本条件就是true，首先执行left。
 */
public class OrCond <: BeanCondition {
    public const OrCond(public let left: BeanCondition, public let right: BeanCondition) {}
    public func on(factory: BeanFactory): Bool {
        left.on(factory) || right.on(factory)
    }
    public func toString(): String {
        '(${left} || ${right})'
    }
}
/**
 * 将指定初始化条件取反
 */
public class NotCond <: BeanCondition {
    public const NotCond(public let op: BeanCondition) {}
    public func on(factory: BeanFactory): Bool {
        !op.on(factory)
    }
    public func toString(): String {
        '(!${op})'
    }
}
