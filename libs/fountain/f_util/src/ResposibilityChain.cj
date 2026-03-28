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
package f_util

import std.collection.ArrayList
import f_exception.IllegalAccessException

/*
 * 责任链模式的接口，所有责任链策略都要实现此接口
 * S 是策略的具体实现，N与S需要一一对应
 * C 是执行策略的条件参数，满足条件的策略会得到执行
 * A 是执行策略的参数
 * R 是执行策略的结果
 */
public interface Resposibility<C, A, R> {
    /**
     * 检查指定条件是否满足执行当前策略的要求
     */
    func check(condition: C): Bool

    /**
     * 执行当前策略
     */
    func execute(arg: A): R
}

public interface ValidationResposibility<C, A> <: Resposibility<C, A, Unit> {
    func execute(arg: A): Unit {}
}

public class ResposibilityChain<C, A, R> {
    private let resposibilities = ArrayList<Resposibility<C, A, R>>()
    public init() {}
    public init(resposibilities: Iterable<Resposibility<C, A, R>>) {
        for (r in resposibilities) {
            this.resposibilities.add(r)
        }
    }

    /**
     * 注册一个策略
     */
    public func register(resposibility: Resposibility<C, A, R>): ResposibilityChain<C, A, R> {
        resposibilities.add(resposibility)
        this
    }
    public func register<S>(resposibilities: Iterable<S>): Unit where S <: Resposibility<C, A, R> {
        for (r in resposibilities) {
            this.resposibilities.add(r)
        }
    }

    /**  执行一个策略，遍历策略集合，直到遇到一个Resposibility.check(condition)返回true的策略，并执行这个策略。
     * 如果没有策略满足条件，就抛出IllegalAccessException
     */
    public func execute(condition: C, arg: A): R {
        for (r in resposibilities) {
            if (r.check(condition)) {
                return r.execute(arg)
            }
        }
        throw IllegalAccessException("there is no strategy to match current condition")
    }
    public func executeAll(condition: C, arg: A): Unit {
        for (r in resposibilities where r.check(condition)) {
            r.execute(arg)
        }
    }
}
