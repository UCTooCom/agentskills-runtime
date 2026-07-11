/**
 * Copyright 2024 Beijing Baolande Software Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Runtime Library Exception to the Apache 2.0 License:
 *
 * As an exception, if you use this Software to compile your source code and
 * portions of this Software are embedded into the binary product as a result,
 * you may redistribute such product without providing attribution as would
 * otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.
 */
package activemq4cj.client.transport

public class InactivityMonitor <: TransportFilter {
    protected static let logger = LoggerFactory.getLogger("InactivityMonitor")

    private static let DEFAULT_CHECK_TIME_MILLS: Duration = Duration.millisecond * 30000

    private static var CHECKER_COUNTER: Int32 = 0
    private static var CONNECT_CHECK_TIMER: ?Timer = None
    private static var READ_CHECK_TIMER: ?Timer = None
    private static var WRITE_CHECK_TIMER: ?Timer = None

    private let monitorStarted: AtomicBool = AtomicBool(false)

    private let commandSent: AtomicBool = AtomicBool(false)
    private let inSend: AtomicBool = AtomicBool(false)
    private let failed: AtomicBool = AtomicBool(false)

    private let commandReceived: AtomicBool = AtomicBool(true)
    private let inReceive: AtomicBool = AtomicBool(false)

    private var localWireFormatInfo: ?WireFormatInfo = None
    private var remoteWireFormatInfo: ?WireFormatInfo = None

    private var ignoreRemoteWireFormat: Bool = false
    private var ignoreAllWireFormatInfo: Bool = false

    private var connectAttemptTimeoutVal: Duration = DEFAULT_CHECK_TIME_MILLS
    private var readCheckTimeVal: Duration = DEFAULT_CHECK_TIME_MILLS
    private var writeCheckTimeVal: Duration = DEFAULT_CHECK_TIME_MILLS
    private var initialDelayTimeVal: Duration = DEFAULT_CHECK_TIME_MILLS
    private var useKeepAliveVal: Bool = true
    private var keepAliveResponseRequiredVal: Bool = false
    private let lastReadCheckTime: ThreadLocal<DateTime> = ThreadLocal<DateTime>()
    private let lastWriteCheckTime: ThreadLocal<DateTime> = ThreadLocal<DateTime>()

    protected var wireFormat: ?WireFormat = None

    private let sendLock: ReentrantReadWriteMutex = ReentrantReadWriteMutex()

    private let monitor = Monitor()

    public InactivityMonitor(next: Transport, wireFormat: ?WireFormat) {
        super(next)
        this.wireFormat = wireFormat
        if (this.wireFormat.isNone()) {
            this.ignoreAllWireFormatInfo = true
        }
    }

    /**
     * 分别处理接收到的KeepAliveInfo和WireFormatInfo，除了KeepAliveInfo，其他命令继续传播
     */
    public override func onCommand(command: Command): Unit {
        commandReceived.store(true)
        inReceive.store(true)
        try {
            if (let Some(keepAliveInfo) <- (command as KeepAliveInfo)) {
                if (logger.isTraceEnabled()) {
                    logger.log(LogLevel.TRACE, "Receive message: ${keepAliveInfo}")
                }
                if (keepAliveInfo.responseRequired) {
                    sendLock.readMutex.lock()
                    try {
                        keepAliveInfo.responseRequired = false
                        oneway(keepAliveInfo)
                    } catch (e: TransportException) {
                        onException(e)
                    } finally {
                        sendLock.readMutex.unlock()
                    }
                }
            } else {
                if (let Some(wireFormatInfo) <- (command as WireFormatInfo)) {
                    synchronized(monitor) {
                        try {
                            processInboundWireFormatInfo(wireFormatInfo)
                        } catch (e: TransportException) {
                            onException(e)
                        }
                    }
                }
                if (let Some(listener) <- transportListener) {
                    listener.onCommand(command)
                }
            }
        } finally {
            inReceive.store(false)
        }
    }

    public override func oneway(command: Command): Unit {
        sendLock.readMutex.lock()
        inSend.store(true)
        try {
            if (failed.load()) {
                throw TransportException("Cannot send, the connection has already failed")
            }
            if (let Some(wireFormatInfo) <- (command as WireFormatInfo)) {
                synchronized(monitor) {
                    processOutboundWireFormatInfo(wireFormatInfo)
                }
            }
            next.oneway(command)
        } catch (ex: TransportException) {
            throw ex
        } finally {
            commandSent.store(true)
            inSend.store(false)
            sendLock.readMutex.unlock()
        }
    }

    public override func onException(error: TransportException): Unit {
        if (failed.compareAndSwap(false, true)) {
            stopMonitorThreads()
            if (let Some(listener) <- transportListener) {
                listener.onException(error)
            }
        }
    }

    public func start(): Unit {
        if (!isMonitorStarted()) {
            startConnectCheckTask(connectAttemptTimeout)
        }
        next.start()
        startMonitorThreads()
    }

    public override func stop(): Unit {
        stopMonitorThreads()
        next.stop()
    }

