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
package activemq4cj.client

public class ActiveMQConnection <: TransportListener & IConnection {
    protected static let logger = LoggerFactory.getLogger("ActiveMQConnection")

    public static let DEFAULT_THREAD_POOL_SIZE: Int64 = 1000
    public static let DEFAULT_QUEUE_SIZE: Int64 = Int64(Int16.Max)
    private let executor: ThreadPool

    protected let activeTempDestinations: HashSet<ActiveMQTempDestination> = HashSet<ActiveMQTempDestination>()

    private var dispatchAsyncVal: Bool = true
    private var alwaysSessionAsyncVal: Bool = true
    private var advisoryConsumer: ?AdvisoryConsumer = None

    private var disableTimeStampsByDefaultVal: Bool = false
    private var optimizedMessageDispatchVal: Bool = true
    private var copyMessageOnSendVal: Bool = true
    private var useCompressionVal: Bool = false
    private var objectMessageSerializationDeferedVal: Bool = false
    private var useAsyncSendVal: Bool = false
    private var optimizeAcknowledgeVal: Bool = false
    private var optimizeAcknowledgeTimeOutVal: Int64 = 0
    private var optimizedAckScheduledAckIntervalVal: Int64 = 0
    private var nestedMapAndListEnabledVal: Bool = true
    private var useRetroactiveConsumerVal: Bool = false
    private var exclusiveConsumerVal: Bool = false
    private var alwaysSyncSendVal: Bool = false
    private var closeTimeoutVal: Int32 = 15000
    private var watchTopicAdvisoriesVal: Bool = true
    private var warnAboutUnstartedConnectionTimeoutVal: Int64 = 500
    private var sendTimeoutVal: Int32 = 0
    private var sendAcksAsyncVal: Bool = true
    private var checkForDuplicatesVal: Bool = true
    private var queueOnlyConnectionVal: Bool = false
    private var consumerExpiryCheckEnabledVal: Bool = true

    /**
     * clientId生成，保证唯一
     */
    private let clientIdGenerator: IdGenerator
    private let consumerIdGenerator = Int64SequenceGenerator()
    private let sessionIdGenerator: Int64SequenceGenerator = Int64SequenceGenerator()
    private let localTransactionIdGeneratorVal: Int64SequenceGenerator = Int64SequenceGenerator()
    private let tempDestinationIdGenerator: Int64SequenceGenerator = Int64SequenceGenerator()

    //状态
    private var isConnectionInfoSentToBroker: Bool = false
    private var clientIDSet: Bool = false
    private let started: AtomicBool = AtomicBool(false)
    private let closed: AtomicBool = AtomicBool(false)
    private let closing: AtomicBool = AtomicBool(false)
    private let transportFailed: AtomicBool = AtomicBool(false)

    private let info: ConnectionInfo
    private var brokerInfoVal: ?BrokerInfo = None
    private let brokerInfoReceived: SyncCounter = SyncCounter(1)
    private var producerWindowSizeVal: Int32 = ActiveMQConnectionFactory.DEFAULT_PRODUCER_WINDOW_SIZE
    private var exceptionListenerVal: ?ExceptionListener = None
    private var firstFailureExceptionVal: ?TransportException = None
    private var clientInternalExceptionListenerVal: ?ClientInternalExceptionListener = None

    private var protocolVersionVal: Int32 = Int32(CommandTypes.PROTOCOL_VERSION)
    private var consumerFailoverRedeliveryWaitPeriodVal: Duration = Duration.Zero
    private var messagePrioritySupportedVal: Bool = false
    private var transactedIndividualAckVal: Bool = false
    private var nonBlockingRedeliveryVal: Bool = false
    private var rmIdFromConnectionIdVal: Bool = false
    private let connectionAudit: ConnectionAudit = ConnectionAudit()

    private var transport: Transport

    private var connectResponseTimeoutVal: Int32 = 0

    private var prefetchPolicyVal: ActiveMQPrefetchPolicy = ActiveMQPrefetchPolicy()
    private var redeliveryPolicyMapVal: ?RedeliveryPolicyMap = None
    private var transformerVal: ?MessageTransformer = None

