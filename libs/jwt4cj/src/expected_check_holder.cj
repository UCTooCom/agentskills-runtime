/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

// 
public interface ExpectedCheckHolder {

    /**
     * The claim name that will be checked.
     *
     * @return the claim name
     */
    func getClaimName(): String

    /**
     * The verification that will be run.
     *
     * @param claim the claim for which verification is done
     * @param decodedJWT the JWT on which verification is done
     * @return whether the verification passed or not
     */
    func verify(claim: Claim, decodedJWT: DecodedJWT): Bool
}
