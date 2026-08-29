package ystyle::cordis_host

import ystyle::cordis_core.{PluginEntry, InstanceStatus}
import ystyle::jsonrpc.JsonRpcClient
import std.process.SubProcess
import std.collection.{HashMap, ArrayList}
import std.sync.{Mutex, Condition}

/**
 * 插件运行时实例（docs/design-impl.md §2.2、docs/cordis-comparison.md §4 Fiber 状态机）
 *
 * 对齐 Cordis Fiber 的生命周期语义：
 * - status：InstanceState（Starting/Pending/Active/Unloading/Failed/Unreachable）
 * - settleLock/settleCond：状态转换同步原语（awaitActive 等状态变化）
 * - error：启动失败/崩溃原因（对齐 Cordis Fiber._error，await 重抛）
 */
public class PluginInstance {
    public var entry: PluginEntry
    public var process: SubProcess
    public var client: JsonRpcClient
    public var status: InstanceStatus
    public var provides: HashMap<String, String>   // serviceKey -> undo_id
    // 插件上报的依赖（initialize 握手时记录，依赖变更通知用）
    public var injects: ArrayList<String> = ArrayList()
    // 状态转换同步（Fiber 状态机：awaitActive 等待状态变化，对齐 Cordis Fiber）
    public let settleLock: Mutex = Mutex()
    public let settleCond: Condition
    // 终止互斥（PluginManager.terminate 幂等：防并发重复杀进程）
    public let terminateLock: Mutex = Mutex()
    // 启动失败/崩溃原因（对齐 Cordis Fiber._error，await() 重抛）
    public var error: ?String = None

    public init(entry: PluginEntry, process: SubProcess, client: JsonRpcClient) {
        this.entry = entry
        this.process = process
        this.client = client
        this.status = InstanceStatus.Starting
        this.provides = HashMap<String, String>()
        this.settleCond = synchronized(this.settleLock) {
            this.settleLock.condition()
        }
    }

    /**
     * 状态转换（低层原语）：更新状态并唤醒等待者（不通知宿主监听器）
     * 宿主侧请用 PluginHost.transitionStatus（会额外通知 statusListeners）。
     * @return 旧状态（供宿主判断是否真的变化）
     */
    public func transitionTo(newStatus: InstanceStatus): InstanceStatus {
        synchronized(this.settleLock) {
            let old = this.status
            if (old != newStatus) {
                this.status = newStatus
            }
            this.settleCond.notifyAll()
            old
        }
    }
}
