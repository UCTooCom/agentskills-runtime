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
 * bean定义有指定数量时为true
 */
public enum BeanDefCount <: ToString {
    /**
     * 没有bean定义
     */
    | Zero
    /**
     * 只有一个bean定义
     */
    | OnlyOne
    /**
     * 至少有一个bean定义
     */
    | AtLeastOne
    /**
     * 多于一个bean定义
     */
    | MoreThanOne

    public func toString(): String {
        match(this){
            case Zero => "Zero"
            case OnlyOne => "OnlyOne"
            case AtLeastOne => "AtLeastOne"
            case MoreThanOne => "MoreThanOne"
        }
    }
}

public enum BeanDefType <: ToString {
    /**
     * 不判断bean类型
     */
    | IgnoreType
    /**
     * bean定义的类型必须是指定类型
     */
    | Current(String)
    /**
     * bean定义的类型是指定类型或指定类型的后代类型
     */
    | CurrentOrSubOf(String)
    /**
     * bean定义的类型必须是指定类型的后代类型
     */
    | SubOfOnly(String)
    /**
     * bean定义的类型必须是指定类型或指定类型的祖先类型
     */
    | CurrentOrSuperOf(String)
    /**
     * bean定义的类型必须是指定类型的祖先类型
     */
    | SuperOfOnly(String)

    public func toString(): String {
        match(this){
            case IgnoreType => "IgnoreType"
            case Current(v) => "Current(${v})"
            case CurrentOrSubOf(v) => "CurrentOrSubOf(${v})"
            case SubOfOnly(v) => "SubOfOnly(${v})"
            case CurrentOrSuperOf(v) => "CurrentOrSuperOf(${v})"
            case SuperOfOnly(v) => "SuperOfOnly(${v})"
        }
    }

    public func on(beanType: TypeInfo) {
        match (this) {
            case IgnoreType => true
            case Current(t) => TypeInfos.get(t) == beanType
            case CurrentOrSubOf(t) =>
                let ti = TypeInfos.get(t)
                ti == beanType || beanType.isSubtypeOf(ti)
            case SubOfOnly(t) => beanType.isSubtypeOf(TypeInfos.get(t))
            case CurrentOrSuperOf(t) =>
                let ti = TypeInfos.get(t)
                ti == beanType || ti.isSubtypeOf(beanType)
            case SuperOfOnly(t) => TypeInfos.get(t).isSubtypeOf(beanType)
        }
    }
}

/**
 * beanType是全限定类型名，指定类型有bean定义则on返回true
 */
public class BeanDef <: BeanCondition {
    public const BeanDef(
        public let beanType!: BeanDefType = IgnoreType,
        public let beanName!: StringCond = IgnoreCond,
        public let count!: BeanDefCount = AtLeastOne,
        public let scope!: ?BeanScope = None
    ) {}

    public func toString(): String {
        'type: ${beanType}; name:${beanName}; count:${count}; scope:${scope}'
    }

    public func on(factory: BeanFactory): Bool {
        match ((beanType, beanName)) {
            case (IgnoreType, IgnoreName) => return true //相当于没有指定bean初始化条件
            case (CurrentOrSubOf(t), _) => on(factory, TypeInfos.get(t))
            case (Current(t), _) => on(factory, TypeInfos.get(t))
            case (SubOfOnly(t), _) => on(factory, TypeInfos.get(t))
            case _ => on(factory, TypeInfo.of<Object>())
        }
    }
    private func on(factory: BeanFactory, typeInfo: TypeInfo): Bool {
        var count = 0
        for (m in factory.beanManagers(typeInfo) where beanType.on(m.beanType) && beanName.on(m.name) && (scope
            .isNone() || scope.getOrThrow() == m.meta.scope)) {
            count++
            match (this.count) {
                case AtLeastOne => return true
                case MoreThanOne where count > 1 => return true
                case OnlyOne where count > 1 => return false
                case Zero => return false
                case _ => continue
            }
        }
        match (this.count) {
            case AtLeastOne => count > 0
            case MoreThanOne => count > 1
            case OnlyOne => count == 1
            case Zero => count == 0
        }
    }
}
