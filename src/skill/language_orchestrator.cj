/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonArray, JsonBool}
import magic.log.LogUtils

public enum ProgrammingLanguage {
    | Cangjie | TypeScript | Python | Java | Go | Rust | Custom
}

public class LanguageSkillMapping {
    public var language: ProgrammingLanguage = ProgrammingLanguage.Cangjie
    public var languageName: String = "cangjie"
    public var skillNames: ArrayList<String> = ArrayList<String>()
    public var contextSources: ArrayList<String> = ArrayList<String>()
    public var defaultModel: String = ""
    public var orchestrationTemplate: String = ""

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("language", JsonString(this.languageName))
        var skillsArr = ArrayList<JsonValue>()
        for (s in this.skillNames) { skillsArr.add(JsonString(s)) }
        map.add("skills", JsonArray(skillsArr))
        var ctxArr = ArrayList<JsonValue>()
        for (c in this.contextSources) { ctxArr.add(JsonString(c)) }
        map.add("context_sources", JsonArray(ctxArr))
        map.add("default_model", JsonString(this.defaultModel))
        map.add("orchestration_template", JsonString(this.orchestrationTemplate))
        JsonObject(map)
    }

    public static func fromJsonValue(json: JsonValue): Option<LanguageSkillMapping> {
        if (!(json is JsonObject)) { return None<LanguageSkillMapping> }
        let obj = json.asObject()
        let mapping = LanguageSkillMapping()

        if (let Some(val) <- obj.get("language")) {
            if (val is JsonString) { mapping.languageName = val.asString().getValue() }
        }
        mapping.language = parseProgrammingLanguage(mapping.languageName)

        if (let Some(val) <- obj.get("skills")) {
            if (val is JsonArray) {
                for (item in val.asArray().getItems()) {
                    if (item is JsonString) { mapping.skillNames.add(item.asString().getValue()) }
                }
            }
        }

        if (let Some(val) <- obj.get("context_sources")) {
            if (val is JsonArray) {
                for (item in val.asArray().getItems()) {
                    if (item is JsonString) { mapping.contextSources.add(item.asString().getValue()) }
                }
            }
        }

        if (let Some(val) <- obj.get("default_model")) {
            if (val is JsonString) { mapping.defaultModel = val.asString().getValue() }
        }

        if (let Some(val) <- obj.get("orchestration_template")) {
            if (val is JsonString) { mapping.orchestrationTemplate = val.asString().getValue() }
        }

        Some(mapping)
    }

    public static func parseProgrammingLanguage(s: String): ProgrammingLanguage {
        match (s.toAsciiLower()) {
            case "cangjie" => ProgrammingLanguage.Cangjie
            case "typescript" | "ts" => ProgrammingLanguage.TypeScript
            case "python" | "py" => ProgrammingLanguage.Python
            case "java" => ProgrammingLanguage.Java
            case "go" | "golang" => ProgrammingLanguage.Go
            case "rust" => ProgrammingLanguage.Rust
            case _ => ProgrammingLanguage.Custom
        }
    }

    public static func programmingLanguageToString(l: ProgrammingLanguage): String {
        match (l) {
            case ProgrammingLanguage.Cangjie => "cangjie"
            case ProgrammingLanguage.TypeScript => "typescript"
            case ProgrammingLanguage.Python => "python"
            case ProgrammingLanguage.Java => "java"
            case ProgrammingLanguage.Go => "go"
            case ProgrammingLanguage.Rust => "rust"
            case ProgrammingLanguage.Custom => "custom"
        }
    }
}

public class LanguageMappingConfig {
    private var _mappings: HashMap<String, LanguageSkillMapping>

    public init() {
        _mappings = HashMap<String, LanguageSkillMapping>()
    }

    public func getMapping(language: String): Option<LanguageSkillMapping> {
        _mappings.get(language.toAsciiLower())
    }

    public func addMapping(mapping: LanguageSkillMapping): Unit {
        _mappings.add(mapping.languageName.toAsciiLower(), mapping)
    }

    public func removeMapping(language: String): Bool {
        let key = language.toAsciiLower()
        if (_mappings.contains(key)) {
            _mappings.remove(key)
            return true
        }
        false
    }

    public func getAllMappings(): ArrayList<LanguageSkillMapping> {
        let result = ArrayList<LanguageSkillMapping>()
        for ((_, mapping) in _mappings) {
            result.add(mapping)
        }
        result
    }

    public func listSupportedLanguages(): ArrayList<String> {
        let result = ArrayList<String>()
        for ((key, _) in _mappings) {
            result.add(key)
        }
        result
    }

    public func validate(): ArrayList<String> {
        let errors = ArrayList<String>()
        for ((key, mapping) in _mappings) {
            if (mapping.skillNames.size == 0) {
                errors.add("Language '${key}' has no skills defined")
            }
            if (mapping.defaultModel.size == 0) {
                errors.add("Language '${key}' has no default model")
            }
        }
        errors
    }

    public func loadFromJson(json: JsonValue): Unit {
        if (json is JsonObject) {
            for ((key, val) in json.asObject().getFields()) {
                if (let Some(mapping) <- LanguageSkillMapping.fromJsonValue(val)) {
                    mapping.languageName = key
                    mapping.language = LanguageSkillMapping.parseProgrammingLanguage(key)
                    _mappings.add(key.toAsciiLower(), mapping)
                }
            }
        } else if (json is JsonArray) {
            for (item in json.asArray().getItems()) {
                if (let Some(mapping) <- LanguageSkillMapping.fromJsonValue(item)) {
                    _mappings.add(mapping.languageName.toAsciiLower(), mapping)
                }
            }
        }
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        for ((key, mapping) in _mappings) {
            map.add(key, mapping.toJsonValue())
        }
        JsonObject(map)
    }
}

