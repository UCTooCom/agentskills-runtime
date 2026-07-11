package magic.app.services.aip.acps

import std.collection.*
import std.convert.*
import std.time.*
import stdx.encoding.json.*
import activemq4cj.cjms.CJMSContext
import activemq4cj.cjms.CJMSProducer
import activemq4cj.cjms.CJMSConsumer
import activemq4cj.cjms.Topic
import activemq4cj.cjms.DeliveryMode
import activemq4cj.cjms.AcknowledgeMode
import activemq4cj.cjms.MessageListener
import activemq4cj.cjms.Message
import activemq4cj.cjms.TextMessage
import activemq4cj.client.ActiveMQConnectionFactory
import magic.utils.http.HttpUtils
import magic.utils.getEnv
import magic.log.LogUtils
import magic.app.core.response.APIResult

import magic.app.services.aip.model.MqConnectionState
import magic.app.services.aip.model.MqGroupChannelInfo
import magic.app.services.aip.model.MqAuthRequest
import magic.app.services.aip.model.MqAuthResult
import magic.app.services.aip.model.MqGroupChannelResult
import magic.app.services.aip.model.MqConnectionConfig
import magic.app.services.aip.model.MqMessageCallbackFunc

public class AcpsMqAdapter {
    private var connectionState: MqConnectionState = MqConnectionState.Disconnected
    private var groupChannels: HashMap<String, MqGroupChannelInfo> = HashMap<String, MqGroupChannelInfo>()
    private var jmsContext: ?CJMSContext = None<CJMSContext>
    private var messageCallback: ?MqMessageCallbackFunc = None<MqMessageCallbackFunc>
    private var processedIds: HashSet<String> = HashSet<String>()
    private let maxProcessedIds: Int64 = 1000

    private func ensureInterconnectionMode(): Bool {
        let mode = getEnv("AIP_MODE") ?? "local"
        return mode == "interconnection"
    }

    public func createGroupChannel(sessionId!: String, requesterAic!: String, memberAics!: ArrayList<String>, durable!: Bool): APIResult<MqGroupChannelResult> {
        if (!ensureInterconnectionMode()) {
            return APIResult<MqGroupChannelResult>(false, "AIP-MQ-014: 本地模式不支持MQ群组交互")
        }

        try {
            let connResult = establishConnection()
            if (!connResult.success) {
                return APIResult<MqGroupChannelResult>(false, connResult.reason ?? "AIP-MQ-002: MQ连接建立失败")
            }

            var authReq = MqAuthRequest()
            authReq.requesterAic = requesterAic
            authReq.operation = "create_group"
            authReq.groupId = sessionId
            let aclResult = checkAcl(authReq)
            if (aclResult.success && !aclResult.data.getOrThrow().allowed) {
                return APIResult<MqGroupChannelResult>(false, "AIP-MQ-005: 群组操作ACL鉴权失败")
            }

            return createTopicAndConsumers(sessionId, memberAics, durable)
        } catch (e: Exception) {
            LogUtils.error("AcpsMqAdapter", "createGroupChannel failed: ${e.message}")
            return APIResult<MqGroupChannelResult>(false, "AIP-MQ-006: 群组通道创建失败: ${e.message}")
        }
    }

    public func publishGroupMessage(sessionId!: String, messageId!: String, senderAic!: String, senderRole!: String, dataItems!: String, deliveryMode!: String, timeToLive!: Int64): APIResult<Bool> {
        if (!ensureInterconnectionMode()) {
            return APIResult<Bool>(false, "AIP-MQ-014: 本地模式不支持MQ消息发布")
        }

        try {
            var authReq = MqAuthRequest()
            authReq.requesterAic = senderAic
            authReq.operation = "publish_message"
            authReq.groupId = sessionId
            let aclResult = checkAcl(authReq)
            if (aclResult.success && !aclResult.data.getOrThrow().allowed) {
                return APIResult<Bool>(false, "AIP-MQ-005: 消息发布ACL鉴权失败")
            }

            return publishToTopic(sessionId, messageId, senderAic, senderRole, dataItems, deliveryMode, timeToLive)
        } catch (e: Exception) {
            LogUtils.error("AcpsMqAdapter", "publishGroupMessage failed: ${e.message}")
            return APIResult<Bool>(false, "AIP-MQ-009: 群组消息发送失败: ${e.message}")
        }
    }

