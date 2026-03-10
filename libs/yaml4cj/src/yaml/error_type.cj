/**
 * @file
 * This file is about yaml error type.
 */

package yaml4cj.yaml

enum ErrorTypeT {
    | ErrorTypeT_NO_ERROR
    | ErrorTypeT_MEMORY_ERROR
    | ErrorTypeT_READER_ERROR
    | ErrorTypeT_SCANNER_ERROR
    | ErrorTypeT_PARSER_ERROR
    | ErrorTypeT_COMPOSER_ERROR
    | ErrorTypeT_WRITER_ERROR
    | ErrorTypeT_EMITTER_ERROR

    /**
     * The Function is getValues
     *
     * @return Type of Array<ErrorTypeT>
     * @since 0.30.4
     */
    public static func getValues(): Array<ErrorTypeT> {
        [
            ErrorTypeT_NO_ERROR,
            ErrorTypeT_MEMORY_ERROR,
            ErrorTypeT_READER_ERROR,
            ErrorTypeT_SCANNER_ERROR,
            ErrorTypeT_PARSER_ERROR,
            ErrorTypeT_COMPOSER_ERROR,
            ErrorTypeT_WRITER_ERROR,
            ErrorTypeT_EMITTER_ERROR
        ]
    }

    /**
     * The Function is getCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    func getCode(): Int64 {
        match (this) {
            case ErrorTypeT_NO_ERROR => 0
            case ErrorTypeT_MEMORY_ERROR => 1
            case ErrorTypeT_READER_ERROR => 2
            case ErrorTypeT_SCANNER_ERROR => 3
            case ErrorTypeT_PARSER_ERROR => 4
            case ErrorTypeT_COMPOSER_ERROR => 5
            case ErrorTypeT_WRITER_ERROR => 6
            case ErrorTypeT_EMITTER_ERROR => 7
        }
    }

    /**
     * The Function is hashCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    /*public func hashCode(): Int64 {
        genHashCode([getCode()], name: "ErrorTypeT")
    }*/

    /**
     * The Function is ==
     *
     * @param b of ErrorTypeT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func ==(b: ErrorTypeT): Bool {
        eq(getCode(), b.getCode())
    }

    /**
     * The Function is !=
     *
     * @param b of ErrorTypeT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func !=(b: ErrorTypeT): Bool {
        ne(getCode(), b.getCode())
    }
}

/**
 * The class is YamlError inherited from Exception & ToString
 * @author changeden
 * @since 0.30.4
 */
class YamlError <: Exception & ToString {
    var err: Exception

    /**
     * The Function is init constructor
     *
     * @param err of Exception
     * @since 0.30.4
     */
    public init(err: Exception) {
        this.err = err
    }

    /**
     * The Function is init constructor
     *
     * @param err of String
     * @since 0.30.4
     */
    public init(err: String) {
        this(Exception(err))
    }

    /**
     * The Function is getMessage
     *
     * @since 0.30.4
     */
    /*func getMessage() {
        this.err.message
    }*/

    /**
     * The Function is toString
     *
     * @return Type of String
     * @since 0.30.4
     */
    public override func toString(): String {
        this.err.toString()
    }
}