    private let sessionsMutex: ReentrantMutex = ReentrantMutex()
    protected let sessions: LinkedList<ActiveMQSession> = LinkedList<ActiveMQSession>()
    private let transportListeners: LinkedList<TransportListener> = LinkedList<TransportListener>()
    /**
     * 创建consumer时注册进来，当客户端收到MessageDispatch命令时会根据命令的consumerId字段派发给对应的消费者
     */
    private let dispatchers: ConcurrentHashMap<ConsumerId, ActiveMQDispatcher> = ConcurrentHashMap<ConsumerId, ActiveMQDispatcher>(
    )
    private let producers: ConcurrentHashMap<ProducerId, ActiveMQMessageProducer> = ConcurrentHashMap<ProducerId, ActiveMQMessageProducer>(
    )

    private let monitor = Mutex()
    private let sessionMutex = Mutex()
    private let transportListenersMutex = Mutex()
    //是否手动设置过clientID，持久订阅时需要
    private var userSpecifiedClientID: Bool = false
    private let transportInteruptedProcess: AtomicInt64 = AtomicInt64(0)

    public init(transport: Transport, clientIdGenerator: IdGenerator, connectionIdGenerator: IdGenerator) {
        this.executor = ThreadPoolFactory.createThreadPool(0, DEFAULT_THREAD_POOL_SIZE, DEFAULT_QUEUE_SIZE,
            Duration.second * 5)
        this.clientIdGenerator = clientIdGenerator

        this.info = ConnectionInfo()
        info.connectionId = ConnectionId(connectionIdGenerator.generateId())
        info.manageable = true
        info.faultTolerant = transport.faultTolerant

        this.transport = transport
        this.transport.transportListener = this
        this.connectionAudit.checkForDuplicates = transport.faultTolerant
    }

