/**
 * @file
 * This file is baout yaml tag directive.
 */

package yaml4cj.yaml

/**
 * The class is TagDirectiveT
 * @author changeden
 * @since 0.30.4
 */
class TagDirectiveT {
    public var handle: Array<UInt8>
    public var prefix: Array<UInt8>

    /**
     * The Function is init constructor
     *
     * @since 0.30.4
     */
    public init() {
        this(Array<UInt8>(), Array<UInt8>())
    }

    /**
     * The Function is init constructor
     *
     * @param handle of Array<UInt8>
     * @param prefix of Array<UInt8>
     * @since 0.30.4
     */
    public init(handle: Array<UInt8>, prefix: Array<UInt8>) {
        this.handle = handle
        this.prefix = prefix
    }
}
