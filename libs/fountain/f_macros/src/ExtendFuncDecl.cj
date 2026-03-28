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

public interface ExtendFuncDecl <: ExtendMember {
    func isMut(): Bool
    func isOpen(): Bool
    func isStatic(): Bool
}

extend FuncDecl <: ExtendFuncDecl {
    public func isMut(): Bool {
        isMut(this)
    }
    public func isPublic(): Bool {
        isPublic(this)
    }
    public func isProtected(): Bool {
        isProtected(this)
    }
    public func isPrivate(): Bool {
        isPrivate(this)
    }
    public func isStatic(): Bool {
        isStatic(this)
    }
    public func isOpen(): Bool {
        isOpen(this)
    }
}
