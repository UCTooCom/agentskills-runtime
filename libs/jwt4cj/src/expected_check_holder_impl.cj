/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public class ExpectedCheckHolderImpl <: ExpectedCheckHolder {
    private var claimName: String

    private var predicate: (Claim, DecodedJWT) -> Bool

    public init(climeName: String, predicate: (Claim, DecodedJWT) -> Bool) {
        this.claimName = climeName
        this.predicate = predicate
    }

    /**
     * The claim name that will be checked.
     *
     * @return the claim name
     */
    public func getClaimName(): String {
        return claimName
    }

    /**
     * The verification that will be run.
     *
     * @param claim the claim for which verification is done
     * @param decodedJWT the JWT on which verification is done
     * @return whether the verification passed or not
     */
    public func verify(claim: Claim, decodedJWT: DecodedJWT): Bool {
        predicate(claim, decodedJWT)
    }
}
