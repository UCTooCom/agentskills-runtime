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

public open class ActiveMQConnectionFactory <: ConnectionFactory {
    public static let DEFAULT_PRODUCER_WINDOW_SIZE: Int32 = 0
    private static let DEFAULT_BROKER_HOST: String = "127.0.0.1"
    private static let DEFAULT_BROKER_PORT: Int32 = 61616
    public static let DEFAULT_BROKER_BIND_URL: String = "tcp://${DEFAULT_BROKER_HOST}:${DEFAULT_BROKER_PORT}"

    private let isCJMSPropertiesResolved: AtomicBool = AtomicBool(false)

    private var clientIdGeneratorVal: ?IdGenerator = None
    private var connectionIdGeneratorVal: ?IdGenerator = None
    private var clientIDPrefixVal: ?String = None
    private var connectionIDPrefix: ?String = None

    private var brokerURL: URL
    private var userNameVal: ?String = None
    private var passwordVal: ?String = None
    protected var clientIDVal: ?String = None
    protected var dispatchAsyncVal: Bool = true
    protected var alwaysSessionAsyncVal = true

    private var prefetchPolicyVal: ActiveMQPrefetchPolicy = ActiveMQPrefetchPolicy()
    private var redeliveryPolicyMapVal: RedeliveryPolicyMap = RedeliveryPolicyMap(RedeliveryPolicy())

    //禁用消息时间戳
    private var disableTimeStampsByDefaultVal: Bool = false
    //为true时对持久订阅者使用更大的预取限制
    private var optimizedMessageDispatchVal: Bool = true
    //批量确认的最大时间间隔
    private var optimizeAcknowledgeTimeOutVal: Int64 = 300
    //优化确认的时间周期
    private var optimizedAckScheduledAckIntervalVal: Int64 = 0
    //发送消息时拷贝该消息
    private var copyMessageOnSendVal: Bool = true
    //使用压缩
    private var useCompressionVal: Bool = false
    private var objectMessageSerializationDeferedVal: Bool = false
    private var useAsyncSendVal: Bool = false
    //优化确认，开启后采取批量确认，降低网络开销
    private var optimizeAcknowledgeVal: Bool = false
    private var closeTimeoutVal: Int32 = 15000
    //可追溯消费者允许非持久主题订阅者接收在非持久订阅者启动之前发布的旧消息
    private var useRetroactiveConsumerVal: Bool = false
    private var exclusiveConsumerVal: Bool = false
    private var nestedMapAndListEnabledVal: Bool = true
    //始终以同步方式发送
    private var alwaysSyncSendVal: Bool = false
    private var watchTopicAdvisoriesVal: Bool = true
    private var producerWindowSizeVal = DEFAULT_PRODUCER_WINDOW_SIZE
    private var warnAboutUnstartedConnectionTimeoutVal: Int64 = 500
    private var sendTimeoutVal: Int32 = 0
    private var connectResponseTimeoutVal: Int32 = 0
    //消息确认是否异步发送
    private var sendAcksAsyncVal: Bool = true
    private var transportListenerVal: ?TransportListener = None
    private var exceptionListenerVal: ?ExceptionListener = None
    private var transformer: ?MessageTransformer = None
    // 死信队列审核，防止重复的消息添加到配置的DLQ
    private var auditDepthVal: Int64 = ActiveMQMessageAudit.DEFAULT_WINDOW_SIZE
    private var auditMaximumProducerNumberVal: Int64 = ActiveMQMessageAudit.MAXIMUM_PRODUCER_COUNT
    private var consumerFailoverRedeliveryWaitPeriodVal: Duration = Duration.Zero
    private var checkForDuplicatesVal: Bool = true
    private var messagePrioritySupportedVal: Bool = false
    private var transactedIndividualAckVal: Bool = false
    private var nonBlockingRedeliveryVal: Bool = false
    private var rmIdFromConnectionIdVal: Bool = false
    private var consumerExpiryCheckEnabledVal: Bool = true

