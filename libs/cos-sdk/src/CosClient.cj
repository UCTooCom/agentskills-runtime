package cos

import std.collection.{HashMap, ArrayList}
import std.convert.*
import cos.sign.CosSigner
import cos.http.CosHttpClient
import cos.model.*

public class CosClient {
    private let config: CosClientConfig
    private let signer: CosSigner
    private let httpClient: CosHttpClient
    private let defaultBucket: ?String

    public init(config: CosClientConfig) {
        this.config = config
        this.signer = CosSigner(config.secretId, config.secretKey)
        this.httpClient = CosHttpClient(
            signer,
            config.region,
            defaultBucket: config.bucket,
            protocol: config.protocol,
            timeout: config.timeout
        )
        this.defaultBucket = config.bucket
    }

    public func putObject(request: PutObjectRequest): PutObjectResult {
        let bucket = resolveBucket(request.bucket)
        var headers = HashMap<String, String>()

        if (request.contentType.isSome()) {
            headers["Content-Type"] = request.contentType.getOrThrow()
        }
        if (request.contentLength.isSome()) {
            headers["Content-Length"] = "${request.contentLength.getOrThrow()}"
        }
        if (request.acl.isSome()) {
            headers["x-cos-acl"] = request.acl.getOrThrow()
        }

        for (key in request.metadata.keys()) {
            let optVal = request.metadata.get(key)
            if (optVal.isSome()) {
                headers["x-cos-meta-${key}"] = optVal.getOrThrow()
            }
        }

        let response = httpClient.put(bucket, request.key, request.body, headers: headers)

        if (!response.isSuccess()) {
            throw CosException("Put object failed: ${response.body}", response.statusCode, response.requestId)
        }

        var eTag = ""
        var location = ""
        let eTagOpt = response.headers.get("etag")
        if (eTagOpt.isSome()) {
            eTag = eTagOpt.getOrThrow()
        }
        let locationOpt = response.headers.get("location")
        if (locationOpt.isSome()) {
            location = locationOpt.getOrThrow()
        }
        let versionIdOpt = response.headers.get("x-cos-version-id")

        return PutObjectResult(eTag, location, versionId: versionIdOpt)
    }

    public func getObject(request: GetObjectRequest): GetObjectResult {
        let bucket = resolveBucket(request.bucket)
        let headers = HashMap<String, String>()

        let response = httpClient.get(bucket, request.key, headers: headers)

        if (!response.isSuccess()) {
            throw CosException("Get object failed: ${response.body}", response.statusCode, response.requestId)
        }

        var contentType = "application/octet-stream"
        let contentTypeOpt = response.headers.get("content-type")
        if (contentTypeOpt.isSome()) {
            contentType = contentTypeOpt.getOrThrow()
        }
        
        var contentLengthStr = "0"
        let contentLengthOpt = response.headers.get("content-length")
        if (contentLengthOpt.isSome()) {
            contentLengthStr = contentLengthOpt.getOrThrow()
        }
        let contentLength = tryParseInt64(contentLengthStr)
        
        var eTag = ""
        let eTagOpt = response.headers.get("etag")
        if (eTagOpt.isSome()) {
            eTag = eTagOpt.getOrThrow()
        }
        
        var lastModified = ""
        let lastModifiedOpt = response.headers.get("last-modified")
        if (lastModifiedOpt.isSome()) {
            lastModified = lastModifiedOpt.getOrThrow()
        }

        return GetObjectResult(
            response.body,
            contentType,
            contentLength,
            eTag,
            lastModified
        )
    }

    private func tryParseInt64(value: String): Int64 {
        Int64.parse(value)
    }

    public func deleteObject(request: DeleteObjectRequest): DeleteObjectResult {
        let bucket = resolveBucket(request.bucket)

        let response = httpClient.delete(bucket, request.key, headers: HashMap<String, String>())

        if (!response.isSuccess()) {
            throw CosException("Delete object failed: ${response.body}", response.statusCode, response.requestId)
        }

        return DeleteObjectResult(Int32(response.statusCode))
    }

