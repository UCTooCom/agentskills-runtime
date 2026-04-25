macro package json4cj.jsonmacro

import std.ast.*

/*
* Verifier for tokens
*/
class TokenVerifier {
    /*
    * Verifies class decl token
    * @param input_Tk the token to verify
    * @param macroName the macro name to check against
    * @return (Option<ClassDecl>, Option<StructDecl>) the input token as class or struct type
    */
    public static func verifyClassDecl(input_Tk: Tokens, macroName: String): (Option<ClassDecl>, Option<StructDecl>) {
        var decl = parseDecl(input_Tk)

        if (decl is ClassDecl) {
            return ((decl as ClassDecl), None)
        } else if (decl is StructDecl) {
            return (None, (decl as StructDecl))
        } else {
            throw TokenVerificationException("${macroName} is only allowed for class or struct")
        }
    }

    /*
    * Verifies class, struct, or enum decl token
    * @param input_Tk the token to verify
    * @param macroName the macro name to check against
    * @return (Option<ClassDecl>, Option<StructDecl>, Option<EnumDecl>)
    */
    public static func verifyClassOrEnumDecl(input_Tk: Tokens, macroName: String): (Option<ClassDecl>, Option<StructDecl>, Option<EnumDecl>) {
        var decl = parseDecl(input_Tk)

        if (decl is ClassDecl) {
            return ((decl as ClassDecl), None, None)
        } else if (decl is StructDecl) {
            return (None, (decl as StructDecl), None)
        } else if (decl is EnumDecl) {
            return (None, None, (decl as EnumDecl))
        } else {
            throw TokenVerificationException("${macroName} is only allowed for class, struct, or enum")
        }
    }

    /*
    * Verifies var decl token
    * @param input_Tk the token to verify
    * @param macroName the macro name to check against
    * @return VarDecl the input token as VarDecl type
    */
    public static func verifyVarDecl(input_Tk: Tokens, macroName: String): VarDecl {
        var decl = parseDecl(input_Tk)

        if (!(decl is VarDecl)) {
            throw TokenVerificationException("${macroName} is only allowed for class level vars")
        }

        return (decl as VarDecl).getOrThrow()
    }
}