macro package json4cj.jsonmacro

import std.ast.*

interface DefaultValueExprStore {
    func hasValueExpr(varIdentifierName: String): Bool
    func getValueExpr(varIdentifierName: String): Expr
}
