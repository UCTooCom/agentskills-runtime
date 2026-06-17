/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.skill

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.core.skill.SkillManager
import magic.skill.{StandardSkillValidator, SkillExecutionEngine, CompositeSkillToolManager}
import magic.log.LogUtils
import stdx.encoding.json.*
import std.collection.{ArrayList, HashMap}
import std.time.DateTime

public class SkillValidationController {
    private let validator = StandardSkillValidator()
    private let executionEngine = SkillExecutionEngine()

    public func validate(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            let jsonObj = JsonValue.fromStr(body).asObject()
            let skillName = _getStr(jsonObj, "skillName", "")

            if (skillName.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"skillName is required\"}")
                return
            }

            let skillManager = _getSkillManager()
            match (skillManager.getSkill(skillName)) {
                case Some(skill) =>
                    let (isValid, errors) = validator.validateSkill(skill)

                    let data = JsonObject()
                    data.put("skillName", JsonString(skillName))
                    data.put("isValid", JsonBool(isValid))

                    let errorsArray = JsonArray()
                    for (err in errors) {
                        errorsArray.add(JsonString(err))
                    }
                    data.put("errors", errorsArray)

                    let result = JsonObject()
                    result.put("success", JsonBool(true))
                    result.put("data", data)
                    res.status(200).json(result.toString())
                case None =>
                    res.status(404).json("{\"success\":false,\"reason\":\"Skill not found: ${skillName}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("SkillValidation validate error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func validateSecurity(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            let jsonObj = JsonValue.fromStr(body).asObject()
            let skillName = _getStr(jsonObj, "skillName", "")

            if (skillName.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"skillName is required\"}")
                return
            }

            let skillManager = _getSkillManager()
            match (skillManager.getSkill(skillName)) {
                case Some(skill) =>
                    let (isValid, errors) = validator.validateSkillWithSecurityChecks(skill)

                    let data = JsonObject()
                    data.put("skillName", JsonString(skillName))
                    data.put("isValid", JsonBool(isValid))
                    data.put("isSecure", JsonBool(isValid))

                    let errorsArray = JsonArray()
                    for (err in errors) {
                        errorsArray.add(JsonString(err))
                    }
                    data.put("securityIssues", errorsArray)

                    let result = JsonObject()
                    result.put("success", JsonBool(true))
                    result.put("data", data)
                    res.status(200).json(result.toString())
                case None =>
                    res.status(404).json("{\"success\":false,\"reason\":\"Skill not found: ${skillName}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("SkillValidation validateSecurity error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func executeSecure(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            let jsonObj = JsonValue.fromStr(body).asObject()
            let skillName = _getStr(jsonObj, "skillName", "")
            let argsStr = _getStr(jsonObj, "args", "{}")

            if (skillName.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"skillName is required\"}")
                return
            }

            let skillManager = _getSkillManager()
            match (skillManager.getSkill(skillName)) {
                case Some(skill) =>
                    let args = HashMap<String, JsonValue>()
                    try {
                        let argsJson = JsonValue.fromStr(argsStr).asObject()
                        args.add("_raw", argsJson)
                    } catch (_: Exception) {}

                    let execResult = executionEngine.executeSkillSecurely(skill, args)

                    let data = JsonObject()
                    data.put("skillName", JsonString(skillName))
                    data.put("success", JsonBool(execResult.success))
                    if (execResult.success) {
                        data.put("output", JsonString(execResult.output))
                    } else {
                        let errStr = match (execResult.error) { case Some(e) => e; case None => "" }
                        data.put("error", JsonString(errStr))
                    }
                    data.put("executionTime", JsonInt(execResult.executionTime))

                    let result = JsonObject()
                    result.put("success", JsonBool(true))
                    result.put("data", data)
                    res.status(200).json(result.toString())
                case None =>
                    res.status(404).json("{\"success\":false,\"reason\":\"Skill not found: ${skillName}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("SkillValidation executeSecure error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func validateAll(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let skillManager = _getSkillManager()
            let skills = skillManager.availableSkills
            let resultsArray = JsonArray()
            var validCount: Int64 = 0
            var invalidCount: Int64 = 0

            let skillList = skills.values()
            for (skill in skillList) {
                let (isValid, errors) = validator.validateSkill(skill)

                if (isValid) {
                    validCount = validCount + 1
                } else {
                    invalidCount = invalidCount + 1
                }

                let obj = JsonObject()
                obj.put("skillName", JsonString(skill.name))
                obj.put("isValid", JsonBool(isValid))

                let errorsArray = JsonArray()
                for (err in errors) {
                    errorsArray.add(JsonString(err))
                }
                obj.put("errors", errorsArray)
                resultsArray.add(obj)
            }

            let data = JsonObject()
            data.put("totalSkills", JsonInt(Int64(skills.size)))
            data.put("validCount", JsonInt(validCount))
            data.put("invalidCount", JsonInt(invalidCount))
            data.put("results", resultsArray)

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", data)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            LogUtils.error("SkillValidation validateAll error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    private func _getSkillManager(): SkillManager {
        CompositeSkillToolManager()
    }

    private func _getStr(jsonObj: JsonObject, key: String, default: String): String {
        match (jsonObj.get(key)) {
            case Some(v) => if (v is JsonString) { v.asString().getValue() } else { default }
            case None => default
        }
    }
}
