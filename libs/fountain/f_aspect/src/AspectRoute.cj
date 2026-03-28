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
package f_aspect

public import std.reflect.*
import f_base.*
import f_regex.*

/**
 * 用来修饰切面也就是Aspect的实现类
 */
@Annotation[target: [Type]]
public class AspectRoute <: RouteRule {
    public const AspectRoute(public let route: RouteRule) {}
    public func isAspect<T>(): Bool {
        TypeInfo.of<T>().isSubtypeOf(TypeInfo.of<Aspect>())
    }
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        route.matches(funcInfo)
    }
}
/**
 * 以下所有规则除非特别说明都适用本注释的说明。
 * 任意参数都可以用通配符*表示任意大于等于0个字符，?表示0或1个字符
 * packageName参数是包名，
 * - .*、*.、.*. 表示任意包名
 * - .. 表示任意级别的包名
 * typeName参数是类型名，
 * argTypes参数是参数全限定名，多个参数之间用,分割，适用通配符**表示任意数量和类型的参数类型
 * returnType参数是返回类型全限定名，适用通配符*表示任意返回类型
 * 类型全限定名不支持反射尚不支持的类型
 */
public abstract class RouteRule {
    public const init() {}
    public func matches(funcInfo: InvocationFuncInfo): Bool
    public operator const func &(right: RouteRule) {
        AndRouteRule(this, right)
    }
    public operator const func |(right: RouteRule) {
        OrRouteRule(this, right)
    }
    public operator const func !() {
        NotRouteRule(this)
    }
}
/**
 * 匹配的公共实例函数将被织入
 */
public class ExecutionRouteRule <: AndRouteRule {
    public const init(
        within: WithinRouteRule,
        funcType: FuncRouteRule
    ) {
        super(within, funcType)
    }
    public const init(qualifiedName: String, funcName: String, argTypes: String, returnType: String) {
        this(WithinRouteRule(qualifiedName), FuncRouteRule(funcName, argTypes, returnType))
    }
}
/**
 * 类型包名匹配packageName，类型名匹配typeName的全部类型将会匹配，匹配的类型全部公共实例函数将被织入，
 */
public class WithinRouteRule <: RouteRule {
    public const WithinRouteRule(public let qualifiedName: String) {}
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        Regex.wildcard(qualifiedName).matches(funcInfo.typeInfo.qualifiedName)
    }
}
/**
 * 因为切面修改以后的参数必须是原函数参数的子类型，原函数才能接收切面的修改，
 * 所以参数匹配argTypes的全部公共实例函数将被织入。
 * 多个参数使用,分割，*,表示忽略第一个参数，,*,表示忽略中间某个参数，,*表示忽略最后一个参数
 * **表示任意数量任意类型的参数，可以**在本规则结尾。
 * 本规则指定的明确参数类型如果是目标函数参数的子类型则判定通过，切面对参数的修改可以是目标函数参数的子类型或原类型。
 * 规则指定的类型可以使用`<: TypeQualifiedName`表示目标函数参数是指定参数类型的子类型即符合规则。
 * 规则指定的类型可以使用`TypeQualifiedName <:`表示指定参数类型是目标函数参数的子类型即符合规则。
 * 按照仓颉的子类型关系，任意类型都是其自身的子类型。
 */
public class ArgsRouteRule <: RouteRule {
    public const ArgsRouteRule(public let argTypes: String) {}
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        if (argTypes == '**') {
            return true
        }
        let types = argTypes.split(',')
        let params = funcInfo.funcInfo.parameters
        if (params.size < types.size) {
            return false
        }
        func check(i: Int64): Bool {
            let pt = params[i].typeInfo
            if (i < types.size) {
                let t = types[i].trimAscii()
                t == '*' || if (t.startsWith('<:')) {
                    pt.isSubtypeOf(TypeInfos.get(t[2..].trimAscii()))
                } else if (t.endsWith('<:')) {
                    TypeInfos.get(t[0..t.size - 2].trimAscii()).isSubtypeOf(pt)
                } else {
                    TypeInfos.get(t) == pt
                }
            } else {
                types[types.size - 1] == '**'
            }
        }
        for (i in 0..params.size where !check(i)) {
            return false
        }
        true
    }
}
/**
 * 因为切面修改以后的返回类型必须是原函数返回类型的子类型，才能按原函数的返回类型返回，
 * 所以returnType是目标函数返回类型的子类型将被织入，returnType是一个类型全限定名
 */
