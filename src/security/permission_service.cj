/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.security

import magic.skill.domain.models.{Capability, SecurityPolicy, ResourceLimits}
import magic.log.LogUtils
import std.collection.ArrayList
import std.collection.HashMap
import std.core
import std.time.DateTime

func joinArrayList(list: ArrayList<String>, separator: String): String {
    if (list.isEmpty()) {
        return ""
    }
    let sb = StringBuilder()
    var first = true
    for (item in list) {
        if (first) {
            first = false
        } else {
            sb.append(separator)
        }
        sb.append(item)
    }
    return sb.toString()
}

public class PermissionCheckResult {
    private let _allowed: Bool
    private let _reason: Option<String>
    private let _deniedOperations: ArrayList<String>
    
    public init(
        allowed!: Bool,
        reason!: Option<String>,
        deniedOperations!: ArrayList<String>
    ) {
        _allowed = allowed
        _reason = reason
        _deniedOperations = deniedOperations
    }
    
    public prop allowed: Bool {
        get() { _allowed }
    }
    
    public prop reason: Option<String> {
        get() { _reason }
    }
    
    public prop deniedOperations: ArrayList<String> {
        get() { _deniedOperations }
    }
    
    public static func allow(): PermissionCheckResult {
        return PermissionCheckResult(
            allowed: true,
            reason: None,
            deniedOperations: ArrayList()
        )
    }
    
    public static func deny(reason: String): PermissionCheckResult {
        return PermissionCheckResult(
            allowed: false,
            reason: Some(reason),
            deniedOperations: ArrayList()
        )
    }
}

public class ResourceUsage {
    private var _memoryUsed: Int64
    private var _cpuTimeUsed: Int64
    private var _networkBytesUsed: Int64
    private var _fileOperationsCount: Int32
    
    public init() {
        _memoryUsed = 0
        _cpuTimeUsed = 0
        _networkBytesUsed = 0
        _fileOperationsCount = 0
    }
    
    public prop memoryUsed: Int64 {
        get() { _memoryUsed }
    }
    
    public prop cpuTimeUsed: Int64 {
        get() { _cpuTimeUsed }
    }
    
    public prop networkBytesUsed: Int64 {
        get() { _networkBytesUsed }
    }
    
    public prop fileOperationsCount: Int32 {
        get() { _fileOperationsCount }
    }
    
    public func reset(): Unit {
        _memoryUsed = 0
        _cpuTimeUsed = 0
        _networkBytesUsed = 0
        _fileOperationsCount = 0
    }
    
    public func setMemoryUsed(value: Int64): Unit {
        _memoryUsed = value
    }
    
    public func setCpuTimeUsed(value: Int64): Unit {
        _cpuTimeUsed = value
    }
    
    public func setNetworkBytesUsed(value: Int64): Unit {
        _networkBytesUsed = value
    }
    
    public func setFileOperationsCount(value: Int32): Unit {
        _fileOperationsCount = value
    }
}

public class PermissionService {
    private let _policy: SecurityPolicy
    private let _limits: ResourceLimits
    private let _usage: ResourceUsage
    private let _auditLog: ArrayList<String>
    
    public init(policy: SecurityPolicy, limits: ResourceLimits) {
        _policy = policy
        _limits = limits
        _usage = ResourceUsage()
        _auditLog = ArrayList()
    }
    
    public init(permissionService: PermissionService) {
        _policy = permissionService._policy
        _limits = permissionService._limits
        _usage = ResourceUsage()
        _auditLog = ArrayList()
    }
    
    public func getPolicy(): SecurityPolicy {
        return _policy
    }
    
    public func getLimits(): ResourceLimits {
        return _limits
    }
    
    public func getUsage(): ResourceUsage {
        return _usage
    }
    
    public func resetUsage(): Unit {
        _usage.reset()
    }
    
    public func checkFileSystemAccess(
        operation: String,
        path: String,
        requiredPermission: Option<String>
    ): PermissionCheckResult {
        if (!_policy.allowFileSystemAccess) {
            let reason = "File system access is disabled by security policy"
            LogUtils.info("[PermissionService] ${reason}: ${operation} on ${path}")
            _auditLog.add("DENY: fs:${operation} ${path} - policy disabled")
            return PermissionCheckResult.deny(reason)
        }
        
        LogUtils.info("[PermissionService] File system access allowed: ${operation} on ${path}")
        _auditLog.add("ALLOW: fs:${operation} ${path}")
        
        let newCount = _usage.fileOperationsCount + 1
        _usage.setFileOperationsCount(newCount)
        
        if (newCount > _limits.maxFileOperations) {
            let reason = "File operation limit exceeded: ${newCount.toString()}/${_limits.maxFileOperations.toString()}"
            LogUtils.error("[PermissionService] ${reason}")
            _auditLog.add("DENY: fs:${operation} ${path} - limit exceeded")
            return PermissionCheckResult.deny(reason)
        }
        
        return PermissionCheckResult.allow()
    }
    
    public func checkNetworkAccess(
        operation: String,
        host: Option<String>,
        port: Option<Int32>
    ): PermissionCheckResult {
        if (!_policy.allowNetworkAccess) {
            let target = if (let Some(h) <- host) {
                if (let Some(p) <- port) { "${h}:${p.toString()}" } else { h }
            } else { "unknown" }
            
            let reason = "Network access is disabled by security policy"
            LogUtils.info("[PermissionService] ${reason}: ${operation} to ${target}")
            _auditLog.add("DENY: net:${operation} ${target} - policy disabled")
            return PermissionCheckResult.deny(reason)
        }
        
        let target = if (let Some(h) <- host) {
            if (let Some(p) <- port) { "${h}:${p.toString()}" } else { h }
        } else { "unknown" }
        
        LogUtils.info("[PermissionService] Network access allowed: ${operation} to ${target}")
        _auditLog.add("ALLOW: net:${operation} ${target}")
        
        return PermissionCheckResult.allow()
    }
    