    private let monitor = Mutex()

    public init() {
        this(DEFAULT_BROKER_BIND_URL)
    }

    public init(brokerURL: String) {
        this(URL.parse(brokerURL))
    }

    public init(brokerURL: URL) {
        this.brokerURL = brokerURL
    }

    public init(userName: String, password: String, brokerURL: String) {
        this(userName, password, URL.parse(brokerURL))
    }

    public init(userName: String, password: String, brokerURL: URL) {
        this.userNameVal = userName
        this.passwordVal = password
        this.brokerURL = brokerURL
    }

    public func createConnection(): Connection {
        return createActiveMQConnection()
    }

    public func createConnection(userName: String, password: String): Connection {
        return createActiveMQConnection(userName, password)
    }

    protected func createActiveMQConnection(): ActiveMQConnection {
        return createActiveMQConnection(this.userName, this.password)
    }

    protected func createActiveMQConnection(userName: ?String, password: ?String): ActiveMQConnection {
        resolveCJMSProperties()
        //创建Transport
        let transport: Transport = createTransport()
        let connection = ActiveMQConnection(transport, clientIdGenerator, connectionIdGenerator)

        connection.setUserName(userName)
        connection.setPassword(password)

        if (let Some(clientID) <- this.clientID) {
            connection.setDefaultClientID(clientID)
        }

        configureConnection(connection)

        transport.start()
        return connection
    }

    protected open func createTransport(): Transport {
        let scheme: String = brokerURL.scheme
        var connectionURL = brokerURL
        if (scheme == "auto+ssl") {
            brokerURL.replace(scheme: "ssl")
        }
        return TransportFactory.connect(connectionURL)
    }

    public override func createContext(): CJMSContext {
        return ActiveMQContext(createActiveMQConnection())
    }

    public override func createContext(sessionMode: AcknowledgeMode): CJMSContext {
        return ActiveMQContext(createActiveMQConnection(this.userName, this.password), sessionMode)
    }

    public override func createContext(userName: String, password: String): CJMSContext {
        return ActiveMQContext(createActiveMQConnection(userName, password))
    }

    public override func createContext(userName: String, password: String, sessionMode: AcknowledgeMode): CJMSContext {
        return ActiveMQContext(createActiveMQConnection(userName, password), sessionMode)
    }

    protected func configureConnection(connection: ActiveMQConnection): Unit {
        connection.prefetchPolicy = prefetchPolicy
        connection.disableTimeStampsByDefault = disableTimeStampsByDefault
        connection.optimizedMessageDispatch = optimizedMessageDispatch
        connection.copyMessageOnSend = copyMessageOnSend
        connection.useCompression = useCompression
        connection.objectMessageSerializationDefered = objectMessageSerializationDefered
        connection.dispatchAsync = dispatchAsync
        connection.useAsyncSend = useAsyncSend
        connection.alwaysSyncSend = alwaysSyncSend
        connection.alwaysSessionAsync = alwaysSessionAsync
        connection.optimizeAcknowledge = optimizeAcknowledge
        connection.optimizeAcknowledgeTimeOut = optimizeAcknowledgeTimeOut
        connection.optimizedAckScheduledAckInterval = optimizedAckScheduledAckInterval
        connection.useRetroactiveConsumer = useRetroactiveConsumer
        connection.exclusiveConsumer = exclusiveConsumer
        connection.redeliveryPolicyMap = redeliveryPolicyMap
        connection.transformer = transformer
        connection.watchTopicAdvisories = watchTopicAdvisories
        connection.producerWindowSize = producerWindowSize
        connection.warnAboutUnstartedConnectionTimeout = warnAboutUnstartedConnectionTimeout
        connection.sendTimeout = sendTimeout
        connection.closeTimeout = closeTimeout
        connection.sendAcksAsync = sendAcksAsync
        connection.auditDepth = auditDepth
        connection.auditMaximumProducerNumber = auditMaximumProducerNumber
        connection.consumerFailoverRedeliveryWaitPeriod = consumerFailoverRedeliveryWaitPeriod
        connection.checkForDuplicates = checkForDuplicates
        connection.messagePrioritySupported = messagePrioritySupported
        connection.transactedIndividualAck = transactedIndividualAck
        connection.nonBlockingRedelivery = nonBlockingRedelivery
        connection.nestedMapAndListEnabled = nestedMapAndListEnabled
        connection.rmIdFromConnectionId = rmIdFromConnectionId
        connection.consumerExpiryCheckEnabled = consumerExpiryCheckEnabled
        connection.connectResponseTimeout = connectResponseTimeout
        if (let Some(transportListener) <- transportListener) {
            connection.addTransportListener(transportListener)
        }
        if (let Some(exceptionListener) <- exceptionListener) {
            connection.exceptionListener = exceptionListener
        }
    }

