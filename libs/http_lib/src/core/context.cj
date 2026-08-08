package http_lib.core

import std.time.DateTime
import std.collection.{HashMap, ArrayList}

/**
 * 请求上下文 — 提供每个请求的取消、截止时间和键值存储。
 *
 * 支持：
 *   - 截止时间（自动过期检测）
 *   - 带原因的取消操作
 *   - 子上下文派生（继承截止时间）
 *   - 通过 onCancel 注册清理回调
 *   - 请求作用域的键值存储
 *
 * 使用示例：
 *   let ctx = RequestContext()
 *   ctx.setDeadline(DateTime.now() + Duration.second * 5)
 *   let childCtx = ctx.createChild()
 *   childCtx.onCancel({ => println("清理资源") })
 *   ...
 *   if (ctx.isExpired()) { return errorResponse }
 *   ctx.cancel("请求已中止")  // 同时取消所有子上下文
 */
public class RequestContext {
    private var deadline: ?DateTime = None
    private var cancelled: Bool = false
    private var cancelReason: String = ""
    private var values: HashMap<String, String> = HashMap<String, String>()
    private var children: ArrayList<RequestContext> = ArrayList<RequestContext>()
    private var cancelCallbacks: ArrayList<() -> Unit> = ArrayList<() -> Unit>()
    private var parent: ?RequestContext = None

    public init() {}

    /**
     * 创建子上下文，继承此上下文的截止时间，
     * 当父上下文被取消时子上下文也会自动取消。
     */
    public func createChild(): RequestContext {
        let child = RequestContext()
        child.parent = Some(this)
        match (deadline) {
            case Some(dl) => child.deadline = Some(dl)
            case None => ()
        }
        children.add(child)
        child
    }

    /**
     * 注册回调函数，在上下文被取消时执行。
     * 用于资源清理（关闭连接、移除定时器等）。
     */
    public func onCancel(callback: () -> Unit): Unit {
        cancelCallbacks.add(callback)
    }

    /**
     * 设置此上下文的截止时间。
     * 截止时间过后，isExpired() 返回 true。
     */
    public func setDeadline(dl: DateTime): Unit {
        deadline = Some(dl)
    }

    /**
     * 取消此上下文及所有子上下文，可附带可选原因。
     * 已注册的 onCancel 回调按注册顺序执行。
     */
    public func cancel(reason!: String = ""): Unit {
        if (cancelled) { return }
        cancelled = true
        cancelReason = reason

        // 执行清理回调
        for (cb in cancelCallbacks) {
            try { cb() } catch (_: Exception) {}
        }

        // 向子上下文传播取消
        for (child in children) {
            child.cancel(reason: reason)
        }
    }

    /**
     * 检查上下文是否已过期（截止时间已过或已取消）。
     */
    public func isExpired(): Bool {
        if (cancelled) { return true }
        match (deadline) {
            case Some(dl) => return DateTime.now() > dl
            case None =>
                // 检查父上下文的截止时间
                match (parent) {
                    case Some(p) => p.isExpired()
                    case None => false
                }
        }
    }

    /**
     * 获取取消原因。
     */
    public func getCancelReason(): String {
        cancelReason
    }

    /**
     * 检查上下文是否已被取消。
     */
    public func isCancelled(): Bool {
        cancelled || match (parent) { case Some(p) => p.isCancelled() case None => false }
    }

    /**
     * 获取截止时间（如已设置）。
     */
    public func getDeadline(): ?DateTime {
        deadline
    }

    /**
     * 在上下文中设置值。
     */
    public func setValue(key: String, value: String): Unit {
        values[key] = value
    }

    /**
     * 从上下文中获取值。若本地未找到则检查父上下文。
     */
    public func getValue(key: String): ?String {
        match (values.get(key)) {
            case Some(v) => Some(v)
            case None =>
                match (parent) {
                    case Some(p) => p.getValue(key)
                    case None => None
                }
        }
    }
}
