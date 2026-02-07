/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */
package magic.prompt

import std.regex.{Regex, MatchData}
import std.collection.{HashMap, map, collectArray}

class TemplateEngineException <: Exception {
    TemplateEngineException(msg: String) {
        super(msg)
    }
}

/**
 * A context for template rendering, which holds variables and arrays.
 */
private class Context {
    private let variables: HashMap<String, String>
    private let arrays: HashMap<String, Array<String>>

    init(variables!: HashMap<String, String> = HashMap<String, String>(),
         arrays!: HashMap<String, Array<String>> = HashMap<String, Array<String>>()) {
        this.variables = variables
        this.arrays = arrays
    }

    func set(key: String, value: String): Unit {
        variables.add(key, value)
    }

    func set(key: String, value: Array<String>): Unit {
        arrays.add(key, value)
    }

    func get(key: String): Option<String> {
        return variables.get(key)
    }

    func getArray(key: String): Option<Array<String>> {
        return arrays.get(key)
    }

    func clone(): Context {
        return Context(
            variables: this.variables.clone(),
            arrays: this.arrays.clone()
        )
    }

    func dump(): Unit {
        println("Variables:")
        for ((key, value) in this.variables) {
            println("  ${key} = ${value}")
        }
        println("Arrays:")
        for ((key, array) in this.arrays) {
            println("  ${key} = ${array}]")
        }
    }
}

/**
 * This code implements a simple template engine that supports variable substitution and loops.
 */
private class TemplateEngine {
    private static const ESCAPED_NEWLINE = "#^#"

    private let context = Context()

    public func set(key: String, value: String): This {
        this.context.set(key, value)
        return this
    }

    public func set(key: String, value: Array<String> ): This {
        this.context.set(key, value)
        return this
    }

    public func render(template: String): String {
        return this.doRender(template, this.context)
    }

    private func doRender(template: String, context: Context): String {
        let template2 = this.renderLoops(template, context)
        // println("Template after rendering loops: `${template2}`")
        return this.renderVariables(template2, context)
    }

    private func renderLoops(template: String, context: Context): String {
        // Since the regex does not support DOTALL, we replace all newlines with a special symbol
        let template2 = template.replace("\n", ESCAPED_NEWLINE)
        // Regex to match loops in the format "{for item in array}...{/for}"
        let regex = Regex("{\\s*for\\s+(\\w+)\\s+in\\s+(\\w+)\\s*}(.*?){\\s*/for\\s*}")

        let matcher = regex.matcher(template2)
        // Split "...{for ...}xxx{/for}...{for ...}xxx{/for}..."
        let subStrings = matcher.split()
        // And find all variables
        let loops: Array<MatchData> = matcher.findAll() ?? []
        if (subStrings.size != loops.size + 1) {
            throw TemplateEngineException("Template format error: the number of loops does not match the number of substrings")
        }
        // Render loop content and construct the final string
        let sb = StringBuilder()
        sb.append(subStrings[0])
        for (i in 0..loops.size) {
            let loopContent = this.renderLoop(loops[i], context)
            sb.append(loopContent)
            sb.append(subStrings[i+1])
        }
        // Replace the special symbol with newlines
        return sb.toString().replace(ESCAPED_NEWLINE, "\n")
    }

    private func renderLoop(loop: MatchData, context: Context): String {
        let sb = StringBuilder()
        let itemVar = loop.matchString(1)
        let arrayName = loop.matchString(2)
        var loopBody = loop.matchString(3)
        // Remove prefix newline (aka. the special symbol) and suffix whitespaces
        if (loopBody.startsWith(ESCAPED_NEWLINE)) {
            loopBody = loopBody[3..]
        }
        if (loopBody.trimAsciiEnd().endsWith(ESCAPED_NEWLINE)) {
            loopBody = loopBody.trimAsciiEnd()
        }

        let array = context.getArray(arrayName).getOrThrow({ =>
            throw TemplateEngineException("Array `${arrayName}` is not set in the context")
        })

        let loopContent = StringBuilder()
        for (item in array) {
            // Clone the context
            let loopContext = context.clone()
            // Set the loop variable
            loopContext.set(itemVar, item)
            loopContent.append(this.doRender(loopBody, loopContext))
        }
        return loopContent.toString()
    }

    private func renderVariables(template: String, context: Context): String {
        // Regex to match variables in the format "{ varName }" but not "${ varName }"
        let regex = Regex("(?:^|[^$]){\\s*([_a-zA-Z][_a-zA-Z0-9]*)\\s*}")
        let matcher = regex.matcher(template)
        // Split "... {var1}...{var2}...{varN}..."
        let subStrings = matcher.split()
        // And find all variables
        let vars = match (matcher.findAll()) {
            case Some(mdArray) =>
                mdArray |> map { md => md.matchString(1) } |> collectArray
            case None => Array<String>()
        }
        if (subStrings.size != vars.size + 1) {
            throw TemplateEngineException("Template format error: the number of variables does not match the number of substrings")
        }
        // Replace variables with their values and construct the final string
        let sb = StringBuilder()
        sb.append(subStrings[0])
        for (i in 0..vars.size) {
            sb.append(context.get(vars[i]).getOrThrow({ =>
                context.dump()
                throw TemplateEngineException("Variable `${vars[i]}` is not set")
            }))
            sb.append(subStrings[i+1])
        }
        return sb.toString()
    }
}

/**
 * A template interface for formatting strings with variables.
 * It supports both array of key-value pairs and a HashMap for variable substitution.
 */
public interface Template {
    func format(kv: Array<(String, ToString)>): String
    func format(kv: HashMap<String, ToString>): String
}

extend String <: Template {
    public func format(kv: Array<(String, ToString)>): String {
        let map = HashMap<String, ToString>(kv)
        return this.format(map)
    }

    public func format(kv: HashMap<String, ToString>): String {
        return formatWithRegex(kv)
    }

    private func formatWithTemplateEngine(kv: HashMap<String, ToString>): String {
        let engine = TemplateEngine()
        for ((key, value) in kv) {
            engine.set(key, value.toString())
        }
        return engine.render(this)
    }

    private func formatWithRegex(kv: HashMap<String, ToString>): String {
       let regex = Regex("{\\s*([_a-zA-Z][_a-zA-Z0-9]+)\\s*}")
        let matcher = regex.matcher(this)
        let subStrings = matcher.split()
        let keys = match (matcher.findAll()) {
            case Some(mdArray) =>
                Array<String>(mdArray.size, { i: Int64 =>
                    mdArray[i].matchString(1)
                })
            case None => Array<String>()
        }
        if (subStrings.size != keys.size + 1) {
            throw Exception("String format error")
        }
        // "... {key1}...{key2}...{keyN}..."
        let sb = StringBuilder()
        sb.append(subStrings[0])
        for (i in 0..keys.size) {
            sb.append(kv[keys[i]])
            sb.append(subStrings[i+1])
        }
        return sb.toString()
    }
}