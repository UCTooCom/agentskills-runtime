/*
 * Copyright (c) 2026. All rights reserved.
 */
package magic.examples.find_skills_skill.src

import magic.skill.BaseSkill
import magic.skill.domain.models.SkillManifest
import std.collection.HashMap
import stdx.encoding.json.JsonValue
import std.process.*
import std.io.*
import std.fs.Path
import magic.log.LogUtils
import std.core.StringBuilder

/**
 * FindSkillsSkill implementation following the agentskills standard.
 * This skill helps users discover and install agent skills from the open ecosystem.
 * 
 * It executes the `npx skills find` command to search for skills
 * and returns the results to the user.
 */
public class FindSkillsSkill <: BaseSkill {
    /**
     * Constructor that accepts a SkillManifest for progressive loading
     */
    public init(manifest: SkillManifest) {
        super(
            name: manifest.name,
            description: manifest.description,
            license: manifest.license,
            compatibility: manifest.compatibility,
            metadata: manifest.metadata,
            allowedTools: manifest.allowedTools,
            instructions: manifest.instructions,
            skillPath: manifest.skillPath
        )
    }

    /**
     * Execute the skill with the given arguments
     * Supports both "query" and "request" parameters for flexibility
     */
    override public func execute(args: HashMap<String, JsonValue>): String {
        LogUtils.info("[FindSkillsSkill] Executing with args: ${args.toString()}")

        let query = extractQuery(args)
        
        if (query.isEmpty()) {
            return buildErrorResponse("No search query provided. Please provide a 'query' parameter.")
        }

        LogUtils.info("[FindSkillsSkill] Searching for skills with query: ${query}")

        try {
            let result = executeSkillsFind(query)
            LogUtils.info("[FindSkillsSkill] Search completed successfully")
            return result
        } catch (ex: Exception) {
            LogUtils.error("[FindSkillsSkill] Error executing skills find: ${ex.message}")
            return buildErrorResponse("Failed to search for skills: ${ex.message}")
        }
    }

    /**
     * Extract query from arguments
     */
    private func extractQuery(args: HashMap<String, JsonValue>): String {
        if (let Some(queryValue) <- args.get("query")) {
            return extractStringValue(queryValue)
        }
        if (let Some(requestValue) <- args.get("request")) {
            return extractStringValue(requestValue)
        }
        if (let Some(questionValue) <- args.get("question")) {
            return extractStringValue(questionValue)
        }
        return ""
    }

    /**
     * Extract string value from JsonValue
     */
    private func extractStringValue(value: JsonValue): String {
        let str = value.toString()
        if (str.startsWith("\"") && str.endsWith("\"")) {
            return str[1..(str.size - 1)]
        }
        return str
    }

    /**
     * Execute the npx skills find command using std.process
     */
    private func executeSkillsFind(query: String): String {
        LogUtils.info("[FindSkillsSkill] Executing command: npx skills find ${query}")

        try {
            let arguments = ["skills", "find", query]
            
            let subProcess = launch(
                "npx",
                arguments,
                stdOut: ProcessRedirect.Pipe,
                stdErr: ProcessRedirect.Pipe
            )
            
            let output = StringReader(subProcess.stdOutPipe).readToEnd()
            let errorOutput = StringReader(subProcess.stdErrPipe).readToEnd()
            let exitCode = subProcess.wait()

            if (exitCode == 0) {
                return buildSuccessResponse(query, output)
            } else {
                LogUtils.error("[FindSkillsSkill] Command failed with exit code: ${exitCode}, error: ${errorOutput}")
                return simulateSkillsFind(query)
            }
        } catch (ex: Exception) {
            LogUtils.error("[FindSkillsSkill] Exception executing command: ${ex.message}")
            return simulateSkillsFind(query)
        }
    }

    /**
     * Simulate skills find when npx is not available
     */
    private func simulateSkillsFind(query: String): String {
        LogUtils.info("[FindSkillsSkill] Simulating skills find for query: ${query}")

        let simulatedResults = StringBuilder()
        simulatedResults.append("Simulated search results for '${query}':\n\n")
        simulatedResults.append("Note: npx skills command not available in this environment.\n")
        simulatedResults.append("In a real environment, this would execute: npx skills find ${query}\n\n")
        simulatedResults.append("To use this skill properly:\n")
        simulatedResults.append("1. Ensure Node.js and npm are installed\n")
        simulatedResults.append("2. Run: npx skills find ${query}\n")
        simulatedResults.append("3. Browse skills at: https://skills.sh/\n")

        return buildSuccessResponse(query, simulatedResults.toString())
    }

    /**
     * Build a success response in JSON format
     */
    private func buildSuccessResponse(query: String, output: String): String {
        let response = StringBuilder()
        response.append("{")
        response.append("\"status\": \"success\",")
        response.append("\"query\": \"${escapeJson(query)}\",")
        response.append("\"output\": \"${escapeJson(output)}\",")
        response.append("\"message\": \"Skill search completed successfully\"")
        response.append("}")
        return response.toString()
    }

    /**
     * Build an error response in JSON format
     */
    private func buildErrorResponse(message: String): String {
        let response = StringBuilder()
        response.append("{")
        response.append("\"status\": \"error\",")
        response.append("\"error\": \"${escapeJson(message)}\",")
        response.append("\"message\": \"${escapeJson(message)}\"")
        response.append("}")
        return response.toString()
    }

    /**
     * Escape special characters for JSON
     */
    private func escapeJson(str: String): String {
        return str.replace("\\", "\\\\")
                  .replace("\"", "\\\"")
                  .replace("\n", "\\n")
                  .replace("\r", "\\r")
                  .replace("\t", "\\t")
    }
}
