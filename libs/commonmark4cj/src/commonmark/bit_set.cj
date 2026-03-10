/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */

package commonmark4cj.commonmark

/*
 * simple bitmap
 */
public class BitSet {
    static let ARRSIZE = 16
    var maxIndex: Int64
    let words: Array<UInt64> = Array(ARRSIZE, repeat: 0)
    let wordsMap: HashMap<Int64, UInt64> = HashMap()

    public init(size: Int64) {
        if (size < 0) {
            throw NegativeArraySizeException("size < 0: ${size}")
        }
        this.maxIndex = size - 1
    }

    func getWord(wordIndex: Int64): UInt64 {
        return if (wordIndex < ARRSIZE) {
            words[wordIndex]
        } else {
            wordsMap.get(wordIndex) ?? 0
        }
    }

    func setWord(wordIndex: Int64, word: UInt64): Unit {
        if (wordIndex < ARRSIZE) {
            words[wordIndex] = word
        } else {
            wordsMap.add(wordIndex, word)
        }
    }

    func autoGrow(wordIndex: Int64): Bool {
        return if (wordIndex > this.maxIndex) {
            this.maxIndex = wordIndex
            true
        } else {
            false
        }
    }

    func calcIndex(index: Int64): (Int64, Int64) {
        if (index < 0) {
            throw IndexOutOfBoundsException("index < 0: ${index}")
        }
        (index >> 6, index & 63)
    }

    /*
     * get index value
     */
    public func get(index: Int64): Bool {
        let (wordIndex, wordBitIndex) = calcIndex(index)
        let word = getWord(wordIndex)
        if (word == 0) {
            return false
        }
        return (word >> wordBitIndex & 1) == 1
    }

    /*
     * set index to true
     */
    public func set(index: Int64): Unit {
        this.autoGrow(index)
        let (wordIndex, wordBitIndex) = calcIndex(index)
        let word = getWord(wordIndex) | (1 << wordBitIndex)
        setWord(wordIndex, word)
    }

    /*
     * or
     */
    public func or(set: BitSet): Unit {
        for (i in 0..ARRSIZE) {
            this.words[i] |= set.words[i]
        }
        for ((wordIndex, word) in set.wordsMap) {
            let newWord = this.getWord(wordIndex) | word
            this.setWord(wordIndex, newWord)
        }
    }

    public func clone(): BitSet {
        let newSet = BitSet(this.maxIndex + 1)
        for (i in 0..ARRSIZE) {
            newSet.words[i] = this.words[i]
        }
        for ((wordIndex, word) in this.wordsMap) {
            newSet.setWord(wordIndex, word)
        }
        return newSet
    }
}
