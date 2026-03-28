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
package f_macros

public func isStatic(tokens: Tokens): Bool {
    isStatic(parseDecl(tokens))
}

public func isStatic(decl: Decl): Bool {
    isModifier(decl.modifiers, STATIC)
}

public func isAbstract(tokens: Tokens): Bool {
    isAbstract(parseDecl(tokens))
}

public func isAbstract(decl: Decl): Bool {
    decl is ClassDecl && isAbstract((decl as ClassDecl).getOrThrow())
}

public func isAbstract(decl: ClassDecl): Bool {
    isModifier(decl.modifiers, ABSTRACT)
}
public func isSealed(tokens: Tokens): Bool {
    isSealed(parseDecl(tokens))
}
public func isSealed(decl: Decl): Bool {
    match(decl) {
        case x: ClassDecl => isSealed(x)
        case _ => false
    }
}
public func isSealed(decl: ClassDecl): Bool {
    isModifier(decl.modifiers, SEALED)
}

public func isPublic(tokens: Tokens): Bool {
    isPublic(parseDecl(tokens))
}

public func isPublic(decl: Decl): Bool {
    isModifier(decl.modifiers, PUBLIC)
}
public func isPrivate(decl: Decl): Bool {
    isModifier(decl.modifiers, PRIVATE)
}
public func isProtected(decl: Decl): Bool {
    isModifier(decl.modifiers, PROTECTED)
}
public func isInternal(decl: Decl): Bool {
    isModifier(decl.modifiers, INTERNAL)
}

public func isPrivate(tokens: Tokens): Bool {
    isPrivate(parseDecl(tokens))
}

public func isProtected(tokens: Tokens): Bool {
    isProtected(parseDecl(tokens))
}

public func isMut(tokens: Tokens): Bool {
    isMut(parseDecl(tokens))
}

public func isMut(decl: Decl): Bool {
    isModifier(decl.modifiers, MUT)
}


public func isOpen(tokens: Tokens): Bool {
    isOpen(parseDecl(tokens))
}

public func isOpen(decl: Decl): Bool {
    isModifier(decl.modifiers, OPEN)
}


public func isOverride(tokens: Tokens): Bool {
    isOverride(parseDecl(tokens))
}

public func isOverride(decl: Decl): Bool {
    isModifier(decl.modifiers, OVERRIDE)
}

public func isRedef(tokens: Tokens): Bool {
    isRedef(parseDecl(tokens))
}

public func isRedef(decl: Decl): Bool {
    isModifier(decl.modifiers, REDEF)
}

func isModifier(modifiers: ArrayList<Modifier>, kind: TokenKind): Bool {
    for(m in modifiers where m.keyword.kind == kind){
        return true
    }
    false
}

public func isVar(param: FuncParam){
    param.isMemberParam() && param.keyword.kind == VAR
}