    /**
     * 解析并正确设置BrokerURL携带的CJMS参数
     */
    protected open func resolveCJMSProperties(): Unit {
        //确保多次调用也只会执行一次
        if (isCJMSPropertiesResolved.compareAndSwap(false, true)) {
            let rc: HashMap<String, ?String> = URLSupport.parseQuery(this.brokerURL)
            let jmsOptionsMap: HashMap<String, Any> = TypeConversionSupport.convertMap<String>(
                IntrospectionSupport.extractProperties<?String>(rc, "jms."))

            //利用反射设置ActiveMQPrefetchPolicy的变量值
            var prefetchPolicy = ActiveMQPrefetchPolicy()
            IntrospectionSupport.setProperties(prefetchPolicy, jmsOptionsMap, "prefetchPolicy.")
            this.prefetchPolicyVal = prefetchPolicy

            var redeliveryPolicy = RedeliveryPolicy()
            IntrospectionSupport.setProperties(redeliveryPolicy, jmsOptionsMap, "redeliveryPolicy.")
            this.redeliveryPolicy = redeliveryPolicy

            if (let Some(clientIDPrefix) <- jmsOptionsMap.remove("clientIDPrefix")) {
                if (let Some(prefix) <- (clientIDPrefix as Option<String>)) {
                    this.clientIDPrefixVal = prefix
                }
            }

            if (let Some(clientID) <- jmsOptionsMap.remove("clientID")) {
                if (let Some(clientID) <- (clientID as Option<String>)) {
                    this.clientID = clientID
                }
            }

            IntrospectionSupport.setProperties(this, jmsOptionsMap)

            if (!jmsOptionsMap.isEmpty()) {
                throw IllegalArgumentException(
                    "There are ${jmsOptionsMap.size} jms options that couldn't be set on the ConnectionFactory.Check the options are spelled correctly.This connection factory cannot be started."
                )
            }
            //解析到的jms参数会被剔除，形成新的URL
            this.brokerURL = URLSupport.createRemainingURI(brokerURL, rc)
        }
    }

    public func getBrokerURL(): String {
        return this.brokerURL.toString()
    }

    public func setBrokerURL(brokerURL: String): Unit {
        this.brokerURL = URL.parse(brokerURL)
    }

    public mut prop clientID: ?String {
        get() {
            return this.clientIDVal
        }
        set(value) {
            this.clientIDVal = value
        }
    }

    public mut prop userName: ?String {
        get() {
            return this.userNameVal
        }
        set(value) {
            this.userNameVal = value
        }
    }

    public mut prop password: ?String {
        get() {
            return this.passwordVal
        }
        set(value) {
            this.passwordVal = value
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
            return prefetchPolicyVal
        }
        set(value) {
            this.prefetchPolicyVal = value
        }
    }

    public mut prop redeliveryPolicy: ?RedeliveryPolicy {
        get() {
            return redeliveryPolicyMapVal.getDefaultEntry()
        }
        set(value) {
            //全局的重传策略
            this.redeliveryPolicyMapVal.setDefaultEntry(value)
        }
    }

