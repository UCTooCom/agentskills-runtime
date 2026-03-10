/*
 * Test script to use FirecrawlTool directly
 */
package magic.tool

import magic.core.tool.ToolResponse
import magic.log.LogUtils
import std.collection.HashMap
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}

public class FirecrawlTest {
    public static func main(args: Array<String>): Unit {
        LogUtils.info("Starting Firecrawl test...")
        
        let tool = FirecrawlTool()
        
        // Create parameters for scraping
        let params = HashMap<String, JsonValue>()
        params.add("action", JsonString("scrape"))
        params.add("query", JsonString("https://claude.com/blog/improving-skill-creator-test-measure-and-refine-agent-skills"))
        
        LogUtils.info("Executing FirecrawlTool with parameters:")
        LogUtils.info("Action: scrape")
        LogUtils.info("URL: https://claude.com/blog/improving-skill-creator-test-measure-and-refine-agent-skills")
        
        try {
            let response = tool.invoke(params)
            LogUtils.info("Tool response received")
            LogUtils.info("Response: ${response.result}")
            
            // Save the result to file
            let filePath = "D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills/docs/improving-skill-creator-test-measure-and-refine-agent-skills-original.md"
            let file = std.fs.File.openWrite(filePath)
            file.writeUtf8(response.result)
            file.close()
            
            LogUtils.info("Result saved to: ${filePath}")
        } catch (ex: Exception) {
            LogUtils.error("Error executing FirecrawlTool: ${ex.message}")
        }
        
        LogUtils.info("Firecrawl test completed")
    }
}