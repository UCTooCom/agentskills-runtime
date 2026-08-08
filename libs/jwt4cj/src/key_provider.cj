/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

/*
 * Generic Public/Private Key provider.
 * While implementing, ensure the Private Key and Private Key ID doesn't change in between signing a token.
 *
 * @param <U> the class that represents the Public Key
 * @param <R> the class that represents the Private Key
 */
public interface KeyProvider<U, R> {
    /*
     * Getter for the Public Key instance with the given Id. Used to verify the signature on the JWT verification stage.
     *
     * @param keyId the Key Id specified in the Token's Header or null if none is available.
     * Provides a hint on which Public Key to use to verify the token's signature.
     * @return the Public Key instance
     */
    func getPublicKey(): U

    /*
     * Getter for the Private Key instance. Used to sign the content on the JWT signing stage.
     *
     * @return the Private Key instance
     */
    func getPrivateKey(): R
}
