/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.security

import magic.log.LogUtils
import std.collection.ArrayList
import std.time.DateTime

public class SandboxExecutionResult {
    private let _success: Bool
    private let _output: Option<String>
    private let _error: Option<String>
    private let _exitCode: Option<Int32>
    private let _executionTimeMs: Int64
    
    public init(
        success!: Bool,
        output!: Option<String>,
        error!: Option<String>,
        exitCode!: Option<Int32>,
        executionTimeMs!: Int64
    ) {
        _success = success
        _output = output
        _error = error
        _exitCode = exitCode
        _executionTimeMs = executionTimeMs
    }
    
    public prop success: Bool {
        get() { _success }
    }
    
    public prop output: Option<String> {
        get() { _output }
    }
    
    public prop error: Option<String> {
        get() { _error }
    }
    
    public prop exitCode: Option<Int32> {
        get() { _exitCode }
    }
    
    public prop executionTimeMs: Int64 {
        get() { _executionTimeMs }
    }
    
    public static func successResult(output: String, executionTimeMs: Int64): SandboxExecutionResult {
        return SandboxExecutionResult(
            success: true,
            output: Some(output),
            error: None,
            exitCode: None,
            executionTimeMs: executionTimeMs
        )
    }
    
    public static func failureResult(error: String, executionTimeMs: Int64): SandboxExecutionResult {
        return SandboxExecutionResult(
            success: false,
            output: None,
            error: Some(error),
            exitCode: None,
            executionTimeMs: executionTimeMs
        )
    }
}

public class SandboxExecutor {
    private let _permissionService: PermissionService
    private let _sandboxId: String
    private var _isRunning: Bool
    
    public init(permissionService: PermissionService) {
        _permissionService = permissionService
        _sandboxId = "sandbox-" + DateTime.now().toString()
        _isRunning = false
    }
    
    public init(
        permissionService: PermissionService,
        sandboxId: String
    ) {
        _permissionService = permissionService
        _sandboxId = sandboxId
        _isRunning = false
    }
    
    public func getPermissionService(): PermissionService {
        return _permissionService
    }
    
    public func getSandboxId(): String {
        return _sandboxId
    }
    
    public func isRunning(): Bool {
        return _isRunning
    }
    
    public func executeInSandbox(
        action: () -> Unit,
        timeoutMs: Int64
    ): SandboxExecutionResult {
        let startTime = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        
        LogUtils.info("[SandboxExecutor] Starting execution in sandbox ${_sandboxId}")
        
        try {
            action()
            
            let endTime = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
            let executionTime = endTime - startTime
            
            LogUtils.info("[SandboxExecutor] Execution completed successfully in ${executionTime.toString()}ms")
            
            return SandboxExecutionResult.successResult("Execution completed successfully", executionTime)
        } catch (e: Exception) {
            let endTime = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
            let executionTime = endTime - startTime
            
            LogUtils.error("[SandboxExecutor] Execution failed: ${e.message}")
            
            return SandboxExecutionResult.failureResult(e.message, executionTime)
        }
    }
    
    public func executeWithTimeout(
        action: () -> Unit,
        timeoutMs: Int64
    ): SandboxExecutionResult {
        return executeInSandbox(action, timeoutMs)
    }
    
    public func getStatus(): String {
        return "Sandbox ${_sandboxId}: ${if (_isRunning) { "running" } else { "idle" }}"
    }
    
    public func reset(): Unit {
        _permissionService.resetUsage()
        LogUtils.info("[SandboxExecutor] Sandbox ${_sandboxId} reset")
    }
    
    public func cleanup(): Unit {
        reset()
        LogUtils.info("[SandboxExecutor] Sandbox ${_sandboxId} cleaned up")
    }
}

public class SandboxManager {
    private let _sandboxes: ArrayList<SandboxExecutor>
    private let _defaultPermissionService: PermissionService
    
    public init(defaultPermissionService: PermissionService) {
        _sandboxes = ArrayList()
        _defaultPermissionService = defaultPermissionService
    }
    
    public func createSandbox(): SandboxExecutor {
        let sandbox = SandboxExecutor(_defaultPermissionService)
        _sandboxes.add(sandbox)
        LogUtils.info("[SandboxManager] Created new sandbox: ${sandbox.getSandboxId()}")
        return sandbox
    }
    
    public func createSandbox(permissionService: PermissionService): SandboxExecutor {
        let sandbox = SandboxExecutor(permissionService)
        _sandboxes.add(sandbox)
        LogUtils.info("[SandboxManager] Created new sandbox with custom permissions: ${sandbox.getSandboxId()}")
        return sandbox
    }
    
    public func getSandbox(sandboxId: String): Option<SandboxExecutor> {
        for (sandbox in _sandboxes) {
            if (sandbox.getSandboxId() == sandboxId) {
                return Some(sandbox)
            }
        }
        return None
    }
    
    public func removeSandbox(sandboxId: String): Bool {
        var index = 0
        for (sandbox in _sandboxes) {
            if (sandbox.getSandboxId() == sandboxId) {
                sandbox.cleanup()
                _sandboxes.remove(at: index)
                LogUtils.info("[SandboxManager] Removed sandbox: ${sandboxId}")
                return true
            }
            index = index + 1
        }
        return false
    }
    
    public func getAllSandboxes(): ArrayList<SandboxExecutor> {
        return ArrayList(_sandboxes)
    }
    
    public func cleanupAll(): Unit {
        for (sandbox in _sandboxes) {
            sandbox.cleanup()
        }
        _sandboxes.clear()
        LogUtils.info("[SandboxManager] All sandboxes cleaned up")
    }
}