    private func readCheck(): Unit {
        //正在接收消息，跳过检查
        if (inReceive.load()) {
            logger.trace("A receive is in progress, skipping read check.")
            return
        }
        //接收不到消息，则抛异常，中断连接
        if (!commandReceived.load() && monitorStarted.load()) {
            logger.debug("No message received since last read check for InactivityMonitor.")

            spawn {
                onException(
                    TransportException("The connection was inactive for too (>${this.readCheckTimeVal}) long: "))
            }
        } else {
            //自上次readCheck之后又收到过消息
            if (logger.isTraceEnabled()) {
                logger.trace("Message received since last read check, resetting flag: InactivityMonitor")
            }
        }
        //每次readCheck之后将commandReceived设置为false，而onCommand每次侦听到消息后都会将commandReceived设置为true
        //当在readCheck时检查commandReceived为false，说明自上次readCheck后一直未收到消息
        commandReceived.store(false)
    }

    private func writeCheck(): Unit {
        //当前正在写消息，跳过
        if (inSend.load()) {
            logger.trace("Send in progress. Skipping write check.")
            return;
        }
        //自上次writeCheck后未发送过消息，发送一条keepAliveInfo，保持连接
        if (!commandSent.load() && useKeepAlive && monitorStarted.load()) {
            logger.trace("InactivityMonitor no message sent since last write check, sending a KeepAliveInfo")

            spawn {
                logger.debug("Running InactivityMonitor")
                if (monitorStarted.load()) {
                    try {
                        if (sendLock.writeMutex.tryLock()) {
                            let info: KeepAliveInfo = KeepAliveInfo()
                            info.responseRequired = this.keepAliveResponseRequired
                            oneway(info)
                        }
                    } catch (e: TransportException) {
                        onException(e)
                    } finally {
                        sendLock.writeMutex.unlock()
                    }
                }
            }
        } else {
            logger.trace("InactivityMonitor message sent since last write check, resetting flag.");
        }
        //每次oneWay发送消息后都会将commandSent设置为true，所以writeCheck后将commandSent设置为false，便于下一周期检查
        commandSent.store(false)
    }

    /**
     * 处理wireformatInfo出栈
     */
    private func processOutboundWireFormatInfo(info: WireFormatInfo): Unit {
        localWireFormatInfo = info
        startMonitorThreads()
    }

    /**
     * 处理wireformatInfo入栈
     */
    private func processInboundWireFormatInfo(info: WireFormatInfo): Unit {
        stopConnectCheckTask()
        var error: ?TransportException = None
        remoteWireFormatInfo = info
        try {
            startMonitorThreads()
        } catch (e: TransportException) {
            error = e
        }
        if (let Some(error) <- error) {
            onException(error)
        }
    }

    public func startConnectCheckTask(connectAttemptTimeout: Duration): Unit {
        //从start开始计时，如果在connectAttemptTimeout时间内无法建立连接的话，视为连接建立失败，抛出异常
        if (connectAttemptTimeout <= Duration.Zero) {
            return
        }
        logger.trace("Starting connection check task")
        synchronized(monitor) {
            let startTime = DateTime.now()
            if (CHECKER_COUNTER == 0 && CONNECT_CHECK_TIMER.isNone()) {
                CONNECT_CHECK_TIMER = Timer.once(
                    this.connectAttemptTimeout,
                    {
                        =>
                        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
                        if (DateTime.now() - startTime >= connectAttemptTimeout) {
                            spawn {
                                onException(
                                    TransportException(
                                        "The connection was inactive (no connection attempt made) for too (> ${this.connectAttemptTimeout}) long"
                                    ))
                            }
                        }
                    }
                )
            }
            CHECKER_COUNTER++
        }
    }

    /**
     * 停止connection check，调用相应timer的cancel方法，取消该任务调度
     */
    public func stopConnectCheckTask(): Unit {
        if (let Some(connectCheckTimer) <- CONNECT_CHECK_TIMER) {
            logger.trace("Stopping connection check task for: InactivityMonitor")
            synchronized(monitor) {
                connectCheckTimer.cancel()
                CONNECT_CHECK_TIMER = None
                CHECKER_COUNTER--
            }
        }
    }

    private func startMonitorThreads(): Unit {
        if (monitorStarted.load()) {
            return
        }

        if (!configuredOk()) {
            return
        }

        if (this.writeCheckTime > Duration.Zero || this.readCheckTime > Duration.Zero) {
            monitorStarted.store(true)
            synchronized(monitor) {
                CHECKER_COUNTER++
                if (readCheckTime > Duration.Zero) {
                    READ_CHECK_TIMER = Timer.repeat(
                        this.initialDelayTime,
                        this.readCheckTime,
                        {
                            =>
                            var lastRunTime: DateTime = DateTime.fromUnixTimeStamp(Duration.Zero)
                            if (let Some(lastReadCheckTime) <- lastReadCheckTime.get()) {
                                lastRunTime = lastReadCheckTime
                            }
                            let elapsed: Duration = DateTime.now() - lastRunTime
                            logger.debug("${elapsed.toMilliseconds()}ms elapsed since last read check.")
                            if (!allowReadCheck(elapsed)) {
                                logger.debug("Aborting read check...Not enough time elapsed since last read check.")
                                return
                            }

                            lastReadCheckTime.set(DateTime.now())
                            readCheck()
                        }
                    )
                }
                if (writeCheckTime > Duration.Zero) {
                    WRITE_CHECK_TIMER = Timer.repeat(
                        this.initialDelayTime,
                        this.writeCheckTime,
                        {
                            =>
                            var lastRunTime: Int64 = 0
                            var now: Int64 = DateTime.now().toUnixTimeStamp().toMilliseconds()
                            if (let Some(lastWriteCheckTime) <- lastWriteCheckTime.get()) {
                                lastRunTime = lastWriteCheckTime.toUnixTimeStamp().toMilliseconds()
                            }
                            if (lastRunTime != 0) {
                                logger.debug(
                                    "InactivityMonitor: ${now - lastRunTime}ms elapsed since last write check.")
                            }
                            lastWriteCheckTime.set(DateTime.now())
                            writeCheck()
                        }
                    )
                }
            }
        }
    }

