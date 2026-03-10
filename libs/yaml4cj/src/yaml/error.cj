/**
 * @file
 * This file is baout TypeError
 */

package yaml4cj.yaml

/**
 * The class is TypeError inherited from Exception
 * @author changeden
 * @since 0.30.4
 */
class TypeError <: Exception {
    var errors: Array<String>

    /**
     * The Function is init constructor
     *
     * @param errors of Array<String>
     * @since 0.30.4
     */
    public init(errors: Array<String>) {
        super("yaml: unmarshal errors:\n ${String.join(errors,delimiter:"\r\n")}")
        this.errors = errors
    }

    /**
     * The Function is toString
     *
     * @return Type of String
     * @since 0.30.4
     */
    /*public override func toString(): String {
        "yaml: unmarshal errors:\n ${String.join(errors,delimiter:"\r\n")}"
    }*/
}