public class LanguageContext {
    public var language: String = ""
    public var documentation: String = ""
    public var codingStandards: String = ""
    public var bestPractices: String = ""
    public var referencePaths: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func toSystemPromptFragment(): String {
        let sb = StringBuilder()
        sb.append("\n## ${this.language} Language Context\n")
        if (this.documentation.size > 0) {
            sb.append("\n### Documentation\n${this.documentation}\n")
        }
        if (this.codingStandards.size > 0) {
            sb.append("\n### Coding Standards\n${this.codingStandards}\n")
        }
        if (this.bestPractices.size > 0) {
            sb.append("\n### Best Practices\n${this.bestPractices}\n")
        }
        if (this.referencePaths.size > 0) {
            sb.append("\n### Reference Paths\n")
            for (p in this.referencePaths) {
                sb.append("- ${p}\n")
            }
        }
        sb.toString()
    }
}

public class LanguageContextProvider {
    private var _contexts: HashMap<String, LanguageContext>
    private let _loadContextFromSkill: (String) -> Option<LanguageContext>

    public init(loadContextFromSkill!: (String) -> Option<LanguageContext>) {
        _contexts = HashMap<String, LanguageContext>()
        _loadContextFromSkill = loadContextFromSkill
    }

    public func loadContext(language: String): Option<LanguageContext> {
        let key = language.toAsciiLower()
        if (let Some(ctx) <- _contexts.get(key)) {
            return Some(ctx)
        }
        _loadContextFromSkill(language)
    }

    public func registerContext(language: String, context: LanguageContext): Unit {
        _contexts.add(language.toAsciiLower(), context)
    }

    public func getContext(language: String): Option<LanguageContext> {
        _contexts.get(language.toAsciiLower())
    }

    public func injectContext(systemPrompt: String, language: String): String {
        if (let Some(ctx) <- loadContext(language)) {
            return systemPrompt + ctx.toSystemPromptFragment()
        }
        systemPrompt
    }
}

public class OrchestrationRequest {
    public var language: String = "cangjie"
    public var task: String = ""
    public var input: Option<JsonValue> = None<JsonValue>
    public var modelOverride: Option<String> = None<String>
    public var background: Bool = false

    public init() {}
}

public class OrchestrationResult {
    public var language: String = ""
    public var compositionName: String = ""
    public var status: String = "pending"
    public var stepResults: ArrayList<JsonValue> = ArrayList<JsonValue>()
    public var finalOutput: Option<JsonValue> = None<JsonValue>
    public var languageContext: Option<LanguageContext> = None<LanguageContext>

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("language", JsonString(this.language))
        map.add("composition_name", JsonString(this.compositionName))
        map.add("status", JsonString(this.status))
        var resultsArr = ArrayList<JsonValue>()
        for (r in this.stepResults) { resultsArr.add(r) }
        map.add("step_results", JsonArray(resultsArr))
        if (let Some(output) <- this.finalOutput) {
            map.add("final_output", output)
        }
        JsonObject(map)
    }
}

public class LanguageOrchestrator {
    private let _mappingConfig: LanguageMappingConfig
    private let _contextProvider: LanguageContextProvider
    private let _executeComposition: (String, Option<JsonValue>, Option<String>) -> Option<JsonValue>

    public init(mappingConfig!: LanguageMappingConfig, contextProvider!: LanguageContextProvider, executeComposition!: (String, Option<JsonValue>, Option<String>) -> Option<JsonValue>) {
        _mappingConfig = mappingConfig
        _contextProvider = contextProvider
        _executeComposition = executeComposition
    }

    public func orchestrate(request: OrchestrationRequest): OrchestrationResult {
        LogUtils.info("[LanguageOrchestrator] Orchestrating: language=${request.language}, task=${request.task}")

        let result = OrchestrationResult()
        result.language = request.language

        let mappingOpt = _mappingConfig.getMapping(request.language)
        if (mappingOpt.isNone()) {
            result.status = "error"
            LogUtils.error("[LanguageOrchestrator] No mapping found for language: ${request.language}")
            return result
        }

        let mapping = mappingOpt.getOrThrow()
        result.compositionName = mapping.orchestrationTemplate

        let contextOpt = _contextProvider.loadContext(request.language)
        result.languageContext = contextOpt

        let compositionName = if (mapping.orchestrationTemplate.size > 0) { mapping.orchestrationTemplate } else { mapping.skillNames[0] }
        let output = _executeComposition(compositionName, request.input, request.modelOverride)

        if (let Some(o) <- output) {
            result.status = "completed"
            result.finalOutput = Some(o)
        } else {
            result.status = "failed"
        }

        LogUtils.info("[LanguageOrchestrator] Orchestration ${result.status}: language=${request.language}")
        result
    }

    public func getMapping(language: String): Option<LanguageSkillMapping> {
        _mappingConfig.getMapping(language)
    }

    public func registerMapping(mapping: LanguageSkillMapping): Unit {
        _mappingConfig.addMapping(mapping)
    }

    public func listSupportedLanguages(): ArrayList<String> {
        _mappingConfig.listSupportedLanguages()
    }
}