    public func listObjects(request: ListObjectsRequest): ListObjectsResult {
        let bucket = resolveBucket(request.bucket)

        let response = httpClient.listObjects(
            bucket,
            prefix: request.prefix,
            delimiter: None,
            marker: request.marker,
            maxKeys: request.maxKeys
        )

        if (!response.isSuccess()) {
            throw CosException("List objects failed: ${response.body}", response.statusCode, response.requestId)
        }

        return parseListObjectsResponse(response.body)
    }

    public func headObject(request: GetObjectRequest): ObjectMetadata {
        let bucket = resolveBucket(request.bucket)

        let response = httpClient.head(bucket, request.key, headers: HashMap<String, String>())

        if (!response.isSuccess()) {
            throw CosException("Head object failed: ${response.body}", response.statusCode, response.requestId)
        }

        let headersMap = HashMap<String, String>()
        
        for (key in response.headers.keys()) {
            let valOpt = response.headers.get(key)
            if (valOpt.isSome()) {
                headersMap[key] = valOpt.getOrThrow()
            }
        }

        return ObjectMetadata(headers: headersMap)
    }

    public func doesObjectExist(bucket: String, key: String): Bool {
        let resolvedBucket = resolveBucket(bucket)
        try {
            let response = httpClient.head(resolvedBucket, key, headers: HashMap<String, String>())
            return response.isSuccess()
        } catch (ex: Exception) {
            return false
        }
    }

    private func resolveBucket(bucket: String): String {
        if (bucket.isEmpty()) {
            if (defaultBucket.isSome()) {
                return defaultBucket.getOrThrow()
            }
            throw CosException("Bucket is required", 0, "")
        }
        return bucket
    }

    private func parseListObjectsResponse(body: String): ListObjectsResult {
        let objects = ArrayList<CosObject>()
        var name = ""
        var prefix = ""
        var marker = ""
        var nextMarker: ?String = None
        var maxKeys: Int64 = 1000
        var isTruncated = false

        if (body.isEmpty()) {
            return ListObjectsResult(
                objects,
                name,
                prefix,
                marker,
                maxKeys,
                isTruncated,
                nextMarker: nextMarker
            )
        }

        let xmlDoc = parseXml(body)

        let nameOpt = xmlDoc.get("ListBucketResult/Name")
        if (nameOpt.isSome()) {
            name = nameOpt.getOrThrow()
        }
        let prefixOpt = xmlDoc.get("ListBucketResult/Prefix")
        if (prefixOpt.isSome()) {
            prefix = prefixOpt.getOrThrow()
        }
        let markerOpt = xmlDoc.get("ListBucketResult/Marker")
        if (markerOpt.isSome()) {
            marker = markerOpt.getOrThrow()
        }
        let nextMarkerOpt = xmlDoc.get("ListBucketResult/NextMarker")
        if (nextMarkerOpt.isSome()) {
            nextMarker = nextMarkerOpt
        }

        let maxKeysStrOpt = xmlDoc.get("ListBucketResult/MaxKeys")
        if (maxKeysStrOpt.isSome()) {
            let maxKeysStr = maxKeysStrOpt.getOrThrow()
            maxKeys = tryParseInt64(maxKeysStr)
        }

        let isTruncatedOpt = xmlDoc.get("ListBucketResult/IsTruncated")
        if (isTruncatedOpt.isSome()) {
            let isTruncatedStr = isTruncatedOpt.getOrThrow()
            isTruncated = isTruncatedStr == "true" || isTruncatedStr == "TRUE"
        }

        let contents = xmlDoc.getList("ListBucketResult/Contents")
        for (i in 0..contents.size) {
            let content = contents[i]
            
            var key = ""
            let keyOpt = content.get("Key")
            if (keyOpt.isSome()) {
                key = keyOpt.getOrThrow()
            }
            
            var lastModified = ""
            let lastModifiedOpt = content.get("LastModified")
            if (lastModifiedOpt.isSome()) {
                lastModified = lastModifiedOpt.getOrThrow()
            }
            
            var eTag = ""
            let eTagOpt = content.get("ETag")
            if (eTagOpt.isSome()) {
                eTag = eTagOpt.getOrThrow()
            }
            
            var sizeStr = "0"
            let sizeOpt = content.get("Size")
            if (sizeOpt.isSome()) {
                sizeStr = sizeOpt.getOrThrow()
            }
            let size = tryParseInt64(sizeStr)
            
            var storageClass = "STANDARD"
            let storageClassOpt = content.get("StorageClass")
            if (storageClassOpt.isSome()) {
                storageClass = storageClassOpt.getOrThrow()
            }

            objects.add(CosObject(
                key,
                lastModified,
                eTag,
                size,
                storageClass
            ))
        }

        return ListObjectsResult(
            objects,
            name,
            prefix,
            marker,
            maxKeys,
            isTruncated,
            nextMarker: nextMarker
        )
    }

