/**
 * @file
 * This file is about yaml simple key.
 */

package yaml4cj.yaml

/**
 * The class is SimpleKeyT inherited from ToString
 * @author changeden
 * @since 0.30.4
 */
class SimpleKeyT {
    var possible: Bool = false
    var required: Bool = false
    var tokenNumber: Int64 = 0
    var mark: MarkT = MarkT()

    /**
     * The Function is toString
     *
     * @return Type of String
     * @since 0.30.4
     */
    /*public func toString(): String {
        "possible=${possible} required=${required} tokenNumber=${tokenNumber} mark=${mark}"
    }*/
}
