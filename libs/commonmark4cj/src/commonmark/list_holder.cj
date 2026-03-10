/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2024. All rights reserved.
 */

package commonmark4cj.commonmark

public abstract class ListHolder {
    private static let INDENT_DEFAULT: String = "   "
    private static let INDENT_EMPTY: String = ""

    private let parent: ?ListHolder
    private let indent: String

    init(parent: ?ListHolder) {
        this.parent = parent

        if (parent.isSome()) {
            indent = parent().indent + INDENT_DEFAULT
        } else {
            indent = INDENT_EMPTY
        }
    }

    public func getParent(): ?ListHolder {
        return parent
    }

    public func getIndent(): String {
        return indent
    }
}

class BulletListHolder <: ListHolder {
    private let marker: Rune

    public init(parent: ?ListHolder, list: BulletList) {
        super(parent)
        marker = list.getBulletMarker()
    }

    public func getMarker(): Rune {
        return marker
    }
}

class OrderedListHolder <: ListHolder {
    private let delimiter: Rune
    private var counter: Int

    public init(parent: ?ListHolder, list: OrderedList) {
        super(parent)
        delimiter = list.getDelimiter()
        counter = list.getStartNumber()
    }

    public func getDelimiter(): Rune {
        return delimiter
    }

    public func getCounter(): Int {
        return counter
    }

    public func increaseCounter(): Unit {
        counter++
    }
}
