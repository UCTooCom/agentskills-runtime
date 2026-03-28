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
 * 定义bean的作用范围。prototype和singleton，可以在其它模块定义新的作用范围。
 * 受自定义作用范围影响的bean生命周期由范围定义模块维持
 */
public abstract class BeanScope <: Equatable<BeanScope> & ToString {
    public static const prototype = PrototypeBeanScope()
    public static const singleton = SingletonBeanScope()
    public const init() {}
    /**
     * 返回当前类型的TypeInfo
     */
    public prop typeInfo: TypeInfo
    public operator func ==(other: BeanScope) {
        refEq(this, other) || this.typeInfo == other.typeInfo
    }
    public prop isPrototype: Bool {
        get() {
            this == prototype
        }
    }
    public prop isSingleton: Bool {
        get() {
            this == singleton
        }
    }
}

public class PrototypeBeanScope <: BeanScope {
    internal const init() {}
    public prop typeInfo: TypeInfo {
        get() {
            TypeInfo.of<PrototypeBeanScope>()
        }
    }
    public func toString(): String {
        'prototype'
    }
}

public class SingletonBeanScope <: BeanScope {
    internal const init() {}
    public prop typeInfo: TypeInfo {
        get() {
            TypeInfo.of<SingletonBeanScope>()
        }
    }
    public func toString(): String {
        'singleton'
    }
}
