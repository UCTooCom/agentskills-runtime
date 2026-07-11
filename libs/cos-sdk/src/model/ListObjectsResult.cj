package cos.model

import std.collection.ArrayList

public class ListObjectsResult {
    public let objects: ArrayList<CosObject>
    public let name: String
    public let prefix: String
    public let marker: String
    public let maxKeys: Int64
    public let isTruncated: Bool
    public let nextMarker: ?String

    public init(
        objects: ArrayList<CosObject>,
        name: String,
        prefix: String,
        marker: String,
        maxKeys: Int64,
        isTruncated: Bool,
        nextMarker!: ?String = None
    ) {
        this.objects = objects
        this.name = name
        this.prefix = prefix
        this.marker = marker
        this.maxKeys = maxKeys
        this.isTruncated = isTruncated
        this.nextMarker = nextMarker
    }
}