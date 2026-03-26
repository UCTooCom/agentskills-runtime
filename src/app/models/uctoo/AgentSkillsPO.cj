/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.models.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_data.macros.DataAssist
import f_data.{ObjectData, Data, DataConversionFlag, ObjectFields, MutableField, DataObject, f_data_tryFromData}
import f_orm.*

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * AgentSkillsPO - agent_skills表持久化对象
 * 
 * 对应数据库表: agent_skills
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["agent_skills"]
public class AgentSkillsPO {
        @ORMField[true 'id']
    private var id: String = ""

        @ORMField['name']
    private var name: String = ""

        @ORMField['description']
    private var description: ?String = None<String>

        @ORMField['source']
    private var source: ?String = None<String>

        @ORMField['source_url']
    private var sourceUrl: ?String = None<String>

        @ORMField['source_type']
    private var sourceType: ?String = None<String>

        @ORMField['branch']
    private var branch: ?String = None<String>

        @ORMField['tag']
    private var tag: ?String = None<String>

        @ORMField['commit']
    private var commit: ?String = None<String>

        @ORMField['version']
    private var version: ?String = None<String>

        @ORMField['author']
    private var author: ?String = None<String>

        @ORMField['homepage']
    private var homepage: ?String = None<String>

        @ORMField['license']
    private var license: ?String = None<String>

        @ORMField['keywords']
    private var keywords: ?String = None<String>

        @ORMField['tags']
    private var tags: ?String = None<String>

        @ORMField['categories']
    private var categories: ?String = None<String>

        @ORMField['install_path']
    private var installPath: ?String = None<String>

        @ORMField['compatibility']
    private var compatibility: ?String = None<String>

        @ORMField['allowed_tools']
    private var allowedTools: ?String = None<String>

        @ORMField['dependencies']
    private var dependencies: ?String = None<String>

        @ORMField['permissions']
    private var permissions: ?String = None<String>

        @ORMField['parameters']
    private var parameters: ?String = None<String>

        @ORMField['instructions']
    private var instructions: ?String = None<String>

        @ORMField['scripts_dir_exists']
    private var scriptsDirExists: ?Int32 = None<Int32>

        @ORMField['references_dir_exists']
    private var referencesDirExists: ?Int32 = None<Int32>

        @ORMField['assets_dir_exists']
    private var assetsDirExists: ?Int32 = None<Int32>

        @ORMField['status']
    private var status: ?Int32 = None<Int32>

        @ORMField['runtime_status']
    private var runtimeStatus: ?String = None<String>

        @ORMField['validation_status']
    private var validationStatus: ?String = None<String>

        @ORMField['validation_errors']
    private var validationErrors: ?String = None<String>

        @ORMField['last_validated_at']
    private var lastValidatedAt: ?DateTime = None<DateTime>

        @ORMField['config']
    private var config: ?String = None<String>

        @ORMField['env_vars']
    private var envVars: ?String = None<String>

        @ORMField['timeout']
    private var timeout: ?Int32 = None<Int32>

        @ORMField['retry_count']
    private var retryCount: ?Int32 = None<Int32>

        @ORMField['run_count']
    private var runCount: ?Int32 = None<Int32>

        @ORMField['success_count']
    private var successCount: ?Int32 = None<Int32>

        @ORMField['error_count']
    private var errorCount: ?Int32 = None<Int32>

        @ORMField['last_run_at']
    private var lastRunAt: ?DateTime = None<DateTime>

        @ORMField['last_error']
    private var lastError: ?String = None<String>

        @ORMField['avg_execution_time']
    private var avgExecutionTime: ?Int32 = None<Int32>

        @ORMField['generation_prompt']
    private var generationPrompt: ?String = None<String>

        @ORMField['generation_model']
    private var generationModel: ?String = None<String>

        @ORMField['generation_status']
    private var generationStatus: ?String = None<String>

        @ORMField['parent_skill_id']
    private var parentSkillId: ?String = None<String>

        @ORMField['extra_metadata']
    private var extraMetadata: ?String = None<String>

        @ORMField['creator']
    private var creator: ?String = None<String>

        @ORMField['created_at']
    private var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    private var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    private var deletedAt: ?DateTime = None<DateTime>
    
    public init() {}
    
