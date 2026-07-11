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

public class FailoverTransport <: TransportListener & Transport & Runnable {
    private static let logger = LoggerFactory.getLogger("FailoverTransport")

    //默认的第一次重连延迟为10ms
    private static let DEFAULT_INITIAL_RECONNECT_DELAY: Int64 = 10
    private static let MAX_POOL_SIZE: Int64 = 1
    private static let INFINITE: Int64 = -1
    private var disposedVal: Bool = false
    private let urls: LinkedList<String> = LinkedList<String>()
    private let updated: LinkedList<String> = LinkedList<String>()

    private var doRebalance: Bool = false
    private var doReconnectMark: Bool = false
    private var connectedToPriority: Bool = false
    private var rebalanceUpdateURLsVal: Bool = true
    private var connectedTransportURL: ?URL = None
    private var failedConnectTransportURL: ?URL = None
    private let disposedListener: TransportListener = DefaultTransportListener()

    private var transportListenerVal: ?TransportListener = None
    private var reconnectWorker: ThreadPool
    private var connectedTransport: ?Transport = None
    private var started: Bool = false

    private var priorityBackupVal: Bool = false
    private var priorityList: LinkedList<URL> = LinkedList<URL>()
    private var priorityBackupAvailable: Bool = false
    private var nestedExtraQueryOptionsVal: ?String = None

    private let reconnectMutex: Mutex = Mutex()
    private let backupMutex: Mutex = Mutex()
    private let sleepMutex: Mutex = Mutex()
    private let sleepCondition: Condition = synchronized(sleepMutex) {
        sleepMutex.condition()
    }
    private let requestMap: ConcurrentHashMap<Int32, Command> = ConcurrentHashMap<Int32, Command>()
    private let mutex: Mutex = Mutex()
    private let defaultMaxCacheSizeVal: Int64 = 128 * 1024
    private let stateTrackerVal: ConnectionStateTracker = ConnectionStateTracker(defaultMaxCacheSizeVal)

    private var backupVal: Bool = false
    private let backups: LinkedList<BackupTransport> = LinkedList<BackupTransport>()
    private var backupPoolSizeVal: Int64 = 1
    private var initialReconnectDelayVal: Duration = Duration.millisecond * DEFAULT_INITIAL_RECONNECT_DELAY
    private var maxReconnectDelayVal: Duration = Duration.millisecond * 30000
    private var timeoutVal: Duration = Duration.millisecond * -1
    private var useExponentialBackOffVal: Bool = true
    private var randomizeVal: Bool = true
    //最大重连次数，-1表示无限重试，0表示禁用重连，
    private var maxReconnectAttemptsVal: Int64 = INFINITE
    private var startupMaxReconnectAttemptsVal: Int64 = INFINITE
    //每重连该次数后打印警告日志
    private var warnAfterReconnectAttemptsVal: Int64 = 10
    private var connectFailuresVal: Int64 = 0
    private var reconnectDelayVal: Int64 = DEFAULT_INITIAL_RECONNECT_DELAY
    private var connectionFailure: ?Exception = None
    private var firstConnection: Bool = true
    private var trackMessagesVal: Bool = false
    private var updateURIsSupportedVal: Bool = true
    private var reconnectSupportedVal: Bool = true
    private var backOffMultiplier: Float64 = Float64(2)
    //文本文件的路径
    private var updateURIsURLVal: ?String = None

    private var shutdown: Bool = false

    public init() {
        stateTrackerVal.trackTransactions = true
        this.reconnectWorker = ThreadPoolFactory.createThreadPool(0, MAX_POOL_SIZE, Int64(Int16.Max), Duration.minute * 2
        )
    }

    public override func run(): Unit {
        if (!started) {
            return
        }

        var buildBackup = true
        if ((connectedTransport.isNone() || doRebalance || priorityBackupAvailable) && !disposed &&
                connectionFailure.isNone()) {
            doReconnect()
            buildBackup = false
        }
        if (buildBackup) {
            buildBackups()
            if (priorityBackup && !connectedToPriority) {
                doDelay()
                wakeup()
            }
        } else {
            //再次执行，以创建backup
            wakeup()
        }
    }