    public func subscribeGroupChannel(sessionId!: String, subscriberAic!: String, durable!: Bool): APIResult<Bool> {
        if (!ensureInterconnectionMode()) {
            return APIResult<Bool>(false, "AIP-MQ-014: 本地模式不支持MQ群组订阅")
        }

        try {
            var authReq = MqAuthRequest()
            authReq.requesterAic = subscriberAic
            authReq.operation = "subscribe_group"
            authReq.groupId = sessionId
            let aclResult = checkAcl(authReq)
            if (aclResult.success && !aclResult.data.getOrThrow().allowed) {
                return APIResult<Bool>(false, "AIP-MQ-005: 群组订阅ACL鉴权失败")
            }

            return addConsumer(sessionId, subscriberAic, durable)
        } catch (e: Exception) {
            LogUtils.error("AcpsMqAdapter", "subscribeGroupChannel failed: ${e.message}")
            return APIResult<Bool>(false, "AIP-MQ-007: 群组订阅失败: ${e.message}")
        }
    }

    public func unsubscribeGroupChannel(sessionId!: String, subscriberAic!: String): APIResult<Bool> {
        if (!ensureInterconnectionMode()) {
            return APIResult<Bool>(false, "AIP-MQ-014: 本地模式不支持MQ群组退订")
        }

        try {
            var authReq = MqAuthRequest()
            authReq.requesterAic = subscriberAic
            authReq.operation = "unsubscribe_group"
            authReq.groupId = sessionId
            let aclResult = checkAcl(authReq)
            if (aclResult.success && !aclResult.data.getOrThrow().allowed) {
                return APIResult<Bool>(false, "AIP-MQ-005: 群组退订ACL鉴权失败")
            }

            return removeConsumer(sessionId, subscriberAic)
        } catch (e: Exception) {
            LogUtils.error("AcpsMqAdapter", "unsubscribeGroupChannel failed: ${e.message}")
            return APIResult<Bool>(false, "AIP-MQ-008: 群组退订失败: ${e.message}")
        }
    }

    public func destroyGroupChannel(sessionId!: String): APIResult<Bool> {
        if (!ensureInterconnectionMode()) {
            return APIResult<Bool>(true)
        }

        try {
            return closeTopicAndConsumers(sessionId)
        } catch (e: Exception) {
            LogUtils.error("AcpsMqAdapter", "destroyGroupChannel failed: ${e.message}")
            return APIResult<Bool>(false, "AIP-MQ-008: 群组通道销毁异常: ${e.message}")
        }
    }

    public func releaseAllResources(): APIResult<Bool> {
        try {
            closeConnection()
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            LogUtils.warn("AcpsMqAdapter", "AIP-MQ-014: MQ资源释放异常: ${e.message}")
            connectionState = MqConnectionState.Disconnected
            return APIResult<Bool>(false, "AIP-MQ-014: MQ资源释放异常，已强制标记释放")
        }
    }

    public func checkConnectivity(): Bool {
        if (!ensureInterconnectionMode()) {
            return false
        }
        return connectionState == MqConnectionState.Connected
    }

    public func getConnectionState(): MqConnectionState {
        return connectionState
    }

    public func setMessageCallback(callback!: MqMessageCallbackFunc): Unit {
        messageCallback = callback
        for ((_, channel) in groupChannels) {
            for ((_, consumer) in channel.consumers) {
                consumer.messageListener = MqMessageListener(adapter: this)
            }
        }
    }

    private func establishConnection(): APIResult<Bool> {
        if (connectionState == MqConnectionState.Connected && jmsContext.isSome()) {
            return APIResult<Bool>(true)
        }

        connectionState = MqConnectionState.Connecting

        let configOpt = loadConnectionConfig()
        if (configOpt.isNone()) {
            connectionState = MqConnectionState.Unavailable
            return APIResult<Bool>(false, "AIP-MQ-001: MQ连接配置缺失，请检查AIP_MQ_ENDPOINT等环境变量")
        }

        let config = configOpt.getOrThrow()

        try {
            let factory = ActiveMQConnectionFactory(config.brokerUrl)
            let context = factory.createContext(config.username, config.password, AcknowledgeMode.AUTO_ACKNOWLEDGE)
            jmsContext = context
            connectionState = MqConnectionState.Connected
            LogUtils.info("AcpsMqAdapter", "MQ connection established to ${config.brokerUrl}")
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            connectionState = MqConnectionState.Unavailable
            LogUtils.error("AcpsMqAdapter", "AIP-MQ-002: MQ连接建立失败: ${e.message}")
            return APIResult<Bool>(false, "AIP-MQ-002: MQ连接建立失败: ${e.message}")
        }
    }

