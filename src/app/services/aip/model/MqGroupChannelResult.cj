package magic.app.services.aip.model

import std.collection.*

public class MqGroupChannelResult {
    public var sessionId: String = ""
    public var topicName: String = ""
    public var subscribedMembers: ArrayList<String> = ArrayList<String>()
    public var failedMembers: ArrayList<String> = ArrayList<String>()

    public init() {}
}