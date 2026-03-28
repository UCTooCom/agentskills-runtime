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
package f_io

/**
 * 本包仅支持linux
 */
/*
#define PROT_READ   0x1
#define PROT_WRITE  0x2
#define PROT_EXEC   0x4
#define PROT_NONE   0x0
#define MAP_SHARED  0x01
#define MAP_PRIVATE 0x02
#define MAP_FIXED   0x10
#define MAP_ANONYMOUS 0x20
MS_SYNC
MS_ASYNC
MS_INVALIDATE

#define MS_ASYNC        0x0001          /* sync memory asynchronously */
#define MS_INVALIDATE   0x0002          /* invalidate mappings & caches */
#define MS_SYNC         0x0004          /* synchronous memory sync */

  void *mmap(void *start, size_t length, int prot, int flags, int fd, off_t offset);
    int munmap(void *start, size_t length);
    int msync(void *addr, size_t length, int flags);

 */
@When[os == "Linux"]
private const PROT_READ: IntNative = 0x1
@When[os == "Linux"]
private const PROT_WRITE: IntNative = 0x2
@When[os == "Linux"]
private const PROT_EXEC: IntNative = 0x4
@When[os == "Linux"]
private const PROT_NONE: IntNative = 0x0
@When[os == "Linux"]
private const MAP_SHARED: IntNative = 0x01
@When[os == "Linux"]
private const MAP_PRIVATE: IntNative = 0x02
// @When[os == "Linux"]
//private const MAP_FIXED: IntNative = 0x10
@When[os == "Linux"]
private const MAP_ANONYMOUS: IntNative = 0x20
@When[os == "Linux"]
private const MS_SYNC: IntNative = 0x0004
@When[os == "Linux"]
private const MS_ASYNC: IntNative = 0x001
@When[os == "Linux"]
private const MS_INVALIDATE: IntNative = 0x002

@When[os == "Linux"]
foreign {
    func mmap(start: CPointer<Unit>, length: UIntNative, prot: IntNative, flags: IntNative, fd: IntNative,
        offset: IntNative): CPointer<Unit>

    func munmap(start: CPointer<Unit>, length: UIntNative): IntNative

    func msync(addr: CPointer<Unit>, length: UIntNative, flags: IntNative): IntNative
}
@When[os == "Linux"]
public enum MMapProt {
    | Read
    | Write
    | Exec
    | None

    public prop value: IntNative {
        get() {
            match (this) {
                case Read => PROT_READ
                case Write => PROT_WRITE
                case Exec => PROT_EXEC
                case None => PROT_NONE
            }
        }
    }
    operator func &(prot: IntNative): Bool {
        (this.value & prot) != 0
    }
    public operator func |(other: MMapProt): Array<MMapProt> {
        [this, other]
    }
    public operator func |(others: Array<MMapProt>): Array<MMapProt> {
        Array<MMapProt>(others.size + 1) {
            i => if (i == 0) {
                this
            } else {
                others[i - 1]
            }
        }
    }
}
@When[os == "Linux"]
public interface MMapProtArray {
    operator func |(other: MMapProt): Array<MMapProt>
    operator func |(others: Array<MMapProt>): Array<MMapProt>
    func combine(): IntNative
}
@When[os == "Linux"]
extend Array<MMapProt> <: MMapProtArray {
    public operator func |(other: MMapProt): Array<MMapProt> {
        Array<MMapProt>(this.size + 1) {
            i => if (i < this.size) {
                this[i]
            } else {
                other
            }
        }
    }
    public operator func |(others: Array<MMapProt>): Array<MMapProt> {
        Array<MMapProt>(this.size + others.size) {
            i => if (i < this.size) {
                this[i]
            } else {
                others[i - this.size]
            }
        }
    }
    public func combine(): IntNative {
        var res: IntNative = 0
        for (prot in this) {
            res |= prot.value
        }
        return res
    }
}
@When[os == "Linux"]
public enum MMapFlag <: Equatable<MMapFlag> & Equatable<IntNative> {
    | Shared
    | Private
    // | Fixed
    | Anonymous

    public prop value: IntNative {
        get() {
            match (this) {
                case Shared => MAP_SHARED
                case Private => MAP_PRIVATE
                // case Fixed => MAP_FIXED
                case Anonymous => MAP_ANONYMOUS
            }
        }
    }
    public operator func ==(other: MMapFlag): Bool {
        this == other.value
    }
    public operator func ==(other: IntNative): Bool {
        this.value == other
    }
    public prop isShared: Bool {
        get() {
            this == Shared
        }
    }
    public prop isPrivate: Bool {
        get() {
            this == Private
        }
    }
    public prop isAnonymous: Bool {
        get() {
            this == Anonymous
        }
    }
}
@When[os == "Linux"]
public enum MSyncFlag {
    | Sync
    | Async
    | Invalidate

    public prop value: IntNative {
        get() {
            match (this) {
                case Sync => MS_SYNC
                case Async => MS_ASYNC
                case Invalidate => MS_INVALIDATE
            }
        }
    }
}

/**
 * 默认映射字节数
 */
@When[os == "Linux"]
public const DEFAULT_MMAP_BYTES = 1 * 1024 * 1024 * 1024