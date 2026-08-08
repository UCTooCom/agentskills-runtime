/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public class HeaderDeserializer <: Deserializer {
    func doDeserialize(jsonStr: String): Header {
        let map = super.deserialize(jsonStr)
        let algorithm: ?String = asString(HeaderParams.ALGORITHM, map)
        let typ: ?String = asString(HeaderParams.TYPE, map)
        let contentType: ?String = asString(HeaderParams.CONTENT_TYPE, map)
        let keyId: ?String = asString(HeaderParams.KEY_ID, map)
        BaseHeader(algorithm, typ, contentType, keyId, map)
    }
}
