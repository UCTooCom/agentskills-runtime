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

/**
 * 拥有已经实现过的全部RouteRule，只是初始化参数是配置项
 */
public abstract class ConfigRouteRule <: RouteRule {
    public const ConfigRouteRule(
        private let config: String,
        private let matchIfNone: Bool) {
    }
    private func getConfig(config: String): ?String {
        Config.getString(config)?.trimAscii()
    }
    protected func doMatches(funcInfo: InvocationFuncInfo, matchFn: (String) -> Bool): Bool {
        if(let Some(x) <- getConfig(config)){
            matchFn(x)
        }else{
            matchIfNone
        }
    }
}
public class ConfigExecutionRouteRule <: ConfigRouteRule {
    public const init(config: String, matchIfNone!: Bool = false) {
        super(config, matchIfNone)
    }
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        doMatches(funcInfo){qualified =>
            for(qualified in qualified.split('|')){
                let colon = qualified.lastIndexOf(':').getOrThrow {AspectException('${qualified} does not contain returnType')}
                let lparen = qualified
                    .indexOf('(')
                    .getOrThrow {AspectException('${qualified} does not contain argTypes')}
                let rparen = colon - 1
                let lastDot = qualified[0 .. lparen]
                    .lastIndexOf('.')
                    .getOrThrow {AspectException('${qualified} does not contain qualifiedName or funcName')}
                let returnType = qualified[colon + 1..].trimAscii()
                let argTypes = qualified[lparen + 1..rparen].trimAscii()
                let funcName = qualified[lastDot + 1..lparen].trimAscii()
                let qualifiedName = qualified[0..lastDot]
                let matched = ExecutionRouteRule(qualifiedName, funcName, argTypes, returnType).matches(funcInfo)
                if(matched){
                    return true
                }
            }
            false
        }
    }
}

public class ConfigWithinRouteRule <: ConfigRouteRule {
    public const init(config: String, matchIfNone!: Bool = false) {
        super(config, matchIfNone)
    }
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        doMatches(funcInfo){qualified =>
            WithinRouteRule(qualified).matches(funcInfo)
        }
    }
}

public class ConfigArgsRouteRule <: ConfigRouteRule {
    public const init(config: String, matchIfNone!: Bool = false) {
        super(config, matchIfNone)
    }
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        doMatches(funcInfo){qualified =>
            ArgsRouteRule(qualified).matches(funcInfo)
        }
    }
}

public class ConfigReturnTypeRouteRule <: ConfigRouteRule {
    public const init(config: String, matchIfNone!: Bool = false) {
        super(config, matchIfNone)
    }
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        doMatches(funcInfo){qualified =>
            ReturnTypeRouteRule(qualified).matches(funcInfo)
        }
    }
}

public class ConfigFuncTypeRouteRule <: ConfigRouteRule {
    public const init(config: String, matchIfNone!: Bool = false) {
        super(config, matchIfNone)
    }
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        doMatches(funcInfo){funcType =>
            let colon = funcType.lastIndexOf(':').getOrThrow {AspectException('${funcType} does not contain returnType')}
            let rparen = funcType
                .lastIndexOf(')', colon)
                .getOrThrow {AspectException('${funcType} does not contain argTypes')}
            let lparen = funcType
                .lastIndexOf('(', rparen)
                .getOrThrow {AspectException('${funcType} does not contain argTypes')}
            let returnType = funcType[colon + 1..]
            let argTypes = funcType[lparen + 1..rparen]
            FuncTypeRouteRule(argTypes, returnType).matches(funcInfo)
        }
    }
}

public class ConfigFuncNameRouteRule <: ConfigRouteRule {
    public const init(config: String, matchIfNone!: Bool = false) {
        super(config, matchIfNone)
    }
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        doMatches(funcInfo){name =>
            FuncNameRouteRule(name).matches(funcInfo)
        }
    }
}

