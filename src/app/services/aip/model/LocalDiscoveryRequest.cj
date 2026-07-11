/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip.model

public class LocalDiscoveryRequest {
    public var name: Option<String> = None<String>
    public var skillKeyword: Option<String> = None<String>
    public var descriptionKeyword: Option<String> = None<String>
    public var page: Int64 = 1
    public var limit: Int64 = 20

    public init() {}

    public init(name: Option<String>, skillKeyword: Option<String>,
        descriptionKeyword: Option<String>, page: Int64, limit: Int64) {
        this.name = name
        this.skillKeyword = skillKeyword
        this.descriptionKeyword = descriptionKeyword
        this.page = page
        this.limit = limit
    }
}