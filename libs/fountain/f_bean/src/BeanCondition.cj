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
 * bean初始化条件，满足条件的bean才初始化，否则将被从BeanFactory删除
 */
public interface BeanCondition <: ToString {
    func on(factory: BeanFactory): Bool
    operator const func &(right: BeanCondition): BeanCondition {
        AndCond(this, right)
    }
    operator const func |(right: BeanCondition): BeanCondition {
        OrCond(this, right)
    }
    operator const func !(): BeanCondition {
        NotCond(this)
    }
}
/**
 * 默认的bean初始化条件，初始化BeanMeta时的占位。永远返回true。
 */
public class NoneBeanCondition <: BeanCondition {
    public static const instance = NoneBeanCondition()
    private const init() {}
    public func on(_: BeanFactory): Bool {
        true
    }
    public func toString(): String {
        'None'
    }
}