    private func closeConnection(): Unit {
        for ((sessionId, _) in groupChannels) {
            closeTopicAndConsumers(sessionId)
        }
        groupChannels.clear()

        if (let Some(ctx) <- jmsContext) {
            try {
                ctx.close()
            } catch (e: Exception) {
                LogUtils.warn("AcpsMqAdapter", "Error closing JMS context: ${e.message}")
            }
            jmsContext = None<CJMSContext>
        }
        connectionState = MqConnectionState.Disconnected
        LogUtils.info("AcpsMqAdapter", "MQ connection closed")
    }

    private func loadConnectionConfig(): ?MqConnectionConfig {
        let brokerUrl = getEnv("AIP_MQ_ENDPOINT")
        let username = getEnv("AIP_MQ_USERNAME")
        let password = getEnv("AIP_MQ_PASSWORD")

        if (brokerUrl.isNone() || username.isNone() || password.isNone()) {
            return None<MqConnectionConfig>
        }

        let config = MqConnectionConfig()
        config.brokerUrl = brokerUrl.getOrThrow()
        config.username = username.getOrThrow()
        config.password = password.getOrThrow()

        let tlsStr = getEnv("AIP_MQ_TLS_ENABLED")
        if (tlsStr.isSome()) { config.tlsEnabled = tlsStr.getOrThrow() == "true" }

        let maxReconnect = getEnv("AIP_MQ_MAX_RECONNECT_ATTEMPTS")
        if (maxReconnect.isSome()) {
            try {
                let parsed = Int64.parse(maxReconnect.getOrThrow())
                if (parsed > 0) { config.maxReconnectAttempts = parsed }
            } catch (_: Exception) {}
        }

        let delayStr = getEnv("AIP_MQ_RECONNECT_DELAY")
        if (delayStr.isSome()) {
            try {
                let parsed = Int64.parse(delayStr.getOrThrow())
                if (parsed > 0) { config.reconnectDelay = parsed }
            } catch (_: Exception) {}
        }

        return config
    }

    private func checkAcl(request: MqAuthRequest): APIResult<MqAuthResult> {
        let authUrl = getAuthUrl()
        if (authUrl.isEmpty()) {
            let result = MqAuthResult()
            result.allowed = false
            result.reason = "AIP-MQ-013: MQ鉴权服务不可用"
            return APIResult<MqAuthResult>(result)
        }

        try {
            var reqMap = HashMap<String, JsonValue>()
            reqMap.add("requesterAic", JsonString(request.requesterAic))
            reqMap.add("operation", JsonString(request.operation))
            reqMap.add("groupId", JsonString(request.groupId))
            if (request.targetAic.isSome()) {
                reqMap.add("targetAic", JsonString(request.targetAic.getOrThrow()))
            }

            let header = HashMap<String, String>()
            header.add("Content-Type", "application/json")
            header.add("Accept", "application/json")
            let token = getEnv("AIP_MQ_AUTH_TOKEN")
            if (token.isSome()) {
                header.add("Authorization", "Bearer ${token.getOrThrow()}")
            }

            let response = HttpUtils.post("${authUrl}/api/v1/acl/check", header, JsonObject(reqMap))
            if (response.isNone()) {
                let result = MqAuthResult()
                result.allowed = false
                result.reason = "AIP-MQ-013: MQ鉴权服务不可用"
                return APIResult<MqAuthResult>(result)
            }

            let result = MqAuthResult()
            result.allowed = response.getOrThrow().contains("\"allowed\":true")
            return APIResult<MqAuthResult>(result)
        } catch (e: Exception) {
            LogUtils.error("AcpsMqAdapter", "checkAcl failed: ${e.message}")
            let result = MqAuthResult()
            result.allowed = false
            result.reason = "AIP-MQ-013: MQ鉴权服务暂不可用"
            return APIResult<MqAuthResult>(result)
        }
    }