    private func parseXml(xml: String): XmlDocument {
        return SimpleXmlParser.parse(xml)
    }

    public func close(): Unit {
        // HTTP client不需要关闭
    }
}

public class CosException <: Exception {
    public let statusCode: Int64
    public let requestId: String

    public init(message: String, statusCode: Int64, requestId: String) {
        super(message)
        this.statusCode = statusCode
        this.requestId = requestId
    }
}

private class XmlDocument {
    private let data: HashMap<String, String>
    private let lists: HashMap<String, ArrayList<XmlDocument>>

    public init() {
        this.data = HashMap<String, String>()
        this.lists = HashMap<String, ArrayList<XmlDocument>>()
    }

    public func put(key: String, value: String): Unit {
        data[key] = value
    }

    public func get(key: String): ?String {
        data.get(key)
    }

    public func addList(key: String, item: XmlDocument): Unit {
        let existing = lists.get(key)
        if (existing.isNone()) {
            lists[key] = ArrayList<XmlDocument>()
        }
        if (let Some(list) <- lists.get(key)) {
            list.add(item)
        }
    }

    public func getList(key: String): ArrayList<XmlDocument> {
        let optVal = lists.get(key)
        if (optVal.isSome()) {
            return optVal.getOrThrow()
        }
        return ArrayList<XmlDocument>()
    }
}

private class SimpleXmlParser {
    public static func parse(xml: String): XmlDocument {
        let doc = XmlDocument()
        let trimmed = xml.trimAscii()

        if (!trimmed.startsWith("<")) {
            return doc
        }

        parseElement(trimmed, 0, doc, "")

        return doc
    }

    private static func parseElement(xml: String, start: Int, doc: XmlDocument, parentPath: String): Int {
        var pos = start

        while (pos < xml.size) {
            let currentChar = xml[pos..pos+1]
            if (currentChar != "<") {
                pos++
                continue
            }

            let tagStart = pos
            let tagEndOpt = xml.indexOf(">", tagStart)

            if (tagEndOpt.isNone()) {
                break
            }

            let tagEnd = tagEndOpt.getOrThrow()
            let tagStr = xml[tagStart + 1..tagEnd]
            let tagParts = tagStr.split(" ")
            let tagName = tagParts[0]

            if (tagName.startsWith("/")) {
                return tagEnd + 1
            }

            let isSelfClosing = tagStr.endsWith("/")
            let contentStart = tagEnd + 1

            if (isSelfClosing) {
                let path = buildPath(parentPath, tagName)
                doc.put(path, "")
                pos = contentStart
                continue
            }

            let endTag = "</${tagName}>"
            let endTagStartOpt = xml.indexOf(endTag, contentStart)

            if (endTagStartOpt.isNone()) {
                break
            }

            let endTagStart = endTagStartOpt.getOrThrow()
            let content = xml[contentStart..endTagStart].trimAscii()
            let path = buildPath(parentPath, tagName)

            if (content.startsWith("<")) {
                let childDoc = XmlDocument()
                parseElement(xml, contentStart, childDoc, path)
                doc.addList(path, childDoc)
            } else {
                doc.put(path, content)
            }

            pos = endTagStart + endTag.size
        }

        return pos
    }

    private static func buildPath(parent: String, name: String): String {
        if (parent.isEmpty()) {
            return name
        }
        return "${parent}/${name}"
    }
}
