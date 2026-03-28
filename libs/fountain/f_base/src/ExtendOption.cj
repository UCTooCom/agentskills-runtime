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

public interface ExtendOption<T> {
    func iterator(): Iterator<T>
    func call<R>(fn: (T) -> R): ?R
    func call<A, R>(right: A, fn: (T, A) -> R): ?R
    func caller<A, R>(right: A, fn: (T, A) -> R): OptionCaller<T, R>
    func caller<R>(fn: (T) -> R): OptionCaller<T, R>

    func toResult<U, E>(): ?Result<U, E>
    func toResult<U, E>(fn: (T) -> U): ?Result<U, E>
    func toResult<U, E>(fn: (T) -> ?U): ?Result<U, E>
    func toResult<U, E>(fn: () -> Exception): Result<U, E>
    func wrapResult<E>(): Result<?T, E>
}

public class OptionIterator<T> <: Iterator<T> {
    // public static let none = OptionIterator<T>()
    public init() {
        this(None<T>)
    }
    public OptionIterator(private let opt: Option<T>) {}
    private var got = false

    public func next(): Option<T> {
        if (got) {
            None<T>
        } else {
            got = true
            opt
        }
    }
}

extend<T> Option<T> <: ExtendOption<T> {
    func map<O>(fn: (T) -> ?O): ?O {
        if (let Some(x) <- this) {
            fn(x)
        } else {
            None<O>
        }
    }
    public func iterator(): Iterator<T> {
        OptionIterator<T>(this)
    }
    public func call<R>(fn: (T) -> R): ?R {
        match (this) {
            case Some(x) => fn(x)
            case _ => None<R>
        }
    }
    public func call<A, R>(right: A, fn: (T, A) -> R): ?R {
        call<R> {left => fn(left, right)}
    }
    public func caller<A, R>(right: A, fn: (T, A) -> R): OptionCaller<T, R> {
        caller<R> {
            left => fn(left, right)
        }
    }
    public func caller<R>(fn: (T) -> R): OptionCaller<T, R> {
        OptionCaller<T, R>(this, fn)
    }
    public func toResult<U, E>(): ?Result<U, E> {
        match (this) {
            case Some(x: U) => Ok(x)
            case Some(_) => None<Result<U, E>>
            case _ => NoResult
        }
    }
    public func toResult<U, E>(fn: (T) -> ?U): ?Result<U, E> {
        match (this) {
            case Some(x) => match (fn(x)) {
                case Some(y) => Ok(y)
                case _ => None<Result<U, E>>
            }
            case _ => NoResult
        }
    }
    public func toResult<U, E>(fn: (T) -> U): ?Result<U, E> {
        match (this) {
            case Some(x) => Ok(fn(x))
            case _ => NoResult
        }
    }
    public func toResult<U, E>(fn: () -> Exception): Result<U, E> {
        match (this) {
            case Some(x: U) => Ok(x)
            case Some(_) => throw fn()
            case _ => NoResult
        }
    }
    public func wrapResult<E>(): Result<?T, E> {
        Ok(this)
    }
}

public class OptionCaller<T, R> {
    public OptionCaller(
        private let option: ?T,
        private let someCallee: (T) -> R,
        private var noneCallee!: ?() -> R = None<() -> R>
    ) {}
    public func none(callee: () -> R) {
        noneCallee = callee
        this
    }
    public func call(): ?R {
        match (option) {
            case Some(x) => someCallee(x)
            case _ =>
                if (let Some(c) <- noneCallee) {
                    c()
                } else {
                    None<R>
                }
        }
    }
    public operator func ()(): ?R {
        call()
    }
}

public interface ExtendAddableOption<T> where T <: Addable<T> {}

extend<T> Option<T> <: ExtendAddableOption<T> where T <: Addable<T> {
    public operator func +(other: T): ?T {
        call<T> {x => x + other}
    }
    public operator func +(other: ?T): ?T {
        call<?T> {x => other + x} ?? None<T>
    }
}

public interface ExtendSubableOption<T> where T <: Subable<T> {}

extend<T> Option<T> <: ExtendSubableOption<T> where T <: Subable<T> {
    public operator func -(other: T): ?T {
        call<T> {x => x - other}
    }
    public operator func -(other: ?T): ?T {
        call<?T> {
            x => match (other) {
                case Some(y) => x - y
                case _ => None<T>
            }
        } ?? None<T>
    }
}