    private func getAuthUrl(): String {
        getEnv("AIP_MQ_AUTH_URL") ?? ""
    }

    private func createTopicAndConsumers(sessionId: String, memberAics: ArrayList<String>, durable: Bool): APIResult<MqGroupChannelResult> {
        if (let Some(ctx) <- jmsContext) {
            let topicName = "aip.group.${sessionId}"
            let topic = ctx.createTopic(topicName)
            let producer = ctx.createProducer()
            producer.setDeliveryMode(DeliveryMode.PERSISTENT)
            producer.setTimeToLive(0)

            let channelInfo = MqGroupChannelInfo()
            channelInfo.sessionId = sessionId
            channelInfo.topicName = topicName
            channelInfo.producer = producer

            let result = MqGroupChannelResult()
            result.sessionId = sessionId
            result.topicName = topicName

            let listener = MqMessageListener(adapter: this)
            for (memberAic in memberAics) {
                try {
                    let consumer = if (durable) {
                        ctx.createDurableConsumer(topic, "aip.sub.${memberAic}.${sessionId}", None<String>, false)
                    } else {
                        ctx.createConsumer(topic)
                    }
                    consumer.messageListener = listener
                    channelInfo.consumers.add(memberAic, consumer)
                    if (durable) { channelInfo.durableSubscriptions.add(memberAic) }
                    result.subscribedMembers.add(memberAic)
                } catch (e: Exception) {
                    LogUtils.warn("AcpsMqAdapter", "AIP-MQ-007: Failed to create consumer for ${memberAic}: ${e.message}")
                    result.failedMembers.add(memberAic)
                }
            }

            groupChannels.add(sessionId, channelInfo)
            return APIResult<MqGroupChannelResult>(result)
        } else {
            return APIResult<MqGroupChannelResult>(false, "AIP-MQ-002: MQ连接不可用")
        }
    }

    private func closeTopicAndConsumers(sessionId: String): APIResult<Bool> {
        let channelOpt = groupChannels.get(sessionId)
        if (channelOpt.isNone()) {
            return APIResult<Bool>(true)
        }

        let channel = channelOpt.getOrThrow()
        try {
            for ((_, consumer) in channel.consumers) {
                try {
                    consumer.close()
                } catch (e: Exception) {
                    LogUtils.warn("AcpsMqAdapter", "AIP-MQ-008: Error closing consumer: ${e.message}")
                }
            }

            if (let Some(producer) <- channel.producer) {
                channel.producer = None<CJMSProducer>
            }
        } catch (e: Exception) {
            LogUtils.warn("AcpsMqAdapter", "AIP-MQ-008: 群组通道销毁异常: ${e.message}")
        }

        groupChannels.remove(sessionId)
        return APIResult<Bool>(true)
    }

    private func addConsumer(sessionId: String, subscriberAic: String, durable: Bool): APIResult<Bool> {
        let channelOpt = groupChannels.get(sessionId)
        if (channelOpt.isNone()) {
            return APIResult<Bool>(false, "AIP-MQ-007: 群组通道不存在")
        }

        let channel = channelOpt.getOrThrow()
        if (let Some(ctx) <- jmsContext) {
            try {
                let topic = ctx.createTopic(channel.topicName)
                let consumer = if (durable) {
                    ctx.createDurableConsumer(topic, "aip.sub.${subscriberAic}.${sessionId}", None<String>, false)
                } else {
                    ctx.createConsumer(topic)
                }
                let listener = MqMessageListener(adapter: this)
                consumer.messageListener = listener
                channel.consumers.add(subscriberAic, consumer)
                if (durable) { channel.durableSubscriptions.add(subscriberAic) }
                return APIResult<Bool>(true)
            } catch (e: Exception) {
                LogUtils.error("AcpsMqAdapter", "addConsumer failed: ${e.message}")
                return APIResult<Bool>(false, "AIP-MQ-007: 群组订阅失败: ${e.message}")
            }
        } else {
            return APIResult<Bool>(false, "AIP-MQ-002: MQ连接不可用")
        }
    }

