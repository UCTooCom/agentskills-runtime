/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

/*
 * The Claim class holds the value in a generic way so that it can be recovered in many representations.
 */
public interface Claim <: ToString {
    /*
     * Whether this Claim has a null value or not.
     * If the claim is not present, it will return false hence checking isMissing is advised as well
     *
     * @return whether this Claim has a null value or not.
     */
    func isNull(): Bool

    /*
     * Can be used to verify whether the Claim is found or not.
     * This will be true even if the Claim has None value associated to it.
     *
     * @return whether this Claim is present or not
     */
    func isMissing(): Bool

    /*
     * Get this Claim as a Boolean.
     * If the value isn't of type Boolean or it can't be converted to a Boolean, None will be returned.
     *
     * @return the value as a Boolean or None.
     */
    func asBool(): Bool

    /*
     * Get this Claim as an Int64.
     * If the value isn't of type Integer or it can't be converted to an Integer, None will be returned.
     *
     * @return the value as an Int64 or None.
     */
    func asInt(): Int64

    /*
     * Get this Claim as a Float64.
     * If the value isn't of type Float or it can't be converted to a Float, None will be returned.
     *
     * @return the value as a Int64 or None.
     */
    func asFloat(): Float64

    /*
     * Get this Claim as a String.
     * If the value isn't of type String, None will be returned. For a String representation of non-textual
     * claim types, clients can call toString().
     *
     * @return the value as a String or None if the underlying value is not a string.
     */
    func asString(): String

    /*
     * Get this Claim as a Date.
     * If the value can't be converted to a Date, {@code None} will be returned.
     *
     * @return the value as a Date or None.
     */
    func asTime(): DateTime

    /*
     * Get this Claim as an Array .
     * If the value isn't an Array, None will be returned.
     *
     * @return the value as an Array or None.
     * @throws JWTDecodeException if the values inside the Array can't be converted to a NodeType.
     */
    func asArray(): Array<NodeType>

    /*
     * Get this Claim as a List.
     * If the value isn't an Array, None will be returned.
     *
     * @return the value as a List or None.
     * @throws JWTDecodeException if the values inside the List can't be converted to a NodeType.
     */
    func asList(): ArrayList<NodeType>

    /*
     * Get this Claim as a generic Map of values.
     *
     * @return the value as instance of Map.
     * @throws JWTDecodeException if the value can't be converted to a Map.
     */
    func asMap(): Map<String, NodeType>

    /*
     * Get this Claim node value.
     *
     * @return the value as NodeType.
     */
    func getValue(): NodeType
}