public interface ExtendMulableOption<T> where T <: Mulable<T> {}

extend<T> Option<T> <: ExtendMulableOption<T> where T <: Mulable<T> {
    public operator func *(other: T): ?T {
        call<T> {x => x * other}
    }
    public operator func *(other: ?T): ?T {
        call<?T> {x => other * x} ?? None<T>
    }
}

public interface ExtendDivableOption<T> where T <: Divable<T> {}

extend<T> Option<T> <: ExtendDivableOption<T> where T <: Divable<T> {
    public operator func /(other: T): ?T {
        call<T> {x => x / other}
    }
    public operator func /(other: ?T): ?T {
        call<?T> {
            x => match (other) {
                case Some(y) => x / y
                case _ => None<T>
            }
        } ?? None<T>
    }
}

public interface ExtendModableOption<T> where T <: Modable<T> {}

extend<T> Option<T> <: ExtendModableOption<T> where T <: Modable<T> {
    public operator func %(other: T): ?T {
        call<T> {x => x % other}
    }
    public operator func %(other: ?T): ?T {
        call<?T> {
            x => match (other) {
                case Some(y) => x % y
                case _ => None<T>
            }
        } ?? None<T>
    }
}

public interface ExtendExpableOption<T> where T <: Expable<T> {}

extend<T> Option<T> <: ExtendExpableOption<T> where T <: Expable<T> {
    public operator func **(other: T): ?T {
        call<T> {x => x ** other}
    }
    public operator func **(other: ?T): ?T {
        call<?T> {
            x => match (other) {
                case Some(y) => x ** y
                case _ => None<T>
            }
        } ?? None<T>
    }
}

public interface ExtendBitAndableOption<T> where T <: BitAndable<T> {}

extend<T> Option<T> <: ExtendBitAndableOption<T> where T <: BitAndable<T> {
    public operator func &(other: T): ?T {
        call<T> {x => x & other}
    }
    public operator func &(other: ?T): ?T {
        call<?T> {
            x => match (other) {
                case Some(y) => x & y
                case _ => None<T>
            }
        } ?? None<T>
    }
}

public interface ExtendBitOrableOption<T> where T <: BitOrable<T> {}

extend<T> Option<T> <: ExtendBitOrableOption<T> where T <: BitOrable<T> {
    public operator func |(other: T): ?T {
        call<T> {x => x | other}
    }
    public operator func |(other: ?T): ?T {
        call<?T> {
            x => match (other) {
                case Some(y) => x | y
                case _ => None<T>
            }
        } ?? None<T>
    }
}

public interface ExtendBitXorableOption<T> where T <: BitXorable<T> {}

extend<T> Option<T> <: ExtendBitXorableOption<T> where T <: BitXorable<T> {
    public operator func ^(other: T): ?T {
        call<T> {x => x ^ other}
    }
    public operator func ^(other: ?T): ?T {
        call<?T> {
            x => match (other) {
                case Some(y) => x ^ y
                case _ => None<T>
            }
        } ?? None<T>
    }
}

public interface ExtendBitNotableOption<T> where T <: BitNotable<T> {}

extend<T> Option<T> <: ExtendBitNotableOption<T> where T <: BitNotable<T> {
    public operator func !(): ?T {
        match (this) {
            case Some(x) => !x
            case _ => None<T>
        }
    }
}

public interface ExtendLeftShiftableOption<T> where T <: LeftShiftable<T> {}

extend<T> Option<T> <: ExtendLeftShiftableOption<T> where T <: LeftShiftable<T> {
    public operator func <<(other: T): ?T {
        call<T> {x => x << other}
    }
    public operator func <<(other: ?T): ?T {
        call<?T> {
            x => match (other) {
                case Some(y) => x << y
                case _ => None<T>
            }
        } ?? None<T>
    }
}

public interface ExtendRightShiftableOption<T> where T <: RightShiftable<T> {}

extend<T> Option<T> <: ExtendRightShiftableOption<T> where T <: RightShiftable<T> {
    public operator func >>(other: T): ?T {
        call<T> {x => x >> other}
    }
    public operator func >>(other: ?T): ?T {
        call<?T> {
            x => match (other) {
                case Some(y) => x >> y
                case _ => None<T>
            }
        } ?? None<T>
    }
}
