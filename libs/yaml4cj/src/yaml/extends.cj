/**
 * @file
 * This file is baout extends.
 */

package yaml4cj.yaml

extend ArrayList<UInt8> {
    /**
     * The Function is fill
     *
     * @param length of Int64, and the Default value is (this.capacity()-this.size)
     *
     * @return Type of Unit
     * @since 0.30.4
     */
    func fill(length!: Int64 = (this.capacity - this.size)): Unit {
        if (this.size == this.capacity || length <= 0) {
            return
        }
        let start = this.size
        let len = min(this.capacity - start, length)
        for (_ in 0..len) {
            this.add(0)
        }
    }
}