    public mut prop redeliveryPolicyMap: RedeliveryPolicyMap {
        get() {
            return this.redeliveryPolicyMapVal
        }
        set(value) {
            //全局的重传策略
            this.redeliveryPolicyMapVal = value
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

    public mut prop closeTimeout: Int32 {
        get() {
            return this.closeTimeoutVal
        }
        set(value) {
            this.closeTimeoutVal = value
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

    public mut prop clientIDPrefix: ?String {
        get() {
            return this.clientIDPrefixVal
        }
        set(value) {
            this.clientIDPrefixVal = value
        }
    }

    protected mut prop clientIdGenerator: IdGenerator {
        get() {
            if (let Some(clientIdGenerator) <- this.clientIdGeneratorVal) {
                return clientIdGenerator
            } else {
                synchronized(monitor) {
                    var clientIdGenerator: IdGenerator
                    if (let Some(clientIDPrefix) <- this.clientIDPrefix) {
                        clientIdGenerator = IdGenerator(clientIDPrefix)
                    } else {
                        clientIdGenerator = IdGenerator()
                    }
                    this.clientIdGeneratorVal = clientIdGenerator
                    return clientIdGenerator
                }
            }
        }
        set(value) {
            this.clientIdGeneratorVal = value
        }
    }

    public func setConnectionIDPrefix(connectionIDPrefix: String) {
        this.connectionIDPrefix = connectionIDPrefix
    }

    protected mut prop connectionIdGenerator: IdGenerator {
        get() {
            if (let Some(connectionIdGenerator) <- this.connectionIdGeneratorVal) {
                return connectionIdGenerator
            } else {
                synchronized(monitor) {
                    var connectionIdGenerator: IdGenerator
                    if (let Some(connectionIDPrefix) <- this.connectionIDPrefix) {
                        connectionIdGenerator = IdGenerator(connectionIDPrefix)
                    } else {
                        connectionIdGenerator = IdGenerator()
                    }
                    this.connectionIdGeneratorVal = connectionIdGenerator
                    return connectionIdGenerator
                }
            }
        }
        set(value) {
            this.connectionIdGeneratorVal = value
        }
    }

    protected func setConnectionIdGenerator(connectionIdGenerator: IdGenerator): Unit {
        this.connectionIdGenerator = connectionIdGenerator
    }

    public mut prop nestedMapAndListEnabled: Bool {
        get() {
            return this.nestedMapAndListEnabledVal
        }
        set(value) {
            this.nestedMapAndListEnabledVal = value
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

    public mut prop watchTopicAdvisories: Bool {
        get() {
            return this.watchTopicAdvisoriesVal
        }
        set(value) {
            this.watchTopicAdvisoriesVal = value
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

    public mut prop connectResponseTimeout: Int32 {
        get() {
            return this.connectResponseTimeoutVal
        }
        set(value) {
            this.connectResponseTimeoutVal = value
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

    public mut prop transportListener: ?TransportListener {
        get() {
            return this.transportListenerVal
        }
        set(value) {
            this.transportListenerVal = value
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

    public mut prop auditDepth: Int64 {
        get() {
            return this.auditDepthVal
        }
        set(value) {
            this.auditDepthVal = value
        }
    }

    public mut prop auditMaximumProducerNumber: Int64 {
        get() {
            return this.auditMaximumProducerNumberVal
        }
        set(value) {
            this.auditMaximumProducerNumberVal = value
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

    public mut prop checkForDuplicates: Bool {
        get() {
            return this.checkForDuplicatesVal
        }
        set(value) {
            this.checkForDuplicatesVal = value
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

    public mut prop consumerExpiryCheckEnabled: Bool {
        get() {
            return this.consumerExpiryCheckEnabledVal
        }
        set(value) {
            this.consumerExpiryCheckEnabledVal = value
        }
    }
}
