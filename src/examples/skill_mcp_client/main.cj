/*
 * Copyright (c) 2024-2025. UCToo Team. All rights reserved.
 *
 * MCP Client for testing skill execution through uctoo_api_mcp_server
 * This client demonstrates how to use the find-skills skill
 */

package magic.examples.skill_mcp_client

import magic.dsl.*
import magic.prelude.*
import magic.config.Config
import std.fs.Path

@agent[
    model: "maas:qwen3-coder-480b-a35b-instruct",
    tools: [
        stdioMCP("cjpm run --skip-build --name magic.examples.uctoo_api_mcp_server")
    ]
]
class SkillExecutionMCPClient {
    @prompt(
        "你是一个专门执行技能的智能助手。你可以帮助用户发现、搜索和执行已安装的技能。\n" +
        "\n" +
        "可用的工具：\n" +
        "- listAvailableSkills: 列出所有可用的技能\n" +
        "- executeSkill: 执行指定技能，需要提供技能名称和参数\n" +
        "\n" +
        "当用户请求：\n" +
        "1. 列出技能时，调用 listAvailableSkills\n" +
        "2. 搜索技能时，调用 executeSkill 并传入 skillId='find-skills' 和 parameters='{\"query\": \"搜索关键词\"}'\n" +
        "3. 执行其他技能时，调用 executeSkill 并传入相应的技能名称和参数\n" +
        "\n" +
        "示例：\n" +
        "- 用户: '帮我找一个关于react测试的技能' -> executeSkill('find-skills', '{\"query\": \"react testing\"}')\n" +
        "- 用户: '搜索PDF相关的技能' -> executeSkill('find-skills', '{\"query\": \"pdf\"}')\n" +
        "- 用户: '有哪些可用的技能?' -> listAvailableSkills()\n" +
        "\n" +
        "请根据用户的请求选择合适的工具并正确提取参数。"
    )
}

main() {
    Config.env.load(Path("./.env"))

    Config.logLevel = "INFO"
    Config.logFile = "./logs/skill-mcp-client.log"

    let stepfunApiKey = Config.env["STEPFUN_API_KEY"]
    if (stepfunApiKey.isSome()) {
        Config.env["STEPFUN_API_KEY"] = stepfunApiKey.getOrThrow()
    } else {
        println("Warning: STEPFUN_API_KEY not found in environment variables")
    }

    if (!Config.validateModelConfig()) {
        println("Error: Model configuration is incomplete. Please check your .env file.")
        return
    }

    let agent = SkillExecutionMCPClient()

    println("========================================")
    println("技能执行 MCP 客户端测试")
    println("========================================")
    println("")

    println("测试 1: 列出所有可用技能")
    println("----------------------------------------")
    let result1 = agent.chat("列出所有可用的技能")
    println("结果: " + result1)
    println("")

    println("测试 2: 搜索 React 测试相关的技能")
    println("----------------------------------------")
    let result2 = agent.chat("帮我找一个关于react测试的技能")
    println("结果: " + result2)
    println("")

    println("测试 3: 搜索 PDF 相关的技能")
    println("----------------------------------------")
    let result3 = agent.chat("搜索PDF相关的技能")
    println("结果: " + result3)
    println("")

    println("测试 4: 搜索部署相关的技能")
    println("----------------------------------------")
    let result4 = agent.chat("有没有部署相关的技能?")
    println("结果: " + result4)
    println("")

    println("测试 5: 搜索代码审查相关的技能")
    println("----------------------------------------")
    let result5 = agent.chat("我想找一个代码审查的技能")
    println("结果: " + result5)
    println("")

    println("========================================")
    println("测试完成!")
    println("========================================")
}