    public func recordNetworkUsage(bytes: Int64): PermissionCheckResult {
        let newBytes = _usage.networkBytesUsed + bytes
        _usage.setNetworkBytesUsed(newBytes)
        
        if (newBytes > _limits.maxNetworkBytes) {
            let reason = "Network bandwidth limit exceeded: ${newBytes.toString()}/${_limits.maxNetworkBytes.toString()} bytes"
            LogUtils.error("[PermissionService] ${reason}")
            _auditLog.add("DENY: net:bandwidth - limit exceeded")
            return PermissionCheckResult.deny(reason)
        }
        
        return PermissionCheckResult.allow()
    }
    
    public func checkCommandExecution(
        command: String,
        args: Option<ArrayList<String>>
    ): PermissionCheckResult {
        if (!_policy.allowCommandExecution) {
            let cmdStr = if (let Some(a) <- args) { "${command} ${joinArrayList(a, " ")}" } else { command }
            let reason = "Command execution is disabled by security policy"
            LogUtils.info("[PermissionService] ${reason}: ${cmdStr}")
            _auditLog.add("DENY: cmd:${command} - policy disabled")
            return PermissionCheckResult.deny(reason)
        }
        
        let cmdStr = if (let Some(a) <- args) { "${command} ${joinArrayList(a, " ")}" } else { command }
        LogUtils.info("[PermissionService] Command execution allowed: ${cmdStr}")
        _auditLog.add("ALLOW: cmd:${command}")
        
        return PermissionCheckResult.allow()
    }
    
    public func recordMemoryUsage(bytes: Int64): PermissionCheckResult {
        let newMemory = _usage.memoryUsed + bytes
        _usage.setMemoryUsed(newMemory)
        
        if (newMemory > _limits.maxMemory) {
            let reason = "Memory limit exceeded: ${newMemory.toString()}/${_limits.maxMemory.toString()} bytes"
            LogUtils.error("[PermissionService] ${reason}")
            _auditLog.add("DENY: memory - limit exceeded")
            return PermissionCheckResult.deny(reason)
        }
        
        return PermissionCheckResult.allow()
    }
    
    public func recordCpuTimeUsage(milliseconds: Int64): PermissionCheckResult {
        let newCpuTime = _usage.cpuTimeUsed + milliseconds
        _usage.setCpuTimeUsed(newCpuTime)
        
        if (newCpuTime > _limits.maxCpuTime) {
            let reason = "CPU time limit exceeded: ${newCpuTime.toString()}/${_limits.maxCpuTime.toString()} ms"
            LogUtils.error("[PermissionService] ${reason}")
            _auditLog.add("DENY: cpu - limit exceeded")
            return PermissionCheckResult.deny(reason)
        }
        
        return PermissionCheckResult.allow()
    }
    
    public func checkExecutionTimeout(startTimeMs: Int64): PermissionCheckResult {
        let currentTime = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        let elapsed = currentTime - startTimeMs
        
        if (elapsed > _policy.executionTimeoutMs) {
            let reason = "Execution timeout: ${elapsed.toString()}ms > ${_policy.executionTimeoutMs.toString()}ms"
            LogUtils.error("[PermissionService] ${reason}")
            _auditLog.add("DENY: timeout - ${reason}")
            return PermissionCheckResult.deny(reason)
        }
        
        return PermissionCheckResult.allow()
    }
    
    public func checkCapability(capability: Capability): PermissionCheckResult {
        let deniedOps = ArrayList<String>()
        
        match (capability.`type`) {
            case "filesystem" =>
                if (!_policy.allowFileSystemAccess) {
                    deniedOps.add("filesystem")
                }
            case "network" =>
                if (!_policy.allowNetworkAccess) {
                    deniedOps.add("network")
                }
            case "command" =>
                if (!_policy.allowCommandExecution) {
                    deniedOps.add("command")
                }
            case _ =>
                LogUtils.info("[PermissionService] Unknown capability type: ${capability.`type`}")
        }
        
        if (!deniedOps.isEmpty()) {
            let reason = "Capabilities denied: ${joinArrayList(deniedOps, ", ")}"
            return PermissionCheckResult(
                allowed: false,
                reason: Some(reason),
                deniedOperations: deniedOps
            )
        }
        
        return PermissionCheckResult.allow()
    }
    
    public func getAuditLog(): ArrayList<String> {
        return ArrayList(_auditLog)
    }
    
    public func clearAuditLog(): Unit {
        _auditLog.clear()
    }
    
    public func getSummary(): String {
        let sb = StringBuilder()
        sb.append("=== Permission Service Summary ===\n")
        sb.append("Policy: fs=${_policy.allowFileSystemAccess}, net=${_policy.allowNetworkAccess}, cmd=${_policy.allowCommandExecution}\n")
        sb.append("Usage: memory=${_usage.memoryUsed.toString()}, cpu=${_usage.cpuTimeUsed.toString()}ms, net=${_usage.networkBytesUsed.toString()}b, files=${_usage.fileOperationsCount.toString()}\n")
        sb.append("Audit log entries: ${_auditLog.size.toString()}")
        return sb.toString()
    }
}
