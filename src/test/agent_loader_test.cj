/*
 * Copyright (c) 2026. All rights reserved.
 */
package magic.test

import magic.agent.{AgentLoader, AgentLoadManager, AgentType}
import magic.utils.resolveRuntimeRoot
import std.io.Path

/**
 * Agent 加载器测试
 *
 * projectRoot 由 resolveRuntimeRoot() 动态解析
 * （优先环境变量 AGENTSKILLS_RUNTIME_HOME，其次进程工作目录），
 * 不再写死任何开发机绝对路径。
 */
public func testAgentLoader(): Unit {
    println("=== Testing Agent Loader ===")

    let projectRoot = resolveRuntimeRoot()

    // 测试从单个文件加载
    let loader = AgentLoader(projectRoot)

    println("\n1. Testing load from single file (AGENTS.md):")
    // 注意：match 臂不能写 `case X => { ... }` 多语句块（会被解析成 lambda 起始），
    // 故此处用 if-let 单分支表达。
    if (let Some(agent) <- loader.loadAgentFromFile(Path("${projectRoot}/AGENTS.md"))) {
        println("   ✓ Successfully loaded agent: ${agent.name}")
        println("   - Type: ${agent.agentType}")
        println("   - Description: ${agent.description}")
        println("   - Version: ${agent.version}")
        println("   - Tools: ${agent.tools.size()} items")
        println("   - Max Turns: ${agent.maxTurns}")
        println("   - Memory: ${agent.memory}")
        println("   - Background: ${agent.background}")
        println("   - Permissions: ${agent.permissions.size()} items")

        // 测试 toJson
        let json = agent.toJson()
        println("   - JSON output: ${json.toString().substring(0, 100)}...")
    } else {
        println("   ✗ Failed to load agent from AGENTS.md")
    }

    // 测试从目录加载
    println("\n2. Testing load from agents directory:")
    let skillCreatorAgentsDir = "${projectRoot}/skills/skill-creator/agents"
    let agents = loader.loadAgentsFromDir(skillCreatorAgentsDir)
    println("   Loaded ${agents.size()} agents from ${skillCreatorAgentsDir}")

    for (agent in agents) {
        println("   - ${agent.name} (${agent.agentType})")
    }

    // 测试 AgentLoadManager
    println("\n3. Testing AgentLoadManager:")
    let manager = AgentLoadManager(projectRoot)

    let dirs = [
        "${projectRoot}/skills/skill-creator/agents"
    ]

    manager.loadFromDirs(dirs)

    let allAgents = manager.getAllAgents()
    println("   Total agents managed: ${allAgents.size()}")

    // 测试按名称查找
    println("\n4. Testing get agent by name:")
    match (manager.getAgentByName("AnalyzerAgent")) {
        case Some(agent) => println("   ✓ Found AnalyzerAgent")
        case None => println("   ✗ AnalyzerAgent not found")
    }

    // 测试按类型查找
    println("\n5. Testing get agents by type:")
    let analyzerAgents = manager.getAgentsByType(AgentType.ANALYZER)
    println("   Found ${analyzerAgents.size()} analyzer agents")

    println("\n=== Agent Loader Test Complete ===")
}

/**
 * 主测试函数
 */
main(): Unit {
    testAgentLoader()
}