    public init(
                id: String,
        name: String,
        description: ?String,
        source: ?String,
        sourceUrl: ?String,
        sourceType: ?String,
        branch: ?String,
        tag: ?String,
        commit: ?String,
        version: ?String,
        author: ?String,
        homepage: ?String,
        license: ?String,
        keywords: ?String,
        tags: ?String,
        categories: ?String,
        installPath: ?String,
        compatibility: ?String,
        allowedTools: ?String,
        dependencies: ?String,
        permissions: ?String,
        parameters: ?String,
        instructions: ?String,
        scriptsDirExists: ?Int32,
        referencesDirExists: ?Int32,
        assetsDirExists: ?Int32,
        status: ?Int32,
        runtimeStatus: ?String,
        validationStatus: ?String,
        validationErrors: ?String,
        lastValidatedAt: ?DateTime,
        config: ?String,
        envVars: ?String,
        timeout: ?Int32,
        retryCount: ?Int32,
        runCount: ?Int32,
        successCount: ?Int32,
        errorCount: ?Int32,
        lastRunAt: ?DateTime,
        lastError: ?String,
        avgExecutionTime: ?Int32,
        generationPrompt: ?String,
        generationModel: ?String,
        generationStatus: ?String,
        parentSkillId: ?String,
        extraMetadata: ?String,
        creator: ?String,
        createdAt: DateTime,
        updatedAt: DateTime,
        deletedAt: ?DateTime
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
        this.tags = tags
        this.categories = categories
        this.installPath = installPath
        this.compatibility = compatibility
        this.allowedTools = allowedTools
        this.dependencies = dependencies
        this.permissions = permissions
        this.parameters = parameters
        this.instructions = instructions
        this.scriptsDirExists = scriptsDirExists
        this.referencesDirExists = referencesDirExists
        this.assetsDirExists = assetsDirExists
        this.status = status
        this.runtimeStatus = runtimeStatus
        this.validationStatus = validationStatus
        this.validationErrors = validationErrors
        this.lastValidatedAt = lastValidatedAt
        this.config = config
        this.envVars = envVars
        this.timeout = timeout
        this.retryCount = retryCount
        this.runCount = runCount
        this.successCount = successCount
        this.errorCount = errorCount
        this.lastRunAt = lastRunAt
        this.lastError = lastError
        this.avgExecutionTime = avgExecutionTime
        this.generationPrompt = generationPrompt
        this.generationModel = generationModel
        this.generationStatus = generationStatus
        this.parentSkillId = parentSkillId
        this.extraMetadata = extraMetadata
        this.creator = creator
        this.createdAt = createdAt
        this.updatedAt = updatedAt
        this.deletedAt = deletedAt
    }
    
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
                sb.append("\"id\":\"${id}\",")
        sb.append("\"name\":\"${name}\",")
        if (let Some(v) <- description) {
            sb.append("\"description\":\"${v}\",")
        } else {
            sb.append("\"description\":\"\",")
        }
        if (let Some(v) <- source) {
            sb.append("\"source\":\"${v}\",")
        } else {
            sb.append("\"source\":\"\",")
        }
        if (let Some(v) <- sourceUrl) {
            sb.append("\"source_url\":\"${v}\",")
        } else {
            sb.append("\"source_url\":\"\",")
        }
        if (let Some(v) <- sourceType) {
            sb.append("\"source_type\":\"${v}\",")
        } else {
            sb.append("\"source_type\":\"\",")
        }
        if (let Some(v) <- branch) {
            sb.append("\"branch\":\"${v}\",")
        } else {
            sb.append("\"branch\":\"\",")
        }
        if (let Some(v) <- tag) {
            sb.append("\"tag\":\"${v}\",")
        } else {
            sb.append("\"tag\":\"\",")
        }
        if (let Some(v) <- commit) {
            sb.append("\"commit\":\"${v}\",")
        } else {
            sb.append("\"commit\":\"\",")
        }
        if (let Some(v) <- version) {
            sb.append("\"version\":\"${v}\",")
        } else {
            sb.append("\"version\":\"\",")
        }
        if (let Some(v) <- author) {
            sb.append("\"author\":\"${v}\",")
        } else {
            sb.append("\"author\":\"\",")
        }
        if (let Some(v) <- homepage) {
            sb.append("\"homepage\":\"${v}\",")
        } else {
            sb.append("\"homepage\":\"\",")
        }
        if (let Some(v) <- license) {
            sb.append("\"license\":\"${v}\",")
        } else {
            sb.append("\"license\":\"\",")
        }
        if (let Some(v) <- keywords) {
            sb.append("\"keywords\":\"${v}\",")
        } else {
            sb.append("\"keywords\":\"\",")
        }
        if (let Some(v) <- tags) {
            sb.append("\"tags\":\"${v}\",")
        } else {
            sb.append("\"tags\":\"\",")
        }
        if (let Some(v) <- categories) {
            sb.append("\"categories\":\"${v}\",")
        } else {
            sb.append("\"categories\":\"\",")
        }
        if (let Some(v) <- installPath) {
            sb.append("\"install_path\":\"${v}\",")
        } else {
            sb.append("\"install_path\":\"\",")
        }
        if (let Some(v) <- compatibility) {
            sb.append("\"compatibility\":\"${v}\",")
        } else {
            sb.append("\"compatibility\":\"\",")
        }
        if (let Some(v) <- allowedTools) {
            sb.append("\"allowed_tools\":\"${v}\",")
        } else {
            sb.append("\"allowed_tools\":\"\",")
        }
        if (let Some(v) <- dependencies) {
            sb.append("\"dependencies\":\"${v}\",")
        } else {
            sb.append("\"dependencies\":\"\",")
        }
        if (let Some(v) <- permissions) {
            sb.append("\"permissions\":\"${v}\",")
        } else {
            sb.append("\"permissions\":\"\",")
        }
        if (let Some(v) <- parameters) {
            sb.append("\"parameters\":\"${v}\",")
        } else {
            sb.append("\"parameters\":\"\",")
        }
        if (let Some(v) <- instructions) {
            sb.append("\"instructions\":\"${v}\",")
        } else {
            sb.append("\"instructions\":\"\",")
        }
        sb.append("\"scripts_dir_exists\":${scriptsDirExists},")
        sb.append("\"references_dir_exists\":${referencesDirExists},")
        sb.append("\"assets_dir_exists\":${assetsDirExists},")
        sb.append("\"status\":${status},")
        if (let Some(v) <- runtimeStatus) {
            sb.append("\"runtime_status\":\"${v}\",")
        } else {
            sb.append("\"runtime_status\":\"\",")
        }
        if (let Some(v) <- validationStatus) {
            sb.append("\"validation_status\":\"${v}\",")
        } else {
            sb.append("\"validation_status\":\"\",")
        }
        if (let Some(v) <- validationErrors) {
            sb.append("\"validation_errors\":\"${v}\",")
        } else {
            sb.append("\"validation_errors\":\"\",")
        }
        if (let Some(v) <- lastValidatedAt) {
            sb.append("\"last_validated_at\":\"${v}\",")
        } else {
            sb.append("\"last_validated_at\":\"\",")
        }
        if (let Some(v) <- config) {
            sb.append("\"config\":\"${v}\",")
        } else {
            sb.append("\"config\":\"\",")
        }
        if (let Some(v) <- envVars) {
            sb.append("\"env_vars\":\"${v}\",")
        } else {
            sb.append("\"env_vars\":\"\",")
        }
        sb.append("\"timeout\":${timeout},")
        sb.append("\"retry_count\":${retryCount},")
        sb.append("\"run_count\":${runCount},")
        sb.append("\"success_count\":${successCount},")
        sb.append("\"error_count\":${errorCount},")
        if (let Some(v) <- lastRunAt) {
            sb.append("\"last_run_at\":\"${v}\",")
        } else {
            sb.append("\"last_run_at\":\"\",")
        }
        if (let Some(v) <- lastError) {
            sb.append("\"last_error\":\"${v}\",")
        } else {
            sb.append("\"last_error\":\"\",")
        }
        sb.append("\"avg_execution_time\":${avgExecutionTime},")
        if (let Some(v) <- generationPrompt) {
            sb.append("\"generation_prompt\":\"${v}\",")
        } else {
            sb.append("\"generation_prompt\":\"\",")
        }
        if (let Some(v) <- generationModel) {
            sb.append("\"generation_model\":\"${v}\",")
        } else {
            sb.append("\"generation_model\":\"\",")
        }
        if (let Some(v) <- generationStatus) {
            sb.append("\"generation_status\":\"${v}\",")
        } else {
            sb.append("\"generation_status\":\"\",")
        }
        if (let Some(v) <- parentSkillId) {
            sb.append("\"parent_skill_id\":\"${v}\",")
        } else {
            sb.append("\"parent_skill_id\":\"\",")
        }
        if (let Some(v) <- extraMetadata) {
            sb.append("\"extra_metadata\":\"${v}\",")
        } else {
            sb.append("\"extra_metadata\":\"\",")
        }
        if (let Some(v) <- creator) {
            sb.append("\"creator\":\"${v}\",")
        } else {
            sb.append("\"creator\":\"\",")
        }
        sb.append("\"created_at\":\"${createdAt}\",")
        sb.append("\"updated_at\":\"${updatedAt}\",")
        if (let Some(v) <- deletedAt) {
            sb.append("\"deleted_at\":\"${v}\"")
        } else {
            sb.append("\"deleted_at\":\"\"")
        }
        sb.append("}")
        return sb.toString()
    }
}