public class ConfigFuncRouteRule <: ConfigRouteRule {
    public const init(config: String, matchIfNone!: Bool = false) {
        super(config, matchIfNone)
    }
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        doMatches(funcInfo){funcDecl =>
            let colon = funcDecl.lastIndexOf(':').getOrThrow {AspectException('${funcDecl} does not contain returnType')}
            let rparen = funcDecl
                .lastIndexOf(')', colon)
                .getOrThrow {AspectException('${funcDecl} does not contain argTypes')}
            let lparen = funcDecl
                .lastIndexOf('(', rparen)
                .getOrThrow {AspectException('${funcDecl} does not contain argTypes')}
            let returnType = funcDecl[colon + 1..]
            let argTypes = funcDecl[lparen + 1..rparen]
            let funcName = funcDecl[0..lparen]
            FuncRouteRule(funcName, argTypes, returnType).matches(funcInfo)
        }
    }
}

public class ConfigTargetRouteRule <: ConfigRouteRule {
    public const init(config: String, matchIfNone!: Bool = false) {
        super(config, matchIfNone)
    }
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        doMatches(funcInfo){qualified =>
            TargetRouteRule(qualified).matches(funcInfo)
        }
    }
}

public class ConfigTargetAnnotationRouteRule <: ConfigRouteRule {
    public const init(config: String, matchIfNone!: Bool = false) {
        super(config, matchIfNone)
    }
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        doMatches(funcInfo){annotationTypes =>
            if (annotationTypes.startsWith('<:')) {
                TargetAnnotationRouteRule(annotationTypes[2..], sub: true)
            } else {
                TargetAnnotationRouteRule(annotationTypes, sub: false)
            }.matches(funcInfo)
        }
    }
}

public class ConfigFuncAnnotationRouteRule <: ConfigRouteRule {
    public const init(config: String, matchIfNone!: Bool = false) {
        super(config, matchIfNone)
    }
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        doMatches(funcInfo){annotationTypes =>
            if (annotationTypes.startsWith('<:')) {
                FuncAnnotationRouteRule(annotationTypes[2..], sub: true)
            } else {
                FuncAnnotationRouteRule(annotationTypes, sub: false)
            }.matches(funcInfo)
        }
    }
}

public class ConfigArgAnnotationsRouteRule <: ConfigRouteRule {
    public const init(config: String, matchIfNone!: Bool = false) {
        super(config, matchIfNone)
    }
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        doMatches(funcInfo){annotationTypes =>
            ArgAnnotationsRouteRule(annotationTypes).matches(funcInfo)
        }
    }
}

public class ConfigAnyArgAnnotationsRouteRule <: ConfigRouteRule {
    public const init(config: String, matchIfNone!: Bool = false) {
        super(config, matchIfNone)
    }
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        doMatches(funcInfo){annotationTypes =>
            AnyArgAnnotationsRouteRule(annotationTypes).matches(funcInfo)
        }
    }
}

public class ConfigArgPrefixAnnotationsRouteRule <: ConfigRouteRule {
    public const init(config: String, matchIfNone!: Bool = false) {
        super(config, matchIfNone)
    }
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        doMatches(funcInfo){annotationTypes =>
            ArgPrefixAnnotationsRouteRule(annotationTypes).matches(funcInfo)
        }
    }
}

public class ConfigArgSuffixAnnotationsRouteRule <: ConfigRouteRule {
    public const init(config: String, matchIfNone!: Bool = false) {
        super(config, matchIfNone)
    }
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        doMatches(funcInfo){annotationTypes =>
            ArgSuffixAnnotationsRouteRule(annotationTypes).matches(funcInfo)
        }
    }
}

public class ConfigBeanNameRouteRule <: ConfigRouteRule {
    public const init(config: String, matchIfNone!: Bool = false) {
        super(config, matchIfNone)
    }
    public func matches(funcInfo: InvocationFuncInfo): Bool {
        doMatches(funcInfo){beanName =>
            BeanNameRouteRule(beanName).matches(funcInfo)
        }
    }
}