    private func removeConsumer(sessionId: String, subscriberAic: String): APIResult<Bool> {
        let channelOpt = groupChannels.get(sessionId)
        if (channelOpt.isNone()) {
            return APIResult<Bool>(true)
        }

        let channel = channelOpt.getOrThrow()
        let consumerOpt = channel.consumers.get(subscriberAic)
        if (consumerOpt.isNone()) {
            return APIResult<Bool>(true)
        }

        try {
            consumerOpt.getOrThrow().close()
            channel.consumers.remove(subscriberAic)
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            LogUtils.error("AcpsMqAdapter", "removeConsumer failed: ${e.message}")
            return APIResult<Bool>(false, "AIP-MQ-008: 群组退订失败: ${e.message}")
        }
    }

    private func publishToTopic(sessionId: String, messageId: String, senderAic: String, senderRole: String, dataItems: String, deliveryMode: String, timeToLive: Int64): APIResult<Bool> {
        let channelOpt = groupChannels.get(sessionId)
        if (channelOpt.isNone()) {
            return APIResult<Bool>(false, "AIP-MQ-009: 群组通道不存在，无法发送消息")
        }

        let channel = channelOpt.getOrThrow()
        if (let Some(ctx) <- jmsContext) {
            if (let Some(producer) <- channel.producer) {
                try {
                    var bodyMap = HashMap<String, JsonValue>()
                    bodyMap.add("messageId", JsonString(messageId))
                    bodyMap.add("sessionId", JsonString(sessionId))
                    bodyMap.add("senderAic", JsonString(senderAic))
                    bodyMap.add("senderRole", JsonString(senderRole))
                    bodyMap.add("dataItems", JsonString(dataItems))
                    let jsonBody = JsonObject(bodyMap).toString()

                    let message = ctx.createTextMessage(jsonBody)
                    message.setStringProperty("messageId", messageId)
                    message.setStringProperty("sessionId", sessionId)
                    message.setStringProperty("senderAic", senderAic)
                    message.setStringProperty("senderRole", senderRole)

                    if (deliveryMode == "NON_PERSISTENT") {
                        producer.setDeliveryMode(DeliveryMode.NON_PERSISTENT)
                    } else {
                        producer.setDeliveryMode(DeliveryMode.PERSISTENT)
                    }

                    if (timeToLive > 0) {
                        producer.setTimeToLive(timeToLive)
                    }

                    let topic = ctx.createTopic(channel.topicName)
                    producer.send(topic, message)
                    return APIResult<Bool>(true)
                } catch (e: Exception) {
                    LogUtils.error("AcpsMqAdapter", "publishToTopic failed: ${e.message}")
                    return APIResult<Bool>(false, "AIP-MQ-009: 群组消息发送失败: ${e.message}")
                }
            }
        }
        return APIResult<Bool>(false, "AIP-MQ-009: MQ连接或生产者不可用")
    }

    public func onMqMessageReceived(message: Message): Unit {
        try {
            let textMsg = message as TextMessage
            if (textMsg.isNone()) {
                return
            }

            let body = textMsg.getOrThrow().text ?? ""
            let msgMessageId = message.getStringProperty("messageId")
            let sessionId = message.getStringProperty("sessionId")
            let senderAic = message.getStringProperty("senderAic")
            let senderRole = message.getStringProperty("senderRole")

            if (processedIds.contains(msgMessageId)) {
                return
            }

            if (processedIds.size >= maxProcessedIds) {
                processedIds.clear()
            }
            processedIds.add(msgMessageId)

            if (let Some(callback) <- messageCallback) {
                let result = callback(sessionId, msgMessageId, senderAic, senderRole, body, None<String>)
                if (!result.success) {
                    LogUtils.error("AcpsMqAdapter", "AIP-MQ-010: 消息回调处理失败: ${result.reason ?? "unknown"}")
                }
            }
        } catch (e: Exception) {
            LogUtils.error("AcpsMqAdapter", "AIP-MQ-010: 消息接收处理异常: ${e.message}")
        }
    }
}

public class MqMessageListener <: MessageListener {
    private let adapter: AcpsMqAdapter

    public init(adapter!: AcpsMqAdapter) {
        this.adapter = adapter
    }

    public func onMessage(message: Message): Unit {
        adapter.onMqMessageReceived(message)
    }
}