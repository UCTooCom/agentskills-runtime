/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

public class ConfigMetadataVO {
    public var envKey: String = ""
    public var name: String = ""
    public var configGroup: String = "other"
    public var configType: String = "string"
    public var isSensitive: Bool = false
    public var defaultValue: Option<String> = None<String>
    public var validationRule: Option<String> = None<String>
    public var description: Option<String> = None<String>
    public var displayOrder: Int32 = 0
    public var editable: Bool = true

    public init() {}
}