package magic.app.services.aip.model

import std.collection.*
import std.time.*
import activemq4cj.cjms.CJMSProducer
import activemq4cj.cjms.CJMSConsumer

public class MqGroupChannelInfo {
    public var sessionId: String = ""
    public var topicName: String = ""
    public var producer: ?CJMSProducer = None<CJMSProducer>
    public var consumers: HashMap<String, CJMSConsumer> = HashMap<String, CJMSConsumer>()
    public var durableSubscriptions: ArrayList<String> = ArrayList<String>()
    public var createdAt: DateTime = DateTime.now()

    public init() {}
}