/**
 * @file
 * This file is about yaml mark.
 */

package yaml4cj.yaml

/**
 * The class is MarkT inherited from ToString
 * @author changeden
 * @since 0.30.4
 */
class MarkT {
    var index: Int64 = 0
    var line: Int64 = 0
    var column: Int64 = 0

    /**
     * The Function is clone
     *
     * @return Type of MarkT
     * @since 0.30.4
     */
    func clone(): MarkT {
        let m = MarkT()
        m.index = index
        m.line = line
        m.column = column
        m
    }

    /**
     * The Function is toString
     *
     * @return Type of String
     * @since 0.30.4
     */
    /*public func toString(): String {
        """
        { index=${index}, line=${line}, column=${column} }
        """
    }*/
}
