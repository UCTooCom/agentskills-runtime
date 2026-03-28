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
package f_mvc

abstract class RequestCondition {
    protected open func check(form: Form) {
        true
    }
    protected open func check(form: Form, url: URL): Bool {
        check(form) && if (url.rawQuery.isSome()) {
            let urlForm = url.queryForm
            !refEq(form, urlForm) && check(urlForm)
        } else {
            false
        }
    }
    protected func check(headers: HttpHeaders): Bool

    private static func compile(expr: Expr): RequestCondition {
        match (expr) {
            case e: ParenExpr => compile(e.parenthesizedExpr)
            case e: UnaryExpr where e.op.kind.toString() == '!' => NotRequestCondition(compile(e.expr))
            case e: RefExpr => ContainsRequestCondition(e.identifier.value)
            case e: CallExpr =>
                let call = (e.callFunc as MemberAccess).getOrThrow()
                let key = call.baseExpr.toTokens().toString()
                let fn = call.field.value
                let args = Array<String>(e.arguments.size) {
                    i => e.arguments[i].expr.toTokens().toString()
                }
                match (fn) {
                    case 'contains' => ValueContainsRequestCondition(key, args)
                    case 'subset' => SubsetOfValuesRequestCondition(key, args)
                    case _ => throw MVCException(
                        'function call in request condition supports contains and subset only, but current is ${e.toTokens()}. \"contains\" means values of request params or headers which is with specified name contains specified values, meanwhile \"subset\" means values of request params or headers which is specified name is subset of specified values.')
                }
            case e: BinaryExpr => match (e.op.kind) {
                case AND => AndRequestCondition(compile(e.leftExpr), compile(e.rightExpr))
                case OR => OrRequestCondition(compile(e.leftExpr), compile(e.rightExpr))
                case EQUAL => EqualRequestCondition(compile(e.leftExpr), compile(e.rightExpr))
                case NOTEQ => NotRequestCondition(EqualRequestCondition(compile(e.leftExpr), compile(e.rightExpr)))
                case SUB => ContainsRequestCondition('${e.leftExpr.toTokens()}-${e.rightExpr.toTokens()}')
                case _ => throw MVCException('illegal operator ${e.op.kind} in expression ${expr.toTokens()}')
            }
            case _ => throw MVCException('illegal expression, ${expr.toTokens()}')
        }
    }
    static func compile(expr: String): RequestCondition {
        if (expr.trimAscii().isEmpty()) {
            return DummyRequestCondition.instance
        }
        let tokens = cangjieLex(expr)
        let e = parseExpr(tokens)
        compile(e)
    }
}

class DummyRequestCondition <: RequestCondition {
    static let instance = DummyRequestCondition()
    protected func check(_: Form, _: URL): Bool {
        true
    }
    protected func check(_: HttpHeaders): Bool {
        true
    }
}

class NotRequestCondition <: RequestCondition {
    NotRequestCondition(private let condition: RequestCondition) {}

    protected func check(form: Form, url: URL): Bool {
        !(condition.check(form, url))
    }
    protected func check(headers: HttpHeaders): Bool {
        !(condition.check(headers))
    }
}

class AndRequestCondition <: RequestCondition {
    AndRequestCondition(private let left: RequestCondition, private let right: RequestCondition) {}
    protected func check(form: Form, url: URL): Bool {
        left.check(form, url) && right.check(form, url)
    }
    protected func check(headers: HttpHeaders): Bool {
        left.check(headers) && right.check(headers)
    }
}

class OrRequestCondition <: RequestCondition {
    OrRequestCondition(private let left: RequestCondition, private let right: RequestCondition) {}
    protected func check(form: Form, url: URL): Bool {
        left.check(form, url) || right.check(form, url)
    }
    protected func check(headers: HttpHeaders): Bool {
        left.check(headers) || right.check(headers)
    }
}

class EqualRequestCondition <: RequestCondition {
    EqualRequestCondition(private let name: String, private let value: String) {}
    init(name: RequestCondition, value: RequestCondition) {
        match ((name, value)) {
            case (x: ContainsRequestCondition, y: ContainsRequestCondition) => (this.name, this.value) = (x.name, y.name)
            case _ => throw MVCException(
                "The left and right of == should be both form name or request header key string value")
        }
    }
    protected func check(form: Form) {
        for (v in form.getAll(name) where v == value) {
            return true
        }
        false
    }

    protected func check(headers: HttpHeaders): Bool {
        for (v in headers.get(name) where v == value) {
            return true
        }
        false
    }
}

abstract class SubsetOfRequestCondition <: RequestCondition {
    protected let key: String
    protected let values = HashSet<String>()
    init(key: String, value: String) {
        this.key = key
        values.add(value)
    }
    init(key: String, values: Array<String>) {
        this.key = key
        this.values.add(all: values)
    }

    protected func check(form: Form) {
        check(form.getAll(key))
    }
    protected func check(headers: HttpHeaders): Bool {
        check(headers.get(key))
    }
    protected func check<C>(currentValues: C): Bool where C <: Collection<String>
}

class ValueContainsRequestCondition <: SubsetOfRequestCondition {
    init(key: String, value: String) {
        super(key, value)
    }
    init(key: String, values: Array<String>) {
        super(key, values)
    }
    protected func check<C>(currentValues: C): Bool where C <: Collection<String> {
        let set = HashSet<String>(currentValues)
        for (value in values where !set.contains(value)) {
            return false
        }
        true
    }
}

class SubsetOfValuesRequestCondition <: SubsetOfRequestCondition {
    init(key: String, value: String) {
        super(key, value)
    }
    init(key: String, values: Array<String>) {
        super(key, values)
    }
    protected func check<C>(currentValues: C): Bool where C <: Collection<String> {
        for (cur in currentValues where !values.contains(cur)) {
            return false
        }
        true
    }
}

class ContainsRequestCondition <: RequestCondition {
    ContainsRequestCondition(let name: String) {}
    protected func check(form: Form) {
        form.get(name).isSome()
    }
    protected func check(headers: HttpHeaders): Bool {
        headers.get(name).size > 0
    }
}
