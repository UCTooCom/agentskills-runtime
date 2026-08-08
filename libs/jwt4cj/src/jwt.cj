/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public class JWT {
    private let parser: JWTParser

    public init() {
        this.parser = JWTParser()
    }

    public func decodeJwt(token: String): DecodedJWT {
        JWTDecoder(parser, token)
    }

    public static func decode(token: String): DecodedJWT {
        JWTDecoder(token)
    }

    public static func require(algorithm: Algorithm): Verification {
        BaseJWTVerifier.builder(algorithm)
    }

    // public static func require(algorithm:Algorithm): Verification{}

    /*
     * Returns a Json Web Token builder used to create and sign tokens.
     *
     * @return a token builder.
     */
    public static func create(): Builder {
        JWTCreator.builder()
    }
}