public class ReturnTypeRouteRule <: RouteRule {
    public const ReturnTypeRouteRule(public let returnType: String) {}
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        returnType == '*' || 
        ((returnType.contains('*') || returnType.contains('?')) && 
          Regex.wildcard(returnType).matches(funcInfo.funcInfo.returnType.qualifiedName)) || 
        TypeInfos.get(returnType).isSubtypeOf(funcInfo.funcInfo.returnType)
    }
}
/**
 * 参数和返回类型匹配的全部公共实例函数将被织入
 */
public class FuncTypeRouteRule <: AndRouteRule {
    public const init(
        argTypes: ArgsRouteRule,
        returnType: ReturnTypeRouteRule
    ) {
        super(argTypes, returnType)
    }
    public const init(argTypes: String, returnType: String) {
        this(ArgsRouteRule(argTypes), ReturnTypeRouteRule(returnType))
    }
}

public class FuncNameRouteRule <: RouteRule {
    public const FuncNameRouteRule(public let name: String) {}
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        Regex.wildcard(name).matches(funcInfo.funcInfo.name)
    }
}

public class FuncRouteRule <: AndRouteRule {
    public const init(
        name: FuncNameRouteRule,
        funcType: FuncTypeRouteRule
    ) {
        super(name, funcType)
    }
    public const init(name: String, argTypes: String, returnType: String) {
        this(FuncNameRouteRule(name), FuncTypeRouteRule(argTypes, returnType))
    }
}
/**
 * 参数是一个类型全限定名，这个类型及它的子类型全部公共实例函数将被织入
 */
public class TargetRouteRule <: RouteRule {
    public const TargetRouteRule(public let targetQualifiedName: String) {}
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        funcInfo.typeInfo.isSubtypeOf(TypeInfos.get(targetQualifiedName))
    }
}

private func contains(annotations: Collection<Annotation>, annotationNames: Array<String>, sub!: Bool = false) {
    if (sub) {
        let list = ArrayList<TypeInfo>(annotations.size)
        let supers = ArrayList<TypeInfo>(annotationNames.size)
        for (annotation in annotations) {
            list.add(ClassTypeInfo.of(annotation))
        }
        for (name in annotationNames) {
            supers.add(TypeInfos.get(name.trimAscii()))
        }
        for (superType in supers) {
            var matched = false
            for (annotationType in list where annotationType.isSubtypeOf(superType)) {
                matched = true
                break
            }
            if (!matched) {
                return false
            }
        }
        true
    } else {
        let set = HashSet<String>()
        for (annotation in annotations) {
            set.add(ClassTypeInfo.of(annotation).qualifiedName)
        }
        for (name in annotationNames where !set.contains(name.trimAscii())) {
            return false
        }
        true
    }
}
/**
 * 如果目标类型有指定类型的注解则目标类型的全部公共实例函数将被织入，本规则不适用通配符
 * 参数是注解类型的全限定名，多个注解类名用&分割，每个注解类型都要能够跟目标类型的注解匹配到才返回true。
 * sub是true时，要求目标类型的注解是指定注解的子类型，否则要求指定的注解全限定名是目标类型注解全限定名的子集。
 */
public class TargetAnnotationRouteRule <: RouteRule {
    public const TargetAnnotationRouteRule(
        public let annotationTypes: String,
        public let sub!: Bool = false
    ) {}
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        let annotationNames = annotationTypes.split('&')
        contains(funcInfo.funcInfo.annotations, annotationNames, sub: sub)
    }
}
/**
 * 目标函数有指定类型的注解将被织入，本规则不适用通配符
 * 参数是注解类型的全限定名，多个注解类名用&分割，每个注解类型都要能够跟目标函数的注解匹配到才返回true。
 * sub是true时，要求目标函数的注解是指定注解的子类型，否则要求指定的注解的全限定名是目标函数注解全限定名的子集。
 */
public class FuncAnnotationRouteRule <: RouteRule {
    public const FuncAnnotationRouteRule(
        public let annotationTypes: String,
        public let sub!: Bool = false
    ) {}
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        let annotationNames = annotationTypes.split('&')
        contains(funcInfo.funcInfo.annotations, annotationNames, sub: sub)
    }
}
/**
 * 目标函数参数都有指定类型注解将被织入，本规则不适用通配符
 * 参数是注解类型的全限定名，多个注解类型用&分割，每个注解类型依次对应一个参数。
 * 忽略某个参数的注解需要使用*占位，
 * 比如*,a.b.c.AnnotationType表示目标函数有两个参数，忽略第一个参数的注解，第二个参数必须有a.b.c.AnnotationType注解
 * a.Annotation1,*,b.Annotation2表示目标函数有三个参数，忽略第二个参数的注解，第一第三个参数必须有a.Annotation1和b.Annotation2
 */
