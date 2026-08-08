/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public class JWTParser <: JWTPartsParser {
    private let headerReader = HeaderDeserializer()
    private let payloadReader = PayloadDeserializer()

    public init() {}

    public override func parseHeader(jsons: String): Header {
        try {
            headerReader.doDeserialize(jsons)
        } catch (e: JsonException) {
            throw JWTDecodeException("The string '${jsons}' doesn't have a valid JSON format.")
        }
    }

    public override func parsePayload(jsons: String): Payload {
        try {
            payloadReader.doDeserialize(jsons)
        } catch (e: JsonException) {
            throw JWTDecodeException("The string '${jsons}' doesn't have a valid JSON format.")
        }
    }
}
