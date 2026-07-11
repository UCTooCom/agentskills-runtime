/*
 * Copyright (c) 2026. All rights reserved.
 */
package magic.agent.test

import magic.agent.{AgentLoader, AgentLoadManager, AgentType}
import std.io.Path

/**
 * Agent 加载器测试
 */
public func testAgentLoader(): Unit {
    println("=== Testing Agent Loader ===")
    
    // 测试从单个文件加载
    let loader = AgentLoader("D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime")
    
    println("\n1. Testing load from single file (AGENTS.md):")
    match (loader.loadAgentFromFile(Path("D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/AGENTS.md"))) {
        case Some(agent) => {
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
        }
        case None => {
            println("   ✗ Failed to load agent from AGENTS.md")
        }
    }
    
    // 测试从目录加载
    println("\n2. Testing load from agents directory:")
    let skillCreatorAgentsDir = "D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/skills/skill-creator/agents"
    let agents = loader.loadAgentsFromDir(skillCreatorAgentsDir)
    println("   Loaded ${agents.size()} agents from ${skillCreatorAgentsDir}")
    
    for (agent in agents) {
        println("   - ${agent.name} (${agent.agentType})")
    }
    
    // 测试 AgentLoadManager
    println("\n3. Testing AgentLoadManager:")
    let manager = AgentLoadManager("D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime")
    
    let dirs = [
        "D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/skills/skill-creator/agents"
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
