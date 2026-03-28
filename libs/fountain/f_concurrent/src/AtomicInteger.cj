/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_concurrent

public interface ExtendAtomicInt8 {
    func fetchIncr(): Int8
    func fetchDecr(): Int8
    func incrFetch(): Int8
    func decrFetch(): Int8
    func addFetch(val: Int8): Int8
    func subFetch(val: Int8): Int8
    func andFetch(val: Int8): Int8
    func orFetch(val: Int8): Int8
    func xorFetch(val: Int8): Int8
}

extend AtomicInt8 <: ExtendAtomicInt8 {
    public func fetchIncr(): Int8 {
        fetchAdd(Int8.one)
    }
    public func fetchDecr(): Int8 {
        fetchSub(Int8.one)
    }
    public func incrFetch(): Int8 {
        addFetch(Int8.one)
    }
    public func decrFetch(): Int8 {
        subFetch(Int8.one)
    }
    public func addFetch(val: Int8): Int8 {
        fetchAdd(val) + val
    }
    public func subFetch(val: Int8): Int8 {
        fetchSub(val) - val
    }
    public func andFetch(val: Int8): Int8 {
        fetchAnd(val) & val
    }
    public func orFetch(val: Int8): Int8 {
        fetchOr(val) | val
    }
    public func xorFetch(val: Int8): Int8 {
        fetchXor(val) ^ val
    }
}

public interface ExtendAtomicUInt8 {
    func fetchIncr(): UInt8
    func fetchDecr(): UInt8
    func incrFetch(): UInt8
    func decrFetch(): UInt8

    func addFetch(val: UInt8): UInt8
    func subFetch(val: UInt8): UInt8
    func andFetch(val: UInt8): UInt8
    func orFetch(val: UInt8): UInt8
    func xorFetch(val: UInt8): UInt8
}

extend AtomicUInt8 <: ExtendAtomicUInt8 {
    public func fetchIncr(): UInt8 {
        fetchAdd(UInt8.one)
    }
    public func fetchDecr(): UInt8 {
        fetchSub(UInt8.one)
    }
    public func incrFetch(): UInt8 {
        addFetch(UInt8.one)
    }
    public func decrFetch(): UInt8 {
        subFetch(UInt8.one)
    }
    public func addFetch(val: UInt8): UInt8 {
        fetchAdd(val) + val
    }
    public func subFetch(val: UInt8): UInt8 {
        fetchSub(val) - val
    }
    public func andFetch(val: UInt8): UInt8 {
        fetchAnd(val) & val
    }
    public func orFetch(val: UInt8): UInt8 {
        fetchOr(val) | val
    }
    public func xorFetch(val: UInt8): UInt8 {
        fetchXor(val) ^ val
    }
}

public interface ExtendAtomicInt16 {
    func fetchIncr(): Int16
    func fetchDecr(): Int16
    func incrFetch(): Int16
    func decrFetch(): Int16

    func addFetch(val: Int16): Int16
    func subFetch(val: Int16): Int16
    func andFetch(val: Int16): Int16
    func orFetch(val: Int16): Int16
    func xorFetch(val: Int16): Int16
}

extend AtomicInt16 <: ExtendAtomicInt16 {
    public func fetchIncr(): Int16 {
        fetchAdd(Int16.one)
    }
    public func fetchDecr(): Int16 {
        fetchSub(Int16.one)
    }
    public func incrFetch(): Int16 {
        addFetch(Int16.one)
    }
    public func decrFetch(): Int16 {
        subFetch(Int16.one)
    }
    public func addFetch(val: Int16): Int16 {
        fetchAdd(val) + val
    }
    public func subFetch(val: Int16): Int16 {
        fetchSub(val) - val
    }
    public func andFetch(val: Int16): Int16 {
        fetchAnd(val) & val
    }
    public func orFetch(val: Int16): Int16 {
        fetchOr(val) | val
    }
    public func xorFetch(val: Int16): Int16 {
        fetchXor(val) ^ val
    }
}

public interface ExtendAtomicUInt16 {
    func fetchIncr(): UInt16
    func fetchDecr(): UInt16
    func incrFetch(): UInt16
    func decrFetch(): UInt16
    func addFetch(val: UInt16): UInt16
    func subFetch(val: UInt16): UInt16
    func andFetch(val: UInt16): UInt16
    func orFetch(val: UInt16): UInt16
    func xorFetch(val: UInt16): UInt16
}

extend AtomicUInt16 <: ExtendAtomicUInt16 {
    public func fetchIncr(): UInt16 {
        fetchAdd(UInt16.one)
    }
    public func fetchDecr(): UInt16 {
        fetchSub(UInt16.one)
    }
    public func incrFetch(): UInt16 {
        addFetch(UInt16.one)
    }
    public func decrFetch(): UInt16 {
        subFetch(UInt16.one)
    }
    public func addFetch(val: UInt16): UInt16 {
        fetchAdd(val) + val
    }
    public func subFetch(val: UInt16): UInt16 {
        fetchSub(val) - val
    }
    public func andFetch(val: UInt16): UInt16 {
        fetchAnd(val) & val
    }
    public func orFetch(val: UInt16): UInt16 {
        fetchOr(val) | val
    }
    public func xorFetch(val: UInt16): UInt16 {
        fetchXor(val) ^ val
    }
}

