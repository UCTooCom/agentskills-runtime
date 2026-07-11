package magic.app.services.aip.model

public class MqConnectionConfig {
    public var brokerUrl: String = ""
    public var username: String = ""
    public var password: String = ""
    public var tlsEnabled: Bool = false
    public var maxReconnectAttempts: Int64 = 10
    public var reconnectDelay: Int64 = 5000

    public init() {}
}