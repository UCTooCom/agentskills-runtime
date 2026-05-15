/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.models.uctoo

//#region AutoCreateCode

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_data.macros.DataAssist
import f_data.{ObjectData, Data, DataConversionFlag, ObjectFields, MutableField, DataObject, f_data_tryFromData}
import f_orm.*
import json4cj.JsonValueSerializable
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull}

/**
 * AgentSkillsPO - agent_skills表持久化对象
 * 
 * 对应数据库表: agent_skills
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["agent_skills"]
public class AgentSkillsPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['name']
    public var name: String = ""

        @ORMField['description']
    public var description: Option<String> = None<String>

        @ORMField['source']
    public var source: Option<String> = None<String>

        @ORMField['source_url']
    public var sourceUrl: Option<String> = None<String>

        @ORMField['source_type']
    public var sourceType: Option<String> = None<String>

        @ORMField['branch']
    public var branch: Option<String> = None<String>

        @ORMField['tag']
    public var tag: Option<String> = None<String>

        @ORMField['commit']
    public var commit: Option<String> = None<String>

        @ORMField['version']
    public var version: Option<String> = None<String>

        @ORMField['author']
    public var author: Option<String> = None<String>

        @ORMField['homepage']
    public var homepage: Option<String> = None<String>

        @ORMField['license']
    public var license: Option<String> = None<String>

        @ORMField['keywords']
    public var keywords: Option<String> = None<String>

        @ORMField['install_path']
    public var installPath: Option<String> = None<String>

        @ORMField['status']
    public var status: Int32 = 0

        @ORMField['runtime_status']
    public var runtimeStatus: Option<String> = None<String>

        @ORMField['last_run_at']
    public var lastRunAt: Option<DateTime> = None<DateTime>

        @ORMField['run_count']
    public var runCount: Int32 = 0

        @ORMField['config']
    public var config: Option<String> = None<String>

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['allowed_tools']
    public var allowedTools: Option<String> = None<String>

        @ORMField['assets_dir_exists']
    public var assetsDirExists: Int32 = 0

        @ORMField['avg_execution_time']
    public var avgExecutionTime: Int32 = 0

        @ORMField['categories']
    public var categories: Option<String> = None<String>

        @ORMField['compatibility']
    public var compatibility: Option<String> = None<String>

        @ORMField['dependencies']
    public var dependencies: Option<String> = None<String>

        @ORMField['env_vars']
    public var envVars: Option<String> = None<String>

        @ORMField['error_count']
    public var errorCount: Int32 = 0

        @ORMField['extra_metadata']
    public var extraMetadata: Option<String> = None<String>

        @ORMField['generation_model']
    public var generationModel: Option<String> = None<String>

        @ORMField['generation_prompt']
    public var generationPrompt: Option<String> = None<String>

        @ORMField['generation_status']
    public var generationStatus: Option<String> = None<String>

        @ORMField['instructions']
    public var instructions: Option<String> = None<String>

        @ORMField['last_error']
    public var lastError: Option<String> = None<String>

        @ORMField['last_validated_at']
    public var lastValidatedAt: Option<DateTime> = None<DateTime>

        @ORMField['parameters']
    public var parameters: Option<String> = None<String>

        @ORMField['parent_skill_id']
    public var parentSkillId: Option<String> = None<String>

        @ORMField['permissions']
    public var permissions: Option<String> = None<String>

        @ORMField['references_dir_exists']
    public var referencesDirExists: Int32 = 0

        @ORMField['retry_count']
    public var retryCount: Int32 = 0

        @ORMField['scripts_dir_exists']
    public var scriptsDirExists: Int32 = 0

        @ORMField['success_count']
    public var successCount: Int32 = 0

        @ORMField['tags']
    public var tags: Option<String> = None<String>

        @ORMField['timeout']
    public var timeout: Int32 = 0

        @ORMField['validation_errors']
    public var validationErrors: Option<String> = None<String>

        @ORMField['validation_status']
    public var validationStatus: Option<String> = None<String>

    public init() {}

    public init(
                id: String,
                name: String,
                description: Option<String>,
                source: Option<String>,
                sourceUrl: Option<String>,
                sourceType: Option<String>,
                branch: Option<String>,
                tag: Option<String>,
                commit: Option<String>,
                version: Option<String>,
                author: Option<String>,
                homepage: Option<String>,
                license: Option<String>,
                keywords: Option<String>,
                installPath: Option<String>,
                status: Int32,
                runtimeStatus: Option<String>,
                lastRunAt: Option<DateTime>,
                runCount: Int32,
                config: Option<String>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>,
                allowedTools: Option<String>,
                assetsDirExists: Int32,
                avgExecutionTime: Int32,
                categories: Option<String>,
                compatibility: Option<String>,
                dependencies: Option<String>,
                envVars: Option<String>,
                errorCount: Int32,
                extraMetadata: Option<String>,
                generationModel: Option<String>,
                generationPrompt: Option<String>,
                generationStatus: Option<String>,
                instructions: Option<String>,
                lastError: Option<String>,
                lastValidatedAt: Option<DateTime>,
                parameters: Option<String>,
                parentSkillId: Option<String>,
                permissions: Option<String>,
                referencesDirExists: Int32,
                retryCount: Int32,
                scriptsDirExists: Int32,
                successCount: Int32,
                tags: Option<String>,
                timeout: Int32,
                validationErrors: Option<String>,
                validationStatus: Option<String>
    ) {
                this.id = id
                this.name = name
                this.description = description
                this.source = source
                this.sourceUrl = sourceUrl
                this.sourceType = sourceType
                this.branch = branch
                this.tag = tag
                this.commit = commit
                this.version = version
                this.author = author
                this.homepage = homepage
                this.license = license
                this.keywords = keywords
                this.installPath = installPath
                this.status = status
                this.runtimeStatus = runtimeStatus
                this.lastRunAt = lastRunAt
                this.runCount = runCount
                this.config = config
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
                this.allowedTools = allowedTools
                this.assetsDirExists = assetsDirExists
                this.avgExecutionTime = avgExecutionTime
                this.categories = categories
                this.compatibility = compatibility
                this.dependencies = dependencies
                this.envVars = envVars
                this.errorCount = errorCount
                this.extraMetadata = extraMetadata
                this.generationModel = generationModel
                this.generationPrompt = generationPrompt
                this.generationStatus = generationStatus
                this.instructions = instructions
                this.lastError = lastError
                this.lastValidatedAt = lastValidatedAt
                this.parameters = parameters
                this.parentSkillId = parentSkillId
                this.permissions = permissions
                this.referencesDirExists = referencesDirExists
                this.retryCount = retryCount
                this.scriptsDirExists = scriptsDirExists
                this.successCount = successCount
                this.tags = tags
                this.timeout = timeout
                this.validationErrors = validationErrors
                this.validationStatus = validationStatus
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("name", this.name.toJsonValue())
        map.add("description", optionToJsonValue(this.description))
        map.add("source", optionToJsonValue(this.source))
        map.add("source_url", optionToJsonValue(this.sourceUrl))
        map.add("source_type", optionToJsonValue(this.sourceType))
        map.add("branch", optionToJsonValue(this.branch))
        map.add("tag", optionToJsonValue(this.tag))
        map.add("commit", optionToJsonValue(this.commit))
        map.add("version", optionToJsonValue(this.version))
        map.add("author", optionToJsonValue(this.author))
        map.add("homepage", optionToJsonValue(this.homepage))
        map.add("license", optionToJsonValue(this.license))
        map.add("keywords", optionToJsonValue(this.keywords))
        map.add("install_path", optionToJsonValue(this.installPath))
        map.add("status", this.status.toJsonValue())
        map.add("runtime_status", optionToJsonValue(this.runtimeStatus))
        map.add("last_run_at", optionToJsonValue(this.lastRunAt))
        map.add("run_count", this.runCount.toJsonValue())
        map.add("config", optionToJsonValue(this.config))
        map.add("creator", optionToJsonValue(this.creator))
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("allowed_tools", optionToJsonValue(this.allowedTools))
        map.add("assets_dir_exists", this.assetsDirExists.toJsonValue())
        map.add("avg_execution_time", this.avgExecutionTime.toJsonValue())
        map.add("categories", optionToJsonValue(this.categories))
        map.add("compatibility", optionToJsonValue(this.compatibility))
        map.add("dependencies", optionToJsonValue(this.dependencies))
        map.add("env_vars", optionToJsonValue(this.envVars))
        map.add("error_count", this.errorCount.toJsonValue())
        map.add("extra_metadata", optionToJsonValue(this.extraMetadata))
        map.add("generation_model", optionToJsonValue(this.generationModel))
        map.add("generation_prompt", optionToJsonValue(this.generationPrompt))
        map.add("generation_status", optionToJsonValue(this.generationStatus))
        map.add("instructions", optionToJsonValue(this.instructions))
        map.add("last_error", optionToJsonValue(this.lastError))
        map.add("last_validated_at", optionToJsonValue(this.lastValidatedAt))
        map.add("parameters", optionToJsonValue(this.parameters))
        map.add("parent_skill_id", optionToJsonValue(this.parentSkillId))
        map.add("permissions", optionToJsonValue(this.permissions))
        map.add("references_dir_exists", this.referencesDirExists.toJsonValue())
        map.add("retry_count", this.retryCount.toJsonValue())
        map.add("scripts_dir_exists", this.scriptsDirExists.toJsonValue())
        map.add("success_count", this.successCount.toJsonValue())
        map.add("tags", optionToJsonValue(this.tags))
        map.add("timeout", this.timeout.toJsonValue())
        map.add("validation_errors", optionToJsonValue(this.validationErrors))
        map.add("validation_status", optionToJsonValue(this.validationStatus))
        return JsonObject(map)
    }

    /// 辅助方法：将 Option<T> 转换为 JsonValue
    private static func optionToJsonValue<T>(opt: Option<T>): JsonValue where T <: JsonValueSerializable<T> {
        if (let Some(v) <- opt) {
            return v.toJsonValue()
        } else {
            return JsonNull()
        }
    }

    /// 序列化为 JSON 字符串
    public func toJson(): String {
        return this.toJsonValue().toString()
    }

//#endregion AutoCreateCode
}
