/*
 * Copyright (c) 2024-2025. All rights reserved.
 */
package magic.model.tokendance

import magic.core.model.*
import magic.utils.http.*
import magic.dsl.jsonable
import magic.jsonable.*

import stdx.encoding.json.*
import std.collection.{ArrayList, HashMap}

@jsonable
private class TokendanceEmbeddingResponse {
    let object: String
    let data: Array<TokendanceEmbeddingData>
    let model: String
    let usage: TokendanceEmbeddingUsage
}

@jsonable
private class TokendanceEmbeddingData {
    let object: String
    let embedding: Array<Float64>
    let index: Int64
}

@jsonable
private class TokendanceEmbeddingUsage {
    let prompt_tokens: Int64
    let total_tokens: Int64
}

public class TokendanceEmbeddingModel <: EmbeddingModel {
    private let model: String
    private let baseURL: String
    public let apiKey: String

    public init(
        model: String,
        apiKey!: String,
        baseURL!: String
    ) {
        this.model = model
        this.apiKey = apiKey
        this.baseURL = baseURL
    }

    override public prop provider: String {
        get() { "tokendance" }
    }

    override public prop name: String {
        get() { model }
    }

    public func create(embeddingReq: EmbeddingRequest): EmbeddingResponse {
        let req = JsonObject()
        req.put("input", JsonString(embeddingReq.prompt))
        req.put("model", JsonString(model))
        req.put("encoding_format", JsonString("float"))
        if (let Some(d) <- embeddingReq.dimensions) {
            req.put("dimensions", JsonInt(d))
        }
        let header = HashMap<String, String>(
            [("Content-Type", "application/json"), ("Authorization", "Bearer ${this.apiKey}")])
        match (HttpUtils.post("${this.baseURL}/embeddings", header, req)) {
            case Some(body) =>
                let resp = TokendanceEmbeddingResponse.fromJsonValue(JsonValue.fromStr(body))
                return EmbeddingResponse(resp.data[0].embedding)
            case None => throw ModelException("Fail to get tokendance embedding http response")
        }
    }
}
