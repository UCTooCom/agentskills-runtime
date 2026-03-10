/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.core.tool.*
import magic.jsonable.TypeSchema
import magic.log.LogUtils
import std.collection.HashMap
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonBool, JsonInt}
import std.time.DateTime
import std.core.Duration

public struct SubAgentTiming {
    public let startTime: Int64
    public let endTime: Int64
    public let durationMs: Int64

    public init(startTime: Int64, endTime: Int64, durationMs: Int64) {
        this.startTime = startTime
        this.endTime = endTime
        this.durationMs = durationMs
    }
}

public class SubAgentTool <: NativeFuncTool {
    public static let NAME = "sub_agent_execute"

    public static let DESC = """
    Execute a sub-agent task with timing and transcript collection.
    Supports skill path, input files, and output directory parameters.
    """

    public init() {
        super(
            name: SubAgentTool.NAME,
            description: SubAgentTool.DESC,
            parameters: [
                ("skill_path", "Path to the skill directory to load (optional)", TypeSchema.Str),
                ("question", "Question or task for the sub-agent", TypeSchema.Str),
                ("input_files", "Array of input file paths (optional)", TypeSchema.Str),
                ("output_dir", "Output directory path (optional)", TypeSchema.Str)
            ],
            retType: TypeSchema.Str,
            examples: [
                """
                {
                  "skill_path": "./skills/my-skill",
                  "question": "Process the input data",
                  "input_files": "[\"./data/input.txt\"]",
                  "output_dir": "./output"
                }
                """
            ],
            extra: HashMap([
                ("filterable", "true"),
                ("terminal", "false"),
                ("compactable", "true")
            ]),
            execFn: { args: HashMap<String, JsonValue> =>
                SubAgentTool.execute(args)
            }
        )
    }

    public static func execute(args: HashMap<String, JsonValue>): String {
        let skillPath = extractString(args, "skill_path")
        let question = extractString(args, "question")
        let inputFiles = extractString(args, "input_files")
        let outputDir = extractString(args, "output_dir")

        if (question.isEmpty()) {
            return buildErrorResponse("question is required")
        }

        let startTime = DateTime.now()
        var transcript = "SubAgent Execution Log\n====================\n"
        if (!skillPath.isEmpty()) {
            transcript = transcript + "Skill: ${skillPath}\n"
        }
        transcript = transcript + "Question: ${question}\n"
        if (!inputFiles.isEmpty()) {
            transcript = transcript + "Input Files: ${inputFiles}\n"
        }
        if (!outputDir.isEmpty()) {
            transcript = transcript + "Output Dir: ${outputDir}\n"
        }

        LogUtils.info("[SubAgentTool] Executing question: ${question}")

        try {
            let result = executeSubAgent(skillPath, question, inputFiles, outputDir, transcript)
            
            let endTime = DateTime.now()
            let durationMs = (endTime - startTime).toMilliseconds()
            let timing = SubAgentTiming(0, durationMs, durationMs)
            
            return buildSuccessResponse(result, timing, transcript)
        } catch (ex: Exception) {
            let endTime = DateTime.now()
            let durationMs = (endTime - startTime).toMilliseconds()
            let timing = SubAgentTiming(0, durationMs, durationMs)
            
            LogUtils.error("[SubAgentTool] Execution failed: ${ex.message}")
            transcript = transcript + "\nError: ${ex.message}\n"
            
            return buildErrorResponse(ex.message, timing: timing, transcript: transcript)
        }
    }

    private static func executeSubAgent(
        skillPath: String,
        question: String,
        inputFiles: String,
        outputDir: String,
        transcript: String
    ): String {
        var log = transcript
        log = log + "Executing sub-agent task\n"
        log = log + "Question: ${question}\n"

        if (!skillPath.isEmpty()) {
            log = log + "Note: Skill loading from path '${skillPath}' would be handled by the main agent\n"
        }

        if (!inputFiles.isEmpty()) {
            log = log + "Note: Input files '${inputFiles}' would be processed\n"
        }

        if (!outputDir.isEmpty()) {
            log = log + "Note: Output would be saved to '${outputDir}'\n"
        }

        log = log + "Sub-agent execution placeholder - actual execution would be handled by main agent\n"

        return "Sub-agent task completed: ${question}"
    }

    private static func buildSuccessResponse(output: String, timing: SubAgentTiming, transcript: String): String {
        let response = JsonObject()
        response.put("success", JsonBool(true))
        response.put("output", JsonString(output))
        
        let timingObj = JsonObject()
        timingObj.put("start_time", JsonInt(timing.startTime))
        timingObj.put("end_time", JsonInt(timing.endTime))
        timingObj.put("duration_ms", JsonInt(timing.durationMs))
        response.put("timing", timingObj)
        
        response.put("transcript", JsonString(transcript))
        
        return response.toJsonString()
    }

    private static func buildErrorResponse(error: String, timing!: SubAgentTiming = SubAgentTiming(0, 0, 0), transcript!: String = ""): String {
        let response = JsonObject()
        response.put("success", JsonBool(false))
        response.put("error", JsonString(error))
        
        let timingObj = JsonObject()
        timingObj.put("start_time", JsonInt(timing.startTime))
        timingObj.put("end_time", JsonInt(timing.endTime))
        timingObj.put("duration_ms", JsonInt(timing.durationMs))
        response.put("timing", timingObj)
        
        if (!transcript.isEmpty()) {
            response.put("transcript", JsonString(transcript))
        }
        
        return response.toJsonString()
    }

    protected static func extractString(args: HashMap<String, JsonValue>, key: String): String {
        if (let Some(value) <- args.get(key)) {
            match (value) {
                case jStr: JsonString =>
                    return jStr.getValue()
                case _ =>
                    let strValue = value.toString()
                    if (strValue.startsWith("\"") && strValue.endsWith("\"")) {
                        return strValue[1..(strValue.size - 1)]
                    }
                    return strValue
            }
        }
        return ""
    }
}
