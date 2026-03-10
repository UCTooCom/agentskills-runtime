/**
 * @file
 * this file is about yaml break.
 */

package yaml4cj.yaml

enum BreakT <: Hashable {
    | BreakT_ANY_BREAK
    | BreakT_CR_BREAK
    | BreakT_LN_BREAK
    | BreakT_CRLN_BREAK

    /**
     * The Function is hashCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    public func hashCode(): Int64 {
        match (this) {
            case BreakT_ANY_BREAK => 0
            case BreakT_CR_BREAK => 1
            case BreakT_LN_BREAK => 2
            case BreakT_CRLN_BREAK => 3
        }
    }

    /**
     * The Function is ==
     *
     * @param b of BreakT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func ==(b: BreakT): Bool {
        eq(this, b)
    }

    /**
     * The Function is !=
     *
     * @param b of BreakT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    /*public operator func !=(b: BreakT): Bool {
        ne(this, b)
    }

    /**
     * The Function is toString
     *
     * @return Type of String
     * @since 0.30.4
     */
    public func toString(): String {
        match (this) {
            case BreakT_ANY_BREAK => "BreakT_ANY_BREAK"
            case BreakT_CR_BREAK => "BreakT_CR_BREAK"
            case BreakT_LN_BREAK => "BreakT_LN_BREAK"
            case BreakT_CRLN_BREAK => "BreakT_CRLN_BREAK"
        }
    }*/
}
