/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.core.tool.ToolManager
import magic.log.LogUtils

public class BuiltinToolsRegistry {
    public static let VERSION = "1.0.0"

    public static func registerAll(toolManager: ToolManager): Unit {
        LogUtils.info("[BuiltinToolsRegistry] Registering all builtin tools...")
        
        registerHttpTools(toolManager)
        registerFileTools(toolManager)
        registerWebTools(toolManager)
        registerVisionTools(toolManager)
        registerSkillTools(toolManager)
        registerCodeGenTools(toolManager)
        registerCliTools(toolManager)

        
        LogUtils.info("[BuiltinToolsRegistry] All builtin tools registered successfully")
    }

    public static func registerFileTools(toolManager: ToolManager): Unit {
        toolManager.addTool(FileReadTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: FileReadTool")
        
        toolManager.addTool(FileWriteTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: FileWriteTool")
        
        toolManager.addTool(FileEditTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: FileEditTool")
        
        toolManager.addTool(FileDeleteTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: FileDeleteTool")
        
        toolManager.addTool(FileCopyTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: FileCopyTool")
        
        toolManager.addTool(FileMoveTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: FileMoveTool")
        
        toolManager.addTool(FileSearchTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: FileSearchTool")
        
        toolManager.addTool(DirectoryListTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: DirectoryListTool")
        
        toolManager.addTool(DirectoryCreateTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: DirectoryCreateTool")
        
        LogUtils.info("[BuiltinToolsRegistry] File tools registered")
    }

    public static func registerHttpTools(toolManager: ToolManager): Unit {
        toolManager.addTool(HttpTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: HttpTool")
        
        LogUtils.info("[BuiltinToolsRegistry] HTTP tools registered")
    }

    public static func registerWebTools(toolManager: ToolManager): Unit {
        toolManager.addTool(WebFetchTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: WebFetchTool")
        

        LogUtils.info("[BuiltinToolsRegistry] Web tools registered")
    }

    /**
     * 视觉工具：把图片交给原生多模态模型理解（vision 直传）。
     * 补齐此前「模型支持视觉、传输层也支持 image_url，但 agent 无工具可用」的断点。
     */
    public static func registerVisionTools(toolManager: ToolManager): Unit {
        toolManager.addTool(ImageUnderstandTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: ImageUnderstandTool")

        LogUtils.info("[BuiltinToolsRegistry] Vision tools registered")
    }

    public static func registerSkillTools(toolManager: ToolManager): Unit {
        toolManager.addTool(SkillInitializerTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: SkillInitializerTool")
        
        toolManager.addTool(SkillPackagerTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: SkillPackagerTool")

        toolManager.addTool(GetSkillContentTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: GetSkillContentTool")
        
        LogUtils.info("[BuiltinToolsRegistry] Skill lifecycle tools registered")
    }

    public static func registerCodeGenTools(toolManager: ToolManager): Unit {
        toolManager.addTool(TemplateEngineTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: TemplateEngineTool")
        
        toolManager.addTool(CodeSnippetGeneratorTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: CodeSnippetGeneratorTool")
        
        LogUtils.info("[BuiltinToolsRegistry] Code generation tools registered")
    }

    public static func registerCliTools(toolManager: ToolManager): Unit {
        toolManager.addTool(CliTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: CliTool")
        
        toolManager.addTool(PythonExecutorTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: PythonExecutorTool")
        
        toolManager.addTool(BrowserTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: BrowserTool")
        
        toolManager.addTool(HttpServerTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: HttpServerTool")
        
        toolManager.addTool(SubAgentTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: SubAgentTool")
        
        toolManager.addTool(EvalRunnerTool())
        LogUtils.info("[BuiltinToolsRegistry] Registered: EvalRunnerTool")
        
        LogUtils.info("[BuiltinToolsRegistry] CLI tools registered")
    }

    public static func getToolNames(): Array<String> {
        [
            HttpTool.NAME,
            FileReadTool.NAME,
            FileWriteTool.NAME,
            FileEditTool.NAME,
            FileDeleteTool.NAME,
            FileCopyTool.NAME,
            FileMoveTool.NAME,
            FileSearchTool.NAME,
            DirectoryListTool.NAME,
            DirectoryCreateTool.NAME,
            WebFetchTool.NAME,
            ImageUnderstandTool.NAME,

            SkillInitializerTool.NAME,
            SkillPackagerTool.NAME,
            GetSkillContentTool.NAME,
            TemplateEngineTool.NAME,
            CodeSnippetGeneratorTool.NAME,
            CliTool.NAME,
            PythonExecutorTool.NAME,
            BrowserTool.NAME,
            HttpServerTool.NAME,
            SubAgentTool.NAME,
            EvalRunnerTool.NAME
        ]
    }
}