    public func start(): Unit {
        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "Connection start")
        }
        //发送ConnectionInfo命令
        ensureConnectionInfoSent()
        if (started.compareAndSwap(false, true)) {
            synchronized(sessionMutex) {
                for (session in sessions) {
                    session.start()
                }
            }
        }
    }

    public func stop(): Unit {
        doStop(true)
    }

    protected func ensureConnectionInfoSent(): Unit {
        synchronized(monitor) {
            if (isConnectionInfoSentToBroker || closed.load()) {
                return
            }
            //设置ClientID
            if (this.connectionInfo.clientId.isNone()) {
                this.connectionInfo.clientId = clientIdGenerator.generateId()
            }
            //发送ConnectionInfo命令
            this.syncSendPacket(this.connectionInfo, Duration.millisecond * Int64(this.connectResponseTimeout))
            this.isConnectionInfoSentToBroker = true

            if (let Some(connectionId) <- info.connectionId) {
                var consumerId: ConsumerId = ConsumerId(SessionId(connectionId.value, -1),
                    consumerIdGenerator.getNextSequenceId())
                if (watchTopicAdvisories) {
                    advisoryConsumer = AdvisoryConsumer(this, consumerId)
                }
            }
        }
    }

    protected func checkClosedOrFailed(): Unit {
        checkClosed()
        if (transportFailed.load()) {
            if (let Some(firstFailureException) <- firstFailureExceptionVal) {
                throw ConnectionFailedException(firstFailureException)
            }
            throw ConnectionFailedException()
        }
    }

    private func checkClosed() {
        if (closed.load()) {
            throw CJMSIllegalStateException("The connection is already closed", "AlreadyClosed")
        }
    }

    public prop connectionInfo: ConnectionInfo {
        get() {
            return this.info
        }
    }

    public override func createSession(): Session {
        return createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)
    }

    public override func createSession(acknowledgeMode: AcknowledgeMode): Session {
        return createSession(acknowledgeMode == AcknowledgeMode.SESSION_TRANSACTED, acknowledgeMode)
    }

    public override func createSession(transacted: Bool, acknowledgeMode: AcknowledgeMode): Session {
        checkClosed()
        ensureConnectionInfoSent()
        var ackMode = acknowledgeMode
        if (!transacted) {
            if (ackMode == AcknowledgeMode.SESSION_TRANSACTED) {
                throw CJMSException("AcknowledgeMode SESSION_TRANSACTED cannot be used for an non-transacted Session")
            }
        } else {
            ackMode = AcknowledgeMode.SESSION_TRANSACTED
        }
        return ActiveMQSession(this, sessionIdGenerator.getNextSequenceId(), ackMode, dispatchAsync, alwaysSessionAsync)
    }

    public func asyncSendPacket(command: Command): Unit {
        checkClosed()
        this.transport.oneway(command)
    }

    public func syncSendPacket(command: Command, onComplete: AsyncCallback): Unit {
        checkClosedOrFailed()
        try {
            this
                .transport
                .asyncRequest(
                    command,
                    {
                        resp: FutureResponse =>
                        let response = resp.getResult()

                        if (let Some(exceptionResponse) <- (response as ExceptionResponse)) {
                            if (let Some(exception) <- exceptionResponse.exception) {
                                var error = CJMSExceptionSupport.create(exception)
                                onComplete.onException(error)
                            }
                        } else {
                            onComplete.onSuccess()
                        }
                    }
                )
        } catch (ex: TransportException) {
            throw CJMSExceptionSupport.create(ex)
        }
    }

    public func syncSendPacket(command: Command, timeout: Duration): Response {
        checkClosedOrFailed()
        let response: ?Response

        if (timeout > Duration.Zero) {
            response = this.transport.request(command, timeout)
        } else {
            response = this.transport.request(command)
        }

        if (let Some(response) <- response) {
            if (let Some(exceptionResponse) <- (response as ExceptionResponse)) {
                if (let Some(exception) <- exceptionResponse.exception) {
                    throw CJMSExceptionSupport.create(exception)
                }
            }
            return response
        }
        throw ActiveMQException("Cannot receive response, command: ${command}}")
    }

    public func syncSendPacket(command: Command): Response {
        return syncSendPacket(command, Duration.Zero)
    }

    public func addTransportListener(transportListener: TransportListener) {
        synchronized(transportListenersMutex) {
            transportListeners.addLast(transportListener)
        }
    }

    public func removeTransportListener(transportListener: TransportListener) {
        synchronized(transportListenersMutex) {
            transportListeners.removeIf({e: TransportListener => refEq(e, transportListener)})
        }
    }

    public func setUserName(userName: ?String) {
        this.connectionInfo.userName = userName
    }

    public func setPassword(password: ?String) {
        this.connectionInfo.password = password
    }

    public func getClientID(): ?String {
        checkClosedOrFailed()
        return this.connectionInfo.clientId
    }

    public func setClientID(clientId: String) {
        checkClosedOrFailed()

        if (this.clientIDSet) {
            throw IllegalStateException("The clientID has already been set")
        }

        if (this.isConnectionInfoSentToBroker) {
            throw IllegalStateException("Setting clientID on a used Connection is not allowed")
        }

        this.connectionInfo.clientId = clientId
        this.userSpecifiedClientID = true
        ensureConnectionInfoSent()
    }

    public func setDefaultClientID(clientID: String) {
        this.connectionInfo.clientId = clientID
        this.userSpecifiedClientID = true
    }

    public func isUserSpecifiedClientID(): Bool {
        return this.userSpecifiedClientID
    }

    public func checkClientIDWasManuallySpecified(): Unit {
        if (!userSpecifiedClientID) {
            throw CJMSException(
                "You cannot create a durable subscriber without specifying a unique clientID on a Connection")
        }
    }

    public func getMetaData(): ConnectionMetaData {
        checkClosedOrFailed()
        return ActiveMQConnectionMetaData.INSTANCE
    }

    protected func addSession(session: ActiveMQSession): Unit {
        synchronized(sessionMutex) {
            this.sessions.addLast(session)
            if (sessions.size > 1 || session.isTransacted()) {
                optimizedMessageDispatch = false
            }
        }
    }

    protected func removeSession(session: ActiveMQSession) {
        connectionAudit.removeDispatcher(session)
        synchronized(sessionMutex) {
            this.sessions.removeIf({e => refEq(e, session)})
        }
    }

    protected func addProducer(producerId: ProducerId, producer: ActiveMQMessageProducer): Unit {
        producers.put(producerId, producer)
    }

    protected func removeProducer(producerId: ProducerId): Unit {
        producers.remove(producerId)
    }

    protected func addDispatcher(consumerId: ConsumerId, dispatcher: ActiveMQDispatcher) {
        dispatchers.put(consumerId, dispatcher)
    }

    protected func removeDispatcher(consumerId: ConsumerId): Unit {
        dispatchers.remove(consumerId)
    }

    protected func removeDispatcher(dispatcher: ActiveMQDispatcher) {
        connectionAudit.removeDispatcher(dispatcher)
    }

    protected func hasDispatcher(consumerId: ConsumerId): Bool {
        return dispatchers.contains(consumerId)
    }

    public prop brokerName: ?String {
        get() {
            brokerInfoReceived.waitUntilZero(timeout: Duration.second * 5)
            if (let Some(brokerInfo) <- this.brokerInfoVal) {
                return brokerInfo.brokerName
            }
            return None
        }
    }

    public prop brokerInfo: ?BrokerInfo {
        get() {
            return brokerInfoVal
        }
    }

    public prop protocolVersion: Int32 {
        get() {
            return this.protocolVersionVal
        }
    }

    public func onCommand(command: Command): Unit {
        if (!closed.load()) {
            command.visit(this)
        }

        synchronized(transportListenersMutex) {
            for (transportListener in transportListeners) {
                transportListener.onCommand(command)
            }
        }
    }

    public override func processMessageDispatch(dispatch: MessageDispatch): ?Response {
        waitForTransportInterruptionProcessingToComplete()
        if (let Some(consumerId) <- dispatch.consumerId) {
            if (let Some(dispatcher) <- dispatchers.get(consumerId)) {
                var msg = dispatch.message
                if (let Some(msg) <- msg) {
                    var message = msg.copy()
                    message.readOnlyBody = true
                    message.readOnlyProperties = true
                    message.redeliveryCounter = dispatch.redeliveryCounter
                    message.connection = this
                    dispatch.message = message
                }
                dispatcher.dispatch(dispatch)
            }
        }
        return None
    }

    public override func processWireFormat(info: WireFormatInfo): ?Response {
        this.protocolVersionVal = info.version
        return None
    }

    public override func processBrokerInfo(info: BrokerInfo): ?Response {
        this.brokerInfoVal = info
        brokerInfoReceived.dec()
        return None
    }

    public override func processConnectionControl(info: ConnectionControl): ?Response {
        if (info.faultTolerant) {
            this.optimizeAcknowledge = false
            synchronized(sessionMutex) {
                for (session in sessions) {
                    session.setOptimizeAcknowledge(false)
                }
            }
        }
        return None
    }

    public override func processConnectionError(error: ConnectionError): ?Response {
        if (let Some(exception) <- error.exception) {
            onAsyncException(CJMSExceptionSupport.create(exception))
        }
        return None
    }

    public override func processProducerAck(ack: ProducerAck): ?Response {
        if (let Some(producerId) <- ack.producerId) {
            if (let Some(producer) <- producers.get(producerId)) {
                producer.onProducerAck(ack)
            }
        }
        return None
    }

    public func onClientInternalException(error: Exception) {
        if (!closed.load() && !closing.load()) {
            if (let Some(clientInternalExceptionListener) <- clientInternalExceptionListener) {
                executor.addTask(clientInternalExceptionPropagate(clientInternalExceptionListener, error))
            } else {
                logger.debug("Async client internal exception occurred with no exception listener registered: ${error}",
                    error)
            }
        }
    }

    public func onAsyncException(ex: Exception): Unit {
        if (!closed.load() && !closing.load()) {
            if (let Some(exceptionListener) <- this.exceptionListener) {
                let error: CJMSException
                if (let Some(e) <- (ex as CJMSException)) {
                    error = e
                } else {
                    error = CJMSExceptionSupport.create(ex)
                }
                //异步处理，防止主线程阻塞
                executor.addTask(AsyncExceptionTransmission(exceptionListener, error))
            } else {
                logger.log(LogLevel.DEBUG, "Async exception with no exception listener: ${ex}", ex)
            }
        }
    }

    public override func onException(error: TransportException): Unit {
        onAsyncException(error)

        if (!closed.load() && !closing.load()) {
            let exceptionDisposeFunc = {
                =>
                transportFailure(error)
                this.transport.stop()
                brokerInfoReceived.dec()

                try {
                    doCleanup(true)
                } catch (ex: CJMSException) {
                    logger.warn("Exception during connection cleanup, ${ex}", ex)
                }

                for (listener in transportListeners) {
                    listener.onException(error)
                }
            }

            executor.addTask(ExceptionDispose(exceptionDisposeFunc))
        }
    }

    /**
     * 将Connection重置到刚建立时的状态，这样就可以不用再创建一个新连接
     */
    public func cleanUp(): Unit {
        doCleanup(false)
    }

    private func doCleanup(removeConnection: Bool): Unit {
        synchronized(sessionMutex) {
            if (!transportFailed.load()) {
                if (let Some(advisoryConsumer) <- advisoryConsumer) {
                    advisoryConsumer.dispose()
                    this.advisoryConsumer = None
                }
            }

            // 拷贝出来操作，避免出现并发修改异常
            let tempSessions = LinkedList<ActiveMQSession>(sessions)
            for (s in tempSessions) {
                s.dispose()
            }
        }

        if (removeConnection) {
            if (isConnectionInfoSentToBroker) {
                if (!transportFailed.load() && !closing.load()) {
                    syncSendPacket(info.createRemoveInfo())
                }
                isConnectionInfoSentToBroker = false
            }
            if (userSpecifiedClientID) {
                info.clientId = None
                userSpecifiedClientID = false
            }
            clientIDSet = false
        }

        started.store(false)
    }

    private func transportFailure(error: TransportException) {
        transportFailed.store(true)
        if (firstFailureException.isNone()) {
            firstFailureExceptionVal = error
        }
    }

    protected func createTempDestination(topic: Bool): ActiveMQTempDestination {
        let dest: ActiveMQTempDestination

        var connectionIdVal: String
        if (let Some(connectionId) <- connectionInfo.connectionId) {
            if (let Some(value) <- connectionId.value) {
                connectionIdVal = value
            } else {
                throw ActiveMQException("Connection not available")
            }
        } else {
            throw ActiveMQException("Connection not available")
        }

        if (topic) {
            dest = ActiveMQTempTopic(connectionIdVal, tempDestinationIdGenerator.getNextSequenceId())
        } else {
            dest = ActiveMQTempQueue(connectionIdVal, tempDestinationIdGenerator.getNextSequenceId())
        }

        let info = DestinationInfo()
        info.connectionId = connectionInfo.connectionId
        info.operationType = DestinationInfo.ADD_OPERATION_TYPE
        info.destination = dest
        syncSendPacket(info)

        dest.connection = this
        activeTempDestinations.add(dest)
        return dest
    }

    public override func deleteDestination(destination: Destination): Unit {
        if (let Some(destination) <- (destination as ActiveMQTempDestination)) {
            deleteTempDestination(destination)
        }
    }

    public func deleteTempDestination(destination: ActiveMQTempDestination): Unit {
        checkClosedOrFailed()

        for (session in this.sessions) {
            if (session.isInUse(destination)) {
                throw CJMSException("A consumer is consuming from the temporary destination")
            }
        }

        activeTempDestinations.remove(destination)
        let destInfo = DestinationInfo()
        destInfo.connectionId = this.connectionInfo.connectionId
        destInfo.operationType = DestinationInfo.REMOVE_OPERATION_TYPE
        destInfo.destination = destination
        destInfo.timeout = 0
        syncSendPacket(destInfo)
    }

    public func isDeleted(dest: ActiveMQDestination): Bool {
        if (advisoryConsumer.isNone()) {
            return false
        }

        if (let Some(tempDestination) <- (dest as ActiveMQTempDestination)) {
            return !activeTempDestinations.contains(tempDestination)
        }
        return false
    }

    public func unsubscribe(name: String): Unit {
        checkClosedOrFailed()
        let info = RemoveSubscriptionInfo()
        info.connectionId = this.connectionInfo.connectionId
        info.clientId = this.connectionInfo.clientId
        info.subscriptionName = name
        syncSendPacket(info)
    }

    protected func isDuplicate(dispatcher: ActiveMQDispatcher, message: ?Message): Bool {
        return checkForDuplicates && connectionAudit.isDuplicate(dispatcher, message)
    }

    protected func rollbackDuplicate(dispatcher: ActiveMQDispatcher, message: Message) {
        connectionAudit.rollbackDuplicate(dispatcher, message)
    }

    public override func isUseCompression(): Bool {
        return this.useCompression
    }

    public func isStarted(): Bool {
        return started.load()
    }

    public func isClosing(): Bool {
        return this.closing.load()
    }

    public override func isClosed(): Bool {
        return this.closed.load()
    }

    public override func close(): Unit {
        if (!closed.load() && !transportFailed.load()) {
            doStop(false)
        }
        synchronized(sessionMutex) {
            if (!closed.load()) {
                try {
                    closing.store(true)

                    if (let Some(advisoryConsumer) <- advisoryConsumer) {
                        advisoryConsumer.dispose()
                        this.advisoryConsumer = None
                    }

                    var lastDeliveredSequenceId: Int64 = -1

                    var tempSessions = LinkedList<ActiveMQSession>(sessions)
                    for (session in tempSessions) {
                        session.dispose()
                        lastDeliveredSequenceId = max(lastDeliveredSequenceId, session.lastDeliveredSequenceId)
                    }

                    this.activeTempDestinations.clear()
                    if (isConnectionInfoSentToBroker) {
                        var removeCommand = this.connectionInfo.createRemoveInfo()
                        removeCommand.lastDeliveredSequenceId = lastDeliveredSequenceId
                        syncSendPacket(removeCommand, Duration.millisecond * Int64(closeTimeout))
                        if (!transportFailed.load()) {
                            asyncSendPacket(ShutdownInfo())
                        }
                    }
                } finally {
                    closed.store(true)
                    closing.store(false)
                    started.store(false)
                    this.transport.stop()
                }
            }
        }
    }

    func doStop(checkClosed: Bool): Unit {
        if (checkClosed) {
            checkClosedOrFailed()
        }
        if (started.compareAndSwap(true, false)) {
            synchronized(sessionsMutex) {
                for (session in sessions) {
                    session.stop()
                }
            }
        }
    }

    public override func transportInterupted(): Unit {
        transportInteruptedProcess.store(1)
        synchronized(sessionMutex) {
            for (session in sessions) {
                session.clearMessagesWhenInterupted(transportInteruptedProcess)
            }
        }

        if (transportInteruptedProcess.fetchSub(1) > 1) {
            signalInterruptionProcessingNeeded()
        }

        synchronized(transportListenersMutex) {
            for (transportListener in transportListeners) {
                transportListener.transportInterupted()
            }
        }
    }

    public override func transportResumed(): Unit {
        synchronized(transportListenersMutex) {
            for (transportListener in transportListeners) {
                transportListener.transportResumed()
            }
        }
    }

    protected func waitForTransportInterruptionProcessingToComplete(): Unit {
        if (!closed.load() && !transportFailed.load() && transportInteruptedProcess.load() > 0) {
            logger.warn(
                "dispatch with outstanding dispatch interruption processing count ${transportInteruptedProcess.load()}")
            signalInterruptionProcessingComplete()
        }
    }

    protected func transportInterruptionProcessingComplete(): Unit {
        if (transportInteruptedProcess.fetchSub(1) == 1) {
            signalInterruptionProcessingComplete()
        }
    }

    private func signalInterruptionProcessingComplete(): Unit {
        if (logger.isDebugEnabled()) {
            logger.debug(
                "transportInterruptionProcessingComplete: ${transportInteruptedProcess.load()} for:${info.connectionId}"
            )
        }

        var failoverTransport = transport.narrow(TypeInfo.of<FailoverTransport>())
        if (let Some(ft) <- (failoverTransport as FailoverTransport)) {
            if (let Some(connectionId) <- info.connectionId) {
                ft.connectionInterruptProcessingComplete(connectionId)
                if (logger.isDebugEnabled()) {
                    logger.debug("notified failover transport (${ft}) of interruption completion for: ${connectionId}")
                }
            }
        }
        transportInteruptedProcess.store(0)
    }

    private func signalInterruptionProcessingNeeded(): Unit {
        var failoverTransport = transport.narrow(TypeInfo.of<FailoverTransport>())
        if (let Some(ft) <- (failoverTransport as FailoverTransport)) {
            if (let Some(connectionId) <- info.connectionId) {
                ft.stateTracker.transportInterrupted(connectionId)
                if (logger.isDebugEnabled()) {
                    logger.debug(
                        "notified failover transport (${ft}) of pending interruption processing for: ${info.connectionId}"
                    )
                }
            }
        }
    }

    public prop localTransactionIdGenerator: Int64SequenceGenerator {
        get() {
            return this.localTransactionIdGeneratorVal
        }
    }

    public mut prop dispatchAsync: Bool {
        get() {
            return this.dispatchAsyncVal
        }
        set(value) {
            this.dispatchAsyncVal = value
        }
    }

    public mut prop alwaysSessionAsync: Bool {
        get() {
            return this.alwaysSessionAsyncVal
        }
        set(value) {
            this.alwaysSessionAsyncVal = value
        }
    }

    public mut prop prefetchPolicy: ActiveMQPrefetchPolicy {
        get() {
            return this.prefetchPolicyVal
        }
        set(value) {
            this.prefetchPolicyVal = value
        }
    }

    public func getRedeliveryPolicy(): ?RedeliveryPolicy {
        if (let Some(redeliveryPolicyMap) <- redeliveryPolicyMap) {
            return redeliveryPolicyMap.getDefaultEntry()
        }
        return None
    }

    public func setRedeliveryPolicy(redeliveryPolicy: RedeliveryPolicy) {
        if (let Some(redeliveryPolicyMap) <- redeliveryPolicyMap) {
            redeliveryPolicyMap.setDefaultEntry(redeliveryPolicy)
        }
    }

    public mut prop redeliveryPolicyMap: ?RedeliveryPolicyMap {
        get() {
            return this.redeliveryPolicyMapVal
        }
        set(value) {
            this.redeliveryPolicyMapVal = value
        }
    }

    public mut prop auditDepth: Int64 {
        get() {
            return this.connectionAudit.auditDepth
        }
        set(value) {
            this.connectionAudit.auditDepth = value
        }
    }

    public mut prop auditMaximumProducerNumber: Int64 {
        get() {
            return this.connectionAudit.auditMaximumProducerNumber
        }
        set(value) {
            this.connectionAudit.auditMaximumProducerNumber = value
        }
    }

    public mut prop transformer: ?MessageTransformer {
        get() {
            return this.transformerVal
        }
        set(value) {
            this.transformerVal = value
        }
    }

    public mut prop producerWindowSize: Int32 {
        get() {
            return this.producerWindowSizeVal
        }
        set(value) {
            this.producerWindowSizeVal = value
        }
    }

    public prop firstFailureException: ?TransportException {
        get() {
            return this.firstFailureExceptionVal
        }
    }

    public mut prop consumerFailoverRedeliveryWaitPeriod: Duration {
        get() {
            return this.consumerFailoverRedeliveryWaitPeriodVal
        }
        set(value) {
            this.consumerFailoverRedeliveryWaitPeriodVal = value
        }
    }

    public mut prop messagePrioritySupported: Bool {
        get() {
            return this.messagePrioritySupportedVal
        }
        set(value) {
            this.messagePrioritySupportedVal = value
        }
    }

    public mut prop transactedIndividualAck: Bool {
        get() {
            return this.transactedIndividualAckVal
        }
        set(value) {
            this.transactedIndividualAckVal = value
        }
    }

    public mut prop nonBlockingRedelivery: Bool {
        get() {
            return this.nonBlockingRedeliveryVal
        }
        set(value) {
            this.nonBlockingRedeliveryVal = value
        }
    }

    public mut prop rmIdFromConnectionId: Bool {
        get() {
            return this.rmIdFromConnectionIdVal
        }
        set(value) {
            this.rmIdFromConnectionIdVal = value
        }
    }

    public mut prop connectResponseTimeout: Int32 {
        get() {
            return this.connectResponseTimeoutVal
        }
        set(value) {
            this.connectResponseTimeoutVal = value
        }
    }

    public mut prop disableTimeStampsByDefault: Bool {
        get() {
            return this.disableTimeStampsByDefaultVal
        }
        set(value) {
            this.disableTimeStampsByDefaultVal = value
        }
    }

    public mut prop optimizedMessageDispatch: Bool {
        get() {
            return this.optimizedMessageDispatchVal
        }
        set(value) {
            this.optimizedMessageDispatchVal = value
        }
    }

    public mut prop copyMessageOnSend: Bool {
        get() {
            return this.copyMessageOnSendVal
        }
        set(value) {
            this.copyMessageOnSendVal = value
        }
    }

    public mut prop useCompression: Bool {
        get() {
            return this.useCompressionVal
        }
        set(value) {
            this.useCompressionVal = value
        }
    }

    public mut prop objectMessageSerializationDefered: Bool {
        get() {
            return this.objectMessageSerializationDeferedVal
        }
        set(value) {
            this.objectMessageSerializationDeferedVal = value
        }
    }

    public mut prop useAsyncSend: Bool {
        get() {
            return this.useAsyncSendVal
        }
        set(value) {
            this.useAsyncSendVal = value
        }
    }

    public mut prop optimizeAcknowledge: Bool {
        get() {
            return this.optimizeAcknowledgeVal
        }
        set(value) {
            this.optimizeAcknowledgeVal = value
        }
    }

    public mut prop optimizeAcknowledgeTimeOut: Int64 {
        get() {
            return this.optimizeAcknowledgeTimeOutVal
        }
        set(value) {
            this.optimizeAcknowledgeTimeOutVal = value
        }
    }

    public mut prop optimizedAckScheduledAckInterval: Int64 {
        get() {
            return this.optimizedAckScheduledAckIntervalVal
        }
        set(value) {
            this.optimizedAckScheduledAckIntervalVal = value
        }
    }

    public mut prop nestedMapAndListEnabled: Bool {
        get() {
            return this.nestedMapAndListEnabledVal
        }
        set(value) {
            this.nestedMapAndListEnabledVal = value
        }
    }

    public mut prop useRetroactiveConsumer: Bool {
        get() {
            return this.useRetroactiveConsumerVal
        }
        set(value) {
            this.useRetroactiveConsumerVal = value
        }
    }

    public mut prop exclusiveConsumer: Bool {
        get() {
            return this.exclusiveConsumerVal
        }
        set(value) {
            this.exclusiveConsumerVal = value
        }
    }

    public mut prop alwaysSyncSend: Bool {
        get() {
            return this.alwaysSyncSendVal
        }
        set(value) {
            this.alwaysSyncSendVal = value
        }
    }

    public mut prop closeTimeout: Int32 {
        get() {
            return this.closeTimeoutVal
        }
        set(value) {
            this.closeTimeoutVal = value
        }
    }

    public mut prop watchTopicAdvisories: Bool {
        get() {
            return this.watchTopicAdvisoriesVal
        }
        set(value) {
            this.watchTopicAdvisoriesVal = value
        }
    }

    public mut prop warnAboutUnstartedConnectionTimeout: Int64 {
        get() {
            return this.warnAboutUnstartedConnectionTimeoutVal
        }
        set(value) {
            this.warnAboutUnstartedConnectionTimeoutVal = value
        }
    }

    public mut prop sendTimeout: Int32 {
        get() {
            return this.sendTimeoutVal
        }
        set(value) {
            this.sendTimeoutVal = value
        }
    }

    public mut prop sendAcksAsync: Bool {
        get() {
            return this.sendAcksAsyncVal
        }
        set(value) {
            this.sendAcksAsyncVal = value
        }
    }

    public mut prop checkForDuplicates: Bool {
        get() {
            return this.checkForDuplicatesVal
        }
        set(value) {
            this.checkForDuplicatesVal = value
        }
    }

    public mut prop queueOnlyConnection: Bool {
        get() {
            return this.queueOnlyConnectionVal
        }
        set(value) {
            this.queueOnlyConnectionVal = value
        }
    }

    public mut prop consumerExpiryCheckEnabled: Bool {
        get() {
            return this.consumerExpiryCheckEnabledVal
        }
        set(value) {
            this.consumerExpiryCheckEnabledVal = value
        }
    }

    public mut prop exceptionListener: ?ExceptionListener {
        get() {
            return this.exceptionListenerVal
        }
        set(value) {
            this.exceptionListenerVal = value
        }
    }

    public mut prop clientInternalExceptionListener: ?ClientInternalExceptionListener {
        get() {
            return this.clientInternalExceptionListenerVal
        }
        set(value) {
            this.clientInternalExceptionListenerVal = value
        }
    }

    public func toString(): String {
        return "ActiveMQConnection"
    }
}

class AsyncExceptionTransmission <: Runnable {
    private let listener: ExceptionListener
    private let exception: CJMSException

    public init(listener: ExceptionListener, exception: CJMSException) {
        this.listener = listener
        this.exception = exception
    }

    public func run(): Unit {
        listener.onException(exception)
    }
}

class ExceptionDispose <: Runnable {
    private let exceptionDisposeFunc: () -> Unit

    public init(exceptionDisposeFunc: () -> Unit) {
        this.exceptionDisposeFunc = exceptionDisposeFunc
    }

    public func run(): Unit {
        exceptionDisposeFunc()
    }
}

class clientInternalExceptionPropagate <: Runnable {
    private let clientInternalExceptionListener: ClientInternalExceptionListener
    private let exception: Exception

    public init(clientInternalExceptionListener: ClientInternalExceptionListener, exception: Exception) {
        this.clientInternalExceptionListener = clientInternalExceptionListener
        this.exception = exception
    }

    public func run(): Unit {
        this.clientInternalExceptionListener.onException(exception)
    }
}
