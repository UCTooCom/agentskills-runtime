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

public interface CompositeDecl <: ToTokens {
    mut prop annotations: ArrayList<Annotation>
    mut prop modifiers: ArrayList<Modifier>
    mut prop keyword: Token
    mut prop identifier: Token
    mut prop genericParam: GenericParam
    mut prop genericConstraint: ArrayList<GenericConstraint>
    func getAttrs(): Tokens
    func hasAttr(attr: String): Bool
    mut prop upperBound: Token
    mut prop superTypes: ArrayList<TypeNode>
    mut prop body: Body
    func isPublic(): Bool
    func isProtected(): Bool
    func isPrivate(): Bool
    func isInternal(): Bool {
        !(isPublic() || isProtected() || isPrivate())
    }
}

public interface ExtendClassDecl {
    func isOpen(): Bool
    func isAbstract(): Bool
    func isSealed(): Bool
}

extend ClassDecl <: CompositeDecl & ExtendClassDecl {
    public func isPublic(): Bool {
        isPublic(this)
    }
    public func isProtected(): Bool {
        isProtected(this)
    }
    public func isPrivate(): Bool {
        isPrivate(this)
    }
    public func isOpen(): Bool {
        isOpen(this)
    }
    public func isAbstract(): Bool {
        isAbstract(this)
    }
    public func isSealed(): Bool {
        isSealed(this)
    }
}

extend StructDecl <: CompositeDecl {
    public func isPublic(): Bool {
        isPublic(this)
    }
    public func isProtected(): Bool {
        isProtected(this)
    }
    public func isPrivate(): Bool {
        isPrivate(this)
    }
}
