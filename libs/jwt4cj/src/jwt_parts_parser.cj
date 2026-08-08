/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

/*
 * The JWTPartsParser class defines which parts of the JWT should be converted
 * to its specific Object representation instance.
 */
public interface JWTPartsParser {
    /*
     * Parses the given JSON into a Payload instance.
     *
     * @param json the content of the Payload in a JSON representation.
     * @return the Payload.
     * @throws JWTDecodeException if the json doesn't have a proper JSON format.
     */
    func parsePayload(jsons: String): Payload

    /*
     * Parses the given JSON into a Header instance.
     *
     * @param json the content of the Header in a JSON representation.
     * @return the Header.
     * @throws JWTDecodeException if the json doesn't have a proper JSON format.
     */
    func parseHeader(jsons: String): Header
}