public class ArgAnnotationsRouteRule <: RouteRule {
    public const ArgAnnotationsRouteRule(public let annotationTypes: String) {}
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        let params = funcInfo.funcInfo.parameters
        let annotationNames = annotationTypes.split('&')
        for (i in 0..params.size) {
            let param = params[i]
            let annotationName = annotationNames[i].trimAscii()
            if (annotationName == '*') {
                continue
            }
            for (annotation in param.annotations where ClassTypeInfo.of(annotation).qualifiedName == annotationName) {
                continue
            }
            return false
        }
        true
    }
}
/**
 * 目标函数任意一个参数拥有指定的全部注解将被织入，本规则不适用通配符，多个注解用,分割
 */
public class AnyArgAnnotationsRouteRule <: RouteRule {
    public const AnyArgAnnotationsRouteRule(public let annotationTypes: String) {}
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        let params = funcInfo.funcInfo.parameters
        let annotationNames = annotationTypes.split('|')
        for (param in params where contains(param.annotations, annotationNames)) {
            return true
        }
        false
    }
}

private func matches(asc: Bool, funcInfo: InvocationFuncInfo, annotationTypes: String) {
    let annotations = annotationTypes.split(',')
    let params = funcInfo.funcInfo.parameters
    let range = if (asc) {
        0..params.size
    } else {
        params.size - 1..=0
    }
    for (i in range) {
        let current = annotations[i]
        var matched = false
        for (annotation in params[i].annotations where ClassTypeInfo.of(annotation).qualifiedName == current) {
            matched = true
            break
        }
        if (!matched) {
            return false
        }
    }
    true
}
/**
 * 目标函数开头的每个参数拥有指定注解将被织入，本规则不适用通配符，多个注解用,分割
 * 比如a.Annotation1,b.Annotation2 匹配下面的test1和test2
 * public func test1(@Annotation1 a: String, @Annotation2 b: String){}
 * public func test2(@Annotation1 a: String, @Annotation2 b: String, c: String){}
 * public func test3(@Annotation1 a: String, c: String, @Annotation2 b: String){}
 */
public class ArgPrefixAnnotationsRouteRule <: RouteRule {
    public const ArgPrefixAnnotationsRouteRule(public let annotationTypes: String) {}
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        matches(true, funcInfo, annotationTypes)
    }
}
/**
 * 目标函数结尾的每个参数拥有指定注解将被织入，本规则不适用通配符，多个注解用,分割
 * 比如a.Annotation1,b.Annotation2 匹配下面的test1和test2
 * public func test1(@Annotation1 a: String, @Annotation2 b: String){}
 * public func test2(c: String, @Annotation1 a: String, @Annotation2 b: String){}
 * public func test3(@Annotation1 a: String, c: String, @Annotation2 b: String){}
 */
public class ArgSuffixAnnotationsRouteRule <: RouteRule {
    public const ArgSuffixAnnotationsRouteRule(public let annotationTypes: String) {}
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        matches(false, funcInfo, annotationTypes)
    }
}
/**
 * 目标对象的beanName符合本规则，目标的全部公共实例函数将被织入
 */
public class BeanNameRouteRule <: RouteRule {
    public const BeanNameRouteRule(public let beanName: String) {}
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        let managers = BeanFactory.instance.iterator<Object>(funcInfo.typeInfo)
        let regex = Regex.wildcard(beanName)
        for (m in managers where regex.matches(m.name) && m.beanType == funcInfo.typeInfo) {
            return true
        }
        false
    }
}
/**
 * 两个规则都匹配的公共实例函数将被织入
 */
public open class AndRouteRule <: RouteRule {
    public const AndRouteRule(private let left: RouteRule, private let right: RouteRule) {}
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        left.matches(funcInfo) && right.matches(funcInfo)
    }
}
/**
 * 匹配任意一个规则的公共实例函数将被织入
 */
public class OrRouteRule <: RouteRule {
    public const OrRouteRule(public let left: RouteRule, public let right: RouteRule) {}
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        left.matches(funcInfo) || right.matches(funcInfo)
    }
}
/**
 * 对指定规则匹配结果取反。
 */
public class NotRouteRule <: RouteRule {
    public const NotRouteRule(public let rule: RouteRule) {}
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        !rule.matches(funcInfo)
    }
}
