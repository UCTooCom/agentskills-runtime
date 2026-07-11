package magic.app.services.aip.model

public class MqAuthRequest {
    public var requesterAic: String = ""
    public var operation: String = ""
    public var groupId: String = ""
    public var targetAic: ?String = None<String>

    public init() {}
}