    private func stopMonitorThreads(): Unit {
        stopConnectCheckTask()
        if (monitorStarted.compareAndSwap(true, false)) {
            CHECKER_COUNTER--
            if (CHECKER_COUNTER == 0) {
                if (let Some(readCheckTimer) <- READ_CHECK_TIMER) {
                    readCheckTimer.cancel()
                    READ_CHECK_TIMER = None
                }
                if (let Some(writeCheckTimer) <- WRITE_CHECK_TIMER) {
                    writeCheckTimer.cancel()
                    WRITE_CHECK_TIMER = None
                }
            }
        }
    }

    private func configuredOk(): Bool {
        var configured: Bool = false
        if (ignoreAllWireFormatInfo) {
            configured = true
        } else if (localWireFormatInfo.isSome() && remoteWireFormatInfo.isSome()) {
            if (!ignoreRemoteWireFormat) {
                if (logger.isDebugEnabled()) {
                    logger.debug("Using min of local: ${localWireFormatInfo} and remote: ${remoteWireFormatInfo}")
                }
                if (let Some(localWireFormatInfo) <- this.localWireFormatInfo) {
                    if (let Some(remoteWireFormatInfo) <- this.remoteWireFormatInfo) {
                        var readCheckTime: Int64 = min(localWireFormatInfo.getMaxInactivityDuration(),
                            remoteWireFormatInfo.getMaxInactivityDuration())
                        var writeCheckTime: Int64 = writeCheckValueFromReadCheck(readCheckTime)

                        this.readCheckTime = Duration.millisecond * readCheckTime
                        this.initialDelayTime = Duration.millisecond * min(
                            localWireFormatInfo.getMaxInactivityDurationInitalDelay(),
                            remoteWireFormatInfo.getMaxInactivityDurationInitalDelay()
                        )
                        this.writeCheckTime = Duration.millisecond * writeCheckTime
                    }
                }
            } else {
                if (logger.isDebugEnabled()) {
                    logger.debug("Using local: ${localWireFormatInfo}")
                }
                if (let Some(localWireFormatInfo) <- this.localWireFormatInfo) {
                    var readCheckTime: Int64 = localWireFormatInfo.getMaxInactivityDuration()
                    var writeCheckTime: Int64 = writeCheckValueFromReadCheck(readCheckTime)

                    this.readCheckTime = Duration.millisecond * readCheckTime
                    this.initialDelayTime = Duration.millisecond *
                        localWireFormatInfo.getMaxInactivityDurationInitalDelay()
                    this.writeCheckTime = Duration.millisecond * writeCheckTime
                }
            }
            configured = true
        }

        return configured
    }

    private func allowReadCheck(elapsed: Duration): Bool {
        return elapsed > (readCheckTime * 9 / 10)
    }

    private func writeCheckValueFromReadCheck(readCheckTime: Int64): Int64 {
        if (readCheckTime > 3) {
            return readCheckTime / 3
        } else {
            return readCheckTime
        }
    }

    public func isMonitorStarted(): Bool {
        return this.monitorStarted.load()
    }

    public mut prop connectAttemptTimeout: Duration {
        get() {
            return this.connectAttemptTimeoutVal
        }
        set(value) {
            this.connectAttemptTimeoutVal = value
        }
    }

    public mut prop readCheckTime: Duration {
        get() {
            return this.readCheckTimeVal
        }
        set(value) {
            this.readCheckTimeVal = value
        }
    }

    public mut prop writeCheckTime: Duration {
        get() {
            return this.writeCheckTimeVal
        }
        set(value) {
            this.writeCheckTimeVal = value
        }
    }

    public mut prop initialDelayTime: Duration {
        get() {
            return this.initialDelayTimeVal
        }
        set(value) {
            this.initialDelayTimeVal = value
        }
    }

    public mut prop useKeepAlive: Bool {
        get() {
            return this.useKeepAliveVal
        }
        set(value) {
            this.useKeepAliveVal = value
        }
    }

    public mut prop keepAliveResponseRequired: Bool {
        get() {
            return this.keepAliveResponseRequiredVal
        }
        set(value) {
            this.keepAliveResponseRequiredVal = value
        }
    }
}
