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
package f_base

public interface ExtendRune {
    operator func -(c: Rune): UInt32
    operator func +(n: Int8): Rune
    operator func -(n: Int8): Rune
    operator func +(n: UInt8): Rune
    operator func -(n: UInt8): Rune
    operator func +(n: Int16): Rune
    operator func -(n: Int16): Rune
    operator func +(n: UInt16): Rune
    operator func -(n: UInt16): Rune
    operator func +(n: Int32): Rune
    operator func -(n: Int32): Rune
    operator func +(n: UInt32): Rune
    operator func -(n: UInt32): Rune
    operator func +(n: Int64): Rune
    operator func -(n: Int64): Rune
    operator func +(n: UInt64): Rune
    operator func -(n: UInt64): Rune
}

extend Rune <: ExtendRune {
    public operator func +(n: Int8): Rune {
        if (n > 0) {
            this + UInt32(n)
        } else {
            this - UInt32(-n)
        }
    }
    public operator func -(n: Int8): Rune {
        if (n > 0) {
            this - UInt32(n)
        } else {
            this + UInt32(-n)
        }
    }
    public operator func +(n: UInt8): Rune {
        this + UInt32(n)
    }
    public operator func -(n: UInt8): Rune {
        this - UInt32(n)
    }
    public operator func +(n: Int16): Rune {
        if (n > 0) {
            this + UInt32(n)
        } else {
            this - UInt32(-n)
        }
    }
    public operator func -(n: Int16): Rune {
        if (n > 0) {
            this - UInt32(n)
        } else {
            this + UInt32(-n)
        }
    }
    public operator func +(n: UInt16): Rune {
        this + UInt32(n)
    }
    public operator func -(n: UInt16): Rune {
        this - UInt32(n)
    }
    public operator func +(n: UInt32): Rune {
        Rune(UInt32(this) + n)
    }
    public operator func -(n: UInt32): Rune {
        Rune(UInt32(this) - n)
    }
    public operator func -(c: Rune): UInt32 {
        UInt32(this) - UInt32(c)
    }
    public operator func +(n: Int64): Rune {
        if (n > 0) {
            this + UInt32(n)
        } else {
            this - UInt32(-n)
        }
    }
    public operator func -(n: Int64): Rune {
        if (n > 0) {
            this - UInt32(n)
        } else {
            this + UInt32(-n)
        }
    }
    public operator func +(n: UInt64): Rune {
        this + UInt32(n)
    }
    public operator func -(n: UInt64): Rune {
        this - UInt32(n)
    }
    public operator func +(n: Int32): Rune {
        if (n > 0) {
            this + UInt32(n)
        } else {
            this - UInt32(-n)
        }
    }
    public operator func -(n: Int32): Rune {
        if (n > 0) {
            this - UInt32(n)
        } else {
            this + UInt32(-n)
        }
    }
}