public interface ExtendAtomicInt32 {
    func fetchIncr(): Int32
    func fetchDecr(): Int32
    func incrFetch(): Int32
    func decrFetch(): Int32
    func addFetch(val: Int32): Int32
    func subFetch(val: Int32): Int32
    func andFetch(val: Int32): Int32
    func orFetch(val: Int32): Int32
    func xorFetch(val: Int32): Int32
}

extend AtomicInt32 <: ExtendAtomicInt32 {
    public func fetchIncr(): Int32 {
        fetchAdd(Int32.one)
    }
    public func fetchDecr(): Int32 {
        fetchSub(Int32.one)
    }
    public func incrFetch(): Int32 {
        addFetch(Int32.one)
    }
    public func decrFetch(): Int32 {
        subFetch(Int32.one)
    }
    public func addFetch(val: Int32): Int32 {
        fetchAdd(val) + val
    }
    public func subFetch(val: Int32): Int32 {
        fetchSub(val) - val
    }
    public func andFetch(val: Int32): Int32 {
        fetchAnd(val) & val
    }
    public func orFetch(val: Int32): Int32 {
        fetchOr(val) | val
    }
    public func xorFetch(val: Int32): Int32 {
        fetchXor(val) ^ val
    }
}

public interface ExtendAtomicUInt32 {
    func fetchIncr(): UInt32
    func fetchDecr(): UInt32
    func incrFetch(): UInt32
    func decrFetch(): UInt32
    func addFetch(val: UInt32): UInt32
    func subFetch(val: UInt32): UInt32
    func andFetch(val: UInt32): UInt32
    func orFetch(val: UInt32): UInt32
    func xorFetch(val: UInt32): UInt32
}

extend AtomicUInt32 <: ExtendAtomicUInt32 {
    public func fetchIncr(): UInt32 {
        fetchAdd(UInt32.one)
    }
    public func fetchDecr(): UInt32 {
        fetchSub(UInt32.one)
    }
    public func incrFetch(): UInt32 {
        addFetch(UInt32.one)
    }
    public func decrFetch(): UInt32 {
        subFetch(UInt32.one)
    }
    public func addFetch(val: UInt32): UInt32 {
        fetchAdd(val) + val
    }
    public func subFetch(val: UInt32): UInt32 {
        fetchSub(val) - val
    }
    public func andFetch(val: UInt32): UInt32 {
        fetchAnd(val) & val
    }
    public func orFetch(val: UInt32): UInt32 {
        fetchOr(val) | val
    }
    public func xorFetch(val: UInt32): UInt32 {
        fetchXor(val) ^ val
    }
}

public interface ExtendAtomicInt64 {
    func fetchIncr(): Int64
    func fetchDecr(): Int64
    func incrFetch(): Int64
    func decrFetch(): Int64
    func addFetch(val: Int64): Int64
    func subFetch(val: Int64): Int64
    func andFetch(val: Int64): Int64
    func orFetch(val: Int64): Int64
    func xorFetch(val: Int64): Int64
}

extend AtomicInt64 <: ExtendAtomicInt64 {
    public func fetchIncr(): Int64 {
        fetchAdd(Int64.one)
    }
    public func fetchDecr(): Int64 {
        fetchSub(Int64.one)
    }
    public func incrFetch(): Int64 {
        addFetch(Int64.one)
    }
    public func decrFetch(): Int64 {
        subFetch(Int64.one)
    }
    public func addFetch(val: Int64): Int64 {
        fetchAdd(val) + val
    }
    public func subFetch(val: Int64): Int64 {
        fetchSub(val) - val
    }
    public func andFetch(val: Int64): Int64 {
        fetchAnd(val) & val
    }
    public func orFetch(val: Int64): Int64 {
        fetchOr(val) | val
    }
    public func xorFetch(val: Int64): Int64 {
        fetchXor(val) ^ val
    }
}

public interface ExtendAtomicUInt64 {
    func fetchIncr(): UInt64
    func fetchDecr(): UInt64
    func incrFetch(): UInt64
    func decrFetch(): UInt64
    func addFetch(val: UInt64): UInt64
    func subFetch(val: UInt64): UInt64
    func andFetch(val: UInt64): UInt64
    func orFetch(val: UInt64): UInt64
    func xorFetch(val: UInt64): UInt64
}

extend AtomicUInt64 <: ExtendAtomicUInt64 {
    public func fetchIncr(): UInt64 {
        fetchAdd(UInt64.one)
    }
    public func fetchDecr(): UInt64 {
        fetchSub(UInt64.one)
    }
    public func incrFetch(): UInt64 {
        addFetch(UInt64.one)
    }
    public func decrFetch(): UInt64 {
        subFetch(UInt64.one)
    }
    public func addFetch(val: UInt64): UInt64 {
        fetchAdd(val) + val
    }
    public func subFetch(val: UInt64): UInt64 {
        fetchSub(val) - val
    }
    public func andFetch(val: UInt64): UInt64 {
        fetchAnd(val) & val
    }
    public func orFetch(val: UInt64): UInt64 {
        fetchOr(val) | val
    }
    public func xorFetch(val: UInt64): UInt64 {
        fetchXor(val) ^ val
    }
}
