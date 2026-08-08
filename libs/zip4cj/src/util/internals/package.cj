/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
protected package zip4cj.util.internals

import std.collection.ArrayList

public interface UnsignedRightShift<T> {
    operator func [](right: Int64): T
}

extend Int64 <: UnsignedRightShift<Int64> {
    @OverflowWrapping
    public operator func [](right: Int64): Int64 {
        return Int64(UInt64(this) >> (right & 63) & ((1 << (64 - (right & 63))) - 1))
    }
}

extend Int32 <: UnsignedRightShift<Int32> {
    @OverflowWrapping
    public operator func [](right: Int64): Int32 {
        return Int32(UInt64(this) >> (right & 31) & ((1 << (32 - (right & 31))) - 1))
    }
}

public func fill<T>(a: Array<T>, val: T) {
    for (i in 0..a.size) {
        a[i] = val
    }
}

public func ArrayCopy<T>(src: Array<T>, srcPos: Int64, dest: Array<T>, destPos: Int64, length: Int64) {
    if ((srcPos | destPos | length) < 0) {
        throw IndexOutOfBoundsException()
    }
    if (destPos > dest.size) {
        throw IndexOutOfBoundsException()
    }
    src.copyTo(dest, srcPos, destPos, length)
}

public func ListRmove<T>(arr: ArrayList<T>, item: T): Unit where T <: Equatable<T> {
    for (i in 0..arr.size where arr[i] == item) {
        arr.remove(at: i)
        break
    }
}
 