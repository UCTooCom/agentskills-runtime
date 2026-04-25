macro package json4cj.jsonmacro

import std.ast.*

/*
* Processor for decorated class
*/
open class ClassProcessor {
    protected var globalConfig: ClassConfig

    public init(globalConfig: ClassConfig) {
        this.globalConfig = globalConfig
    }

    /*
    * Gets information from var token
    * @param vark_Tk the var token to get information from
    * @return (Token, String, String) the identifier, name, type name of the var
    */
    protected func getVarInfo(vark_Tk: VarDecl): VarInfo {
        return vark_Tk.getVarInfo()
    }

    /*
    * Gets mapped name for given var name from user defined name mapping by @JsonProperty macro
    * @param varName to get mapped name for
    * @return String the mapped name 
    */
    protected func getMappedName(varName: String): String {
        var mappedNameValue = varName
        if (globalConfig.userDefinedVarMap.contains(varName)) {
            mappedNameValue = globalConfig.userDefinedVarMap.get(varName).getOrThrow()
        }
        return mappedNameValue
    }
}