    private func processCommand(info: Command): Unit {
        if (let Some(response) <- (info as Response)) {
            requestMap.remove(response.correlationId)
        }

        if (let Some(conectionControl) <- (info as ConnectionControl)) {
            handleConnectionControl(conectionControl)
        }

        if (let Some(consumerControl) <- (info as ConsumerControl)) {
            if (consumerControl.close) {
                if (let Some(consumerId) <- consumerControl.consumerId) {
                    stateTrackerVal.processRemoveConsumer(consumerId, Int64(RemoveInfo.LAST_DELIVERED_UNKNOWN))
                }
            }
        }

        if (let Some(transportListener) <- this.transportListener) {
            transportListener.onCommand(info)
        }
    }

    private func handleTransportFailure(e: TransportException) {
        if (shutdown) {
            return
        }

        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "handleTransportFailure: ${e}")
        }

        synchronized(reconnectMutex) {
            if (let Some(transport) <- connectedTransport) {
                transport.stop()
            }
            connectedTransport = None
            connectedTransportURL = None
            connectedToPriority = false

            if (let Some(transportListener) <- this.transportListener) {
                if (!disposed && canReconnect()) {
                    transportListener.transportInterupted()
                    wakeup()
                } else {
                    if (let Some(transportException) <- (e as TransportException)) {
                        transportListener.onException(transportException)
                    } else {
                        transportListener.onException(TransportException(e.message, e))
                    }
                }
            }
        }
    }

    public func handleConnectionControl(command: ConnectionControl): Unit {
        if (let Some(reconnectTo) <- command.reconnectTo) {
            var reconnectUrl = reconnectTo.trimAscii()
            if (!reconnectUrl.isEmpty() && reconnectSupported) {
                reconnect(reconnectUrl)
            }
        }

        processNewBrokers(command.rebalanceConnection, command.connectedBrokers)
    }

    private func processNewBrokers(rebalance: Bool, newBrokers: ?String) {
        if (let Some(brokerUrls) <- newBrokers) {
            var urls = brokerUrls.trimAscii()
            if (!urls.isEmpty() && updateURIsSupported) {
                updateURLs(rebalance, urls.split(",", removeEmpty: true))
            }
        }
    }

    private func doReconnect(): Unit {
        var failure: ?Exception = None
        synchronized(reconnectMutex) {
            //从文件读取URL
            doUpdateURLsFromFile()
            var connectList: ?Collection<URL> = None
            if ((connectedTransport.isSome() && !doRebalance && !priorityBackupAvailable) || disposed ||
                    connectionFailure.isSome()) {
                return
            } else {
                var list = getConnectList()
                connectList = list
                if (list.isEmpty()) {
                    throw IOException("No uris available to connect to.")
                } else {
                    if (doRebalance) {
                        if (connectedToPriority || (!doReconnectMark && URLSupport.checkURLEquals(list.first,
                                        connectedTransportURL))) {
                            //负载均衡： 每次把URL洗牌，然后连接第一个，如果已经连接第一个，不再进行负载均衡
                            doRebalance = false
                            return
                        } else {
                            logger.debug("Doing rebalance from: ${connectedTransportURL} to ${list}")
                            try {
                                if (let Some(transport) <- this.connectedTransport) {
                                    this.connectedTransport = None
                                    disposeTransport(transport)
                                }
                            } catch (e: Exception) {
                                logger.debug("Caught an exception stopping existing transport for rebalance", e)
                            }
                            doReconnectMark = false
                        }
                        doRebalance = false
                    }

                    resetReconnectDelay()

                    var transport: ?Transport = None
                    var url: ?URL = None

                    synchronized(backupMutex) {
                        //备用转正
                        if ((priorityBackup || backup) && !backups.isEmpty()) {
                            var l = LinkedList<BackupTransport>(backups)
                            if (randomize) {
                                //开启随机，洗牌backup，使用第一个
                                l = Collections.shuffle<BackupTransport>(l)
                            }
                            if (let Some(backup) <- l.removeFirst()) {
                                backups.removeIf({e: BackupTransport => e == backup})
                                transport = backup.transport
                                url = backup.url

                                if (let Some(brokerInfo) <- backup.brokerInfo) {
                                    processCommand(brokerInfo)
                                }

                                if (priorityBackup && priorityBackupAvailable) {
                                    if (let Some(old) <- this.connectedTransport) {
                                        this.connectedTransport = None
                                        disposeTransport(old)
                                    }
                                    priorityBackupAvailable = false
                                }
                            }
                        }
                    }
                    if (transport.isNone() && !firstConnection && connectFailures == 0 && initialReconnectDelay > 0 &&
                        !disposed) {
                        doDelay()
                    }

                    while ((transport.isSome() || list.size > 0) && connectedTransport.isNone() && !disposed) {
                        try {
                            if (transport.isNone()) {
                                if (let Some(first) <- list.removeFirst()) {
                                    var connectUrl = URLSupport.addExtraQuery(first, nestedExtraQueryOptions)
                                    transport = TransportFactory.compositeConnect(connectUrl)
                                    url = connectUrl
                                }
                            }

                            if (let Some(transport) <- transport) {
                                transport.transportListener = this
                                transport.start()
                                if (started && !firstConnection) {
                                    restoreTransport(transport)
                                }
                            }

                            logger.log(LogLevel.DEBUG, "Connection established")

                            reconnectDelay = initialReconnectDelay
                            connectedTransportURL = url
                            connectedTransport = transport
                            if (let Some(url) <- url) {
                                connectedToPriority = isPriority(url)
                            }
                            connectFailuresVal = 0

                            if (let Some(transportListener) <- this.transportListener) {
                                transportListener.transportResumed()
                            }

                            if (firstConnection) {
                                firstConnection = false

                                logger.log(LogLevel.TRACE, "Successfully connected to ${url}")
                            } else {
                                logger.log(LogLevel.TRACE, "Successfully reconnected to ${url}")
                            }

                            return
                        } catch (e: Exception) {
                            failure = e
                            if (let Some(current) <- transport) {
                                current.stop()
                                transport = None
                            }
                        }
                    }

                    connectFailuresVal++

                    var maxReconnectLimit = calculateReconnectAttemptLimit()

                    if (maxReconnectLimit != INFINITE && connectFailures >= maxReconnectLimit) {
                        //超过最大连接次数
                        logger.error("Failed to connect after: ${connectFailures} attempt(s)")
                        connectionFailure = failure
                        if (let Some(transportListener) <- this.transportListener) {
                            if (let Some(connectionFailure) <- connectionFailure) {
                                transportListener.onException(TransportException(connectionFailure.message))
                            }
                        }
                    }

                    if (warnAfterReconnectAttempts > 0 && (connectFailures == 1 ||
                        (connectFailures % warnAfterReconnectAttempts) == 0)) {
                        logger.warn(
                            "Failed to connect after: ${connectFailures} attempt(s) with ${connectionFailure}, continuing to retry."
                        )
                    }
                }
            }
        }

        if (!disposed) {
            doDelay()
        }
    }

    private func disposeTransport(transport: Transport): Unit {
        transport.transportListener = disposedListener
        transport.stop()
    }

    private func doUpdateURLsFromFile(): Unit {
        var newUrls: ?String = None
        if (let Some(updateURIsURL) <- updateURIsURL) {
            try {
                newUrls = String.fromUtf8(File.readFrom(updateURIsURL))
            } catch (e: FSException | IllegalArgumentException) {
                logger.error("Failed to read updateURIsURL: ${updateURIsURL} ${e}")
            }
        }
        processNewTransports(rebalanceUpdateURIs, newUrls)
    }

    private func processNewTransports(rebalance: Bool, newTransports: ?String): Unit {
        if (let Some(newTransports) <- newTransports) {
            var urls = newTransports.trimAscii()
            if (urls.size > 0 && updateURIsSupported) {
                updateURLs(rebalance, urls.split(",", removeEmpty: true))
            }
        }
    }

    public override func updateURLs(rebalance: Bool, updatedURLs: Array<String>): Unit {
        if (updateURIsSupported) {
            let copy: HashSet<String> = HashSet<String>()
            synchronized(reconnectMutex) {
                copy.add(all: this.updated)
                this.updated.clear()
                for (updateURL in updatedURLs) {
                    if (!Collections.contains<String>(updated, updateURL)) {
                        updated.addLast(updateURL)
                    }
                    if (let Some(failedConnectTransportURL) <- failedConnectTransportURL) {
                        if (!URLSupport.checkURLEquals(failedConnectTransportURL, URL.parse(updateURL))) {
                            this.failedConnectTransportURL = None
                        }
                    }
                }
            }
            if (!(copy.isEmpty() && updated.isEmpty()) && copy != HashSet<String>(updated)) {
                buildBackups()
                reconnect(rebalance)
            }
        }
    }

    private func shouldBuildBackups(): Bool {
        return (backup && backups.size < backupPoolSize) || (priorityBackup &&
            !(priorityBackupAvailable || connectedToPriority))
    }

    private func buildBackups(): Unit {
        synchronized(backupMutex) {
            if (!disposed && shouldBuildBackups()) {
                var backupList = LinkedList<URL>(priorityList)
                var connectList = getConnectList()
                for (connectUrl in connectList) {
                    backupList.removeIf({e: URL => URLSupport.checkURLEquals(connectUrl, e)})
                    backupList.addLast(connectUrl)
                }

                backups.removeIf({e: BackupTransport => e.disposed})
                var iterator = backupList.iterator()
                while (!disposed && shouldBuildBackups()) {
                    if (let Some(backupUrl) <- iterator.next()) {
                        var url = URLSupport.addExtraQuery(backupUrl, nestedExtraQueryOptions)
                        if (connectedTransport.isSome() && !URLSupport.checkURLEquals(connectedTransportURL, Some(url))) {
                            var backupTransport = BackupTransport(this)
                            backupTransport.url = url
                            if (!Collections.contains<BackupTransport>(backups, backupTransport)) {
                                try {
                                    var t = TransportFactory.compositeConnect(url)
                                    t.transportListener = backupTransport
                                    t.start()
                                    backupTransport.transport = t
                                    if (priorityBackup && isPriority(url)) {
                                        priorityBackupAvailable = true
                                        backups.addFirst(backupTransport)
                                        // 移除优先级最低的一个
                                        if (backups.size > backupPoolSize) {
                                            var disposeTransport = backups.removeLast()
                                            if (let Some(disposeTransport) <- disposeTransport) {
                                                disposeTransport.disposed = true
                                                var transport = disposeTransport.transport
                                                if (let Some(transport) <- transport) {
                                                    transport.transportListener = disposedListener
                                                    transport.stop()
                                                }
                                            }
                                        }
                                    } else {
                                        backups.addLast(backupTransport)
                                    }
                                } catch (ex: Exception) {
                                    logger.error("Failed to build backup", ex)
                                }
                            }
                        }
                    } else {
                        break
                    }
                }
            }
        }
    }

    private func calculateReconnectAttemptLimit(): Int64 {
        var maxReconnectValue = this.maxReconnectAttempts
        if (firstConnection && this.startupMaxReconnectAttempts != INFINITE) {
            maxReconnectValue = this.startupMaxReconnectAttempts
        }
        return maxReconnectValue
    }

    public func add(rebalance: Bool, value: ?Array<String>): Unit {
        if (let Some(urlStrs) <- value) {
            var newURL: Bool = false
            synchronized(mutex) {
                for (url in urlStrs) {
                    if (!Collections.contains<String>(urls, url)) {
                        newURL = true
                    }
                    urls.addLast(url)
                }
            }
            if (newURL) {
                reconnect(rebalance)
            }
        }
    }

    public func remove(rebalance: Bool, value: Array<String>) {
        synchronized(mutex) {
            for (url in value) {
                urls.removeIf({e: String => e == url})
            }
        }
    }

    protected func reconnect(rebalance: Bool) {
        synchronized(reconnectMutex) {
            if (started) {
                if (rebalance) {
                    doRebalance = true
                }
                logger.debug("Waking up reconnect task")

                wakeup()
            } else {
                logger.debug(
                    "Reconnect was triggered but transport is not started yet. Wait for start to connect the transport."
                )
            }
        }
    }

    public func reconnect(url: String) {
        synchronized(mutex) {
            urls.clear()
        }
        doReconnectMark = true
        add(true, [url])
    }

    private func getConnectList(): LinkedList<URL> {
        let uniqueUrls: HashSet<String> = HashSet<String>(updated)
        uniqueUrls.add(all: urls)

        let uniqueArray = uniqueUrls.toArray()
        var list = LinkedList<URL>(uniqueUrls.size, {index: Int64 => URL.parse(uniqueArray[index])})

        var oldSize = list.size
        if (let Some(failedConnectTransportURL) <- failedConnectTransportURL) {
            list.removeIf({e: URL => URLSupport.checkURLEquals(e, failedConnectTransportURL)})
        }

        if (randomize) {
            list = Collections.shuffle<URL>(list)
        }

        if (list.size < oldSize) {
            if (let Some(failedConnectTransportURL) <- failedConnectTransportURL) {
                list.addLast(failedConnectTransportURL)
            }
        }
        return list
    }

    private func resetReconnectDelay(): Unit {
        if (!useExponentialBackOff || reconnectDelay == DEFAULT_INITIAL_RECONNECT_DELAY) {
            reconnectDelay = initialReconnectDelay
        }
    }

    private func doDelay(): Unit {
        if (reconnectDelay > 0) {
            synchronized(sleepMutex) {
                if (logger.isDebugEnabled()) {
                    logger.debug("Waiting ${reconnectDelay} ms before attempting connection")
                }
                sleepCondition.wait(timeout: Duration.millisecond * reconnectDelay)
            }
        }

        if (useExponentialBackOff) {
            // 指数增长
            reconnectDelay = Int64(Float64(reconnectDelay) * backOffMultiplier)
            if (reconnectDelay > maxReconnectDelay) {
                reconnectDelay = maxReconnectDelay
            }
        }
    }

    private func restoreTransport(t: Transport) {
        t.start()

        let control = ConnectionControl()
        control.faultTolerant = true
        t.oneway(control)
        stateTrackerVal.restore(t)
        var tmpMap: ConcurrentHashMap<Int32, Command> = ConcurrentHashMap<Int32, Command>(requestMap)

        for ((k, v) in tmpMap) {
            if (logger.isTraceEnabled()) {
                logger.trace("restore requestMap, replay: ${v}")
            }
            t.oneway(v)
        }
    }

    protected func isPriority(url: URL) {
        if (!priorityBackup) {
            return false
        }

        if (!priorityList.isEmpty()) {
            for (priorityURL in priorityList) {
                if (URLSupport.checkURLEquals(priorityURL, Some(url))) {
                    return true
                }
            }
        } else if (!urls.isEmpty()) {
            if (let Some(urlStr) <- urls.first) {
                return URLSupport.checkURLEquals(URL.parse(urlStr), url)
            }
        }

        return false
    }

    public prop faultTolerant: Bool {
        get() {
            return true
        }
    }

    public prop disposed: Bool {
        get() {
            return this.disposedVal
        }
    }

    private func wakeup(): Unit {
        reconnectWorker.addTask(this)
    }

    public override func oneway(command: Command): Unit {
        var startTime = DateTime.now()
        var timeoutMark = false
        while (connectedTransport.isNone() && !disposed && connectionFailure.isNone() && willReconnect()) {
            if (command is ShutdownInfo) {
                return
            } else if (command is RemoveInfo || command is MessageAck) {
                //模拟响应
                stateTrackerVal.track(command)
                if (command.responseRequired) {
                    var response = Response()
                    response.correlationId = command.commandId
                    processCommand(response)
                }
                return
            } else if (let Some(messagePull) <- (command as MessagePull)) {
                //模拟响应
                if (messagePull.timeout != 0) {
                    var dispatch = MessageDispatch()
                    dispatch.consumerId = messagePull.consumerId
                    dispatch.destination = messagePull.destination
                    processCommand(dispatch)
                }
                return
            } else if (command is Message && timeout > 0 && DateTime.now() - startTime > timeoutVal) {
                timeoutMark = true
                break
            }
            synchronized(sleepMutex) {
                sleepCondition.wait(timeout: Duration.millisecond * 100)
            }
        }

        var error: ?Exception = None
        synchronized(reconnectMutex) {
            if (let Some(tranport) <- connectedTransport) {
                var isTracked: Bool = false
                if (let Some(command) <- (command as Command)) {
                    if (let Some(response) <- stateTrackerVal.track(command)) {
                        if (let Some(trackedResponse) <- (response as Tracked)) {
                            isTracked = true
                            if (trackedResponse.isWaitingForResponse()) {
                                requestMap.add(command.commandId, trackedResponse)
                            }
                        }
                    } else if (!isTracked && command.responseRequired) {
                        requestMap.add(command.commandId, command)
                    }
                }

                try {
                    tranport.oneway(command)
                    if (command is ShutdownInfo) {
                        shutdown = true
                    }
                } catch (ex: TransportException) {
                    if (!canReconnect()) {
                        if (let Some(command) <- (command as Command)) {
                            if (command.responseRequired) {
                                requestMap.remove(command.commandId)
                            }
                        }
                    } else {
                        logger.log(LogLevel.DEBUG, "Send oneway failed for command: ${command as Command}")
                    }
                    handleTransportFailure(ex)
                }
            } else {
                if (disposed) {
                    error = TransportException("Transport disposed")
                } else if (connectionFailure.isSome()) {
                    error = connectionFailure
                } else if (timeoutMark == true) {
                    error = TransportException("Failover timeout of ${timeout}ms reached")
                } else if (!willReconnect()) {
                    error = TransportException("Reconnect attempts of ${maxReconnectAttempts} exceeded")
                } else {
                    error = TransportException("Unexpected failure")
                }
            }
        }
        if (!disposed) {
            if (let Some(error) <- error) {
                if (let Some(exception) <- (error as TransportException)) {
                    throw exception
                }
                throw TransportException(error.message, error)
            }
        }
    }

    private func canReconnect(): Bool {
        return started && 0 != calculateReconnectAttemptLimit()
    }

    private func willReconnect(): Bool {
        return firstConnection || 0 != calculateReconnectAttemptLimit()
    }

    public override func request(command: Command): ?Response {
        throw UnsupportedException()
    }

    public func asyncRequest(command: Command, responseCallback: ?(FutureResponse) -> Unit): FutureResponse {
        throw UnsupportedException()
    }

    public override func request(command: Command, timeout: Duration): ?Response {
        throw UnsupportedException()
    }

    public override func onCommand(command: Command) {
        processCommand(command)
    }

    public override func onException(ex: TransportException) {
        handleTransportFailure(ex)
    }

    public override func transportInterupted() {
    }

    public override func transportResumed() {
    }

    public func setPriorityURIs(priorityURIs: String) {
        var urls = priorityURIs.trimAscii()
        if (!urls.isEmpty()) {
            for (url in urls.split(",", removeEmpty: true)) {
                priorityList.addLast(URL.parse(url))
            }
        }
    }

    public override func narrow(target: TypeInfo): Any {
        if (ClassTypeInfo.of(this).isSubtypeOf(target)) {
            return this
        }
        return Option<Transport>.None
    }

    public func connectionInterruptProcessingComplete(connectionId: ConnectionId) {
        synchronized(reconnectMutex) {
            stateTrackerVal.connectionInterruptProcessingComplete(this, connectionId)
        }
    }

    public func start(): Unit {
        synchronized(reconnectMutex) {
            if (started) {
                return
            }
            stateTrackerVal.maxCacheSize = maxCacheSize
            stateTrackerVal.trackMessages = trackMessages
            started = true
            if (let Some(transport) <- connectedTransport) {
                stateTrackerVal.restore(transport)
            } else {
                reconnect(false)
            }
        }
    }

    public func stop(): Unit {
    }

    public func toString(): String {
        return "FailoverTransport"
    }

    public func getCurrentBackupSize(): Int64 {
        return this.backups.size
    }

    public prop connectFailures: Int64 {
        get() {
            return this.connectFailuresVal
        }
    }

    public prop stateTracker: ConnectionStateTracker {
        get() {
            return this.stateTrackerVal
        }
    }

    /**
     * 设置消息侦听
     */
    public mut prop transportListener: ?TransportListener {
        get() {
            return this.transportListenerVal
        }
        set(value) {
            this.transportListenerVal = value
        }
    }

    public mut prop backup: Bool {
        get() {
            return backupVal
        }
        set(value) {
            this.backupVal = value
        }
    }

    public mut prop backupPoolSize: Int64 {
        get() {
            return backupPoolSizeVal
        }
        set(value) {
            this.backupPoolSizeVal = value
        }
    }

    public mut prop priorityBackup: Bool {
        get() {
            return priorityBackupVal
        }
        set(value) {
            this.priorityBackupVal = value
        }
    }

    public mut prop initialReconnectDelay: Int64 {
        get() {
            return initialReconnectDelayVal.toMilliseconds()
        }
        set(value) {
            this.initialReconnectDelayVal = Duration.millisecond * value
        }
    }

    public mut prop maxReconnectDelay: Int64 {
        get() {
            return maxReconnectDelayVal.toMilliseconds()
        }
        set(value) {
            this.maxReconnectDelayVal = Duration.millisecond * value
        }
    }

    public mut prop timeout: Int64 {
        get() {
            return timeoutVal.toMilliseconds()
        }
        set(value) {
            this.timeoutVal = Duration.millisecond * value
        }
    }

    public mut prop useExponentialBackOff: Bool {
        get() {
            return useExponentialBackOffVal
        }
        set(value) {
            this.useExponentialBackOffVal = value
        }
    }

    public mut prop reconnectDelayExponent: Float64 {
        get() {
            return this.backOffMultiplier
        }
        set(value) {
            this.backOffMultiplier = value
        }
    }

    public mut prop randomize: Bool {
        get() {
            return randomizeVal
        }
        set(value) {
            this.randomizeVal = value
        }
    }

    public mut prop maxReconnectAttempts: Int64 {
        get() {
            return maxReconnectAttemptsVal
        }
        set(value) {
            this.maxReconnectAttemptsVal = value
        }
    }

    public mut prop startupMaxReconnectAttempts: Int64 {
        get() {
            return startupMaxReconnectAttemptsVal
        }
        set(value) {
            this.startupMaxReconnectAttemptsVal = value
        }
    }

    public mut prop warnAfterReconnectAttempts: Int64 {
        get() {
            return warnAfterReconnectAttemptsVal
        }
        set(value) {
            this.warnAfterReconnectAttemptsVal = value
        }
    }

    public mut prop trackMessages: Bool {
        get() {
            return trackMessagesVal
        }
        set(value) {
            this.trackMessagesVal = value
        }
    }

    public mut prop maxCacheSize: Int64 {
        get() {
            return stateTracker.maxCacheSize
        }
        set(value) {
            this.stateTracker.maxCacheSize = value
        }
    }

    public mut prop updateURIsSupported: Bool {
        get() {
            return updateURIsSupportedVal
        }
        set(value) {
            this.updateURIsSupportedVal = value
        }
    }

    public mut prop reconnectSupported: Bool {
        get() {
            return reconnectSupportedVal
        }
        set(value) {
            this.reconnectSupportedVal = value
        }
    }

    public mut prop updateURIsURL: ?String {
        get() {
            return updateURIsURLVal
        }
        set(value) {
            this.updateURIsURLVal = value
        }
    }

    public mut prop nestedExtraQueryOptions: ?String {
        get() {
            return nestedExtraQueryOptionsVal
        }
        set(value) {
            this.nestedExtraQueryOptionsVal = value
        }
    }

    public mut prop rebalanceUpdateURIs: Bool {
        get() {
            return this.rebalanceUpdateURLsVal
        }
        set(value) {
            this.rebalanceUpdateURLsVal = value
        }
    }

    public mut prop reconnectDelay: Int64 {
        get() {
            return this.reconnectDelayVal
        }
        set(value) {
            this.reconnectDelayVal = value
        }
    }
}
