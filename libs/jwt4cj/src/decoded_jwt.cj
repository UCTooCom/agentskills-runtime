/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

/*
 * Class that represents a Json Web Token that was decoded from it's string representation.
 */
public interface DecodedJWT <: Header & Payload {
    /*
     * Getter for the String Token used to create this JWT instance.
     *
     * @return the String Token.
     */
    func getToken(): String

    /*
     * Getter for the Header contained in the JWT as a Base64 encoded String.
     * This represents the first part of the token.
     *
     * @return the Header of the JWT.
     */
    func getHeader(): String

    /*
     * Getter for the Payload contained in the JWT as a Base64 encoded String.
     * This represents the second part of the token.
     *
     * @return the Payload of the JWT.
     */
    func getPayload(): String

    /*
     * Getter for the Signature contained in the JWT as a Base64 encoded String.
     * This represents the third part of the token.
     *
     * @return the Signature of the JWT.
     */
    func getSignature(): String
}
