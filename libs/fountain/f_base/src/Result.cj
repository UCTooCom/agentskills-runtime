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

public enum Result<T, E> {
    | Ok
    | Ok(T)
    | Err
    | Err(E)
    | NoResult

    public prop isOk: Bool {
        get() {
            match (this) {
                case Ok => true
                case Ok(_) => true
                case _ => false
            }
        }
    }
    public prop isErr: Bool {
        get() {
            match (this) {
                case Err => true
                case Err(_) => true
                case _ => false
            }
        }
    }
    public prop isNoResult: Bool {
        get() {
            match (this) {
                case NoResult => true
                case _ => false
            }
        }
    }
    public prop withE: Bool {
        get() {
            match (this) {
                case Err(_) => true
                case _ => false
            }
        }
    }
    public prop withValue: Bool {
        get() {
            match (this) {
                case Ok(_) => true
                case _ => false
            }
        }
    }
    public func result(): ?T {
        match (this) {
            case Ok(v) => v
            case _ => None
        }
    }
    public func err(): ?E {
        match (this) {
            case Err(e) => e
            case _ => None
        }
    }
    public func mapValue<U>(f: (T) -> Result<U, E>): Result<U, E> {
        match (this) {
            case Ok => Ok
            case Ok(v) => try {
                f(v)
            } catch (e: Exception) {
                match (e) {
                    case x: E => Err(x)
                    case _ => throw e
                }
            }
            case Err => Err
            case Err(e) => Err(e)
            case NoResult => NoResult
        }
    }
    public func mapError<U>(f: (E) -> Result<U, E>): Result<U, E> {
        match (this) {
            case Ok => Ok
            case Ok(v: U) => Ok(v)
            case Ok(_) => Ok
            case Err => Err
            case NoResult => NoResult
            case Err(e) => f(e)
        }
    }
    /**
     * 忽略数据和错误信息，只返回Ok Err NoResult
     */
    public func ignore(): Result<T, E> {
        match (this) {
            case Ok => Ok
            case Ok(_) => Ok
            case Err => Err
            case NoResult => NoResult
            case Err(_) => Err
        }
    }
    public func filterValue(predicate: (T) -> Bool): Result<T, E> {
        match (this) {
            case Ok(v) where predicate(v) => this
            case _ => NoResult
        }
    }
    public func filterError(predicate: (E) -> Bool): Result<T, E> {
        match (this) {
            case Err(e) where predicate(e) => this
            case _ => NoResult
        }
    }
    public func filterOk() {
        if (isOk) {
            this
        } else {
            NoResult
        }
    }
    public func filterErr() {
        if (isErr) {
            this
        } else {
            NoResult
        }
    }
    public func filterWithE() {
        if (withE) {
            this
        } else {
            NoResult
        }
    }
    public func filterWithValue() {
        if (withValue) {
            this
        } else {
            NoResult
        }
    }
    public func filter() {
        ResultFilter<T, E>(this)
    }
    public func flatten<U>(): Result<U, E> {
        match (this) {
            case Ok(v: Result<U, E>) => v
            case Ok(_) => Ok
            case Ok => Ok
            case Err => Err
            case Err(e) => Err(e)
            case NoResult => NoResult
        }
    }
    public func transpose<U>(): ?Result<U, E> {
        match (this) {
            case Ok(x: ?U) => match (x) {
                case Some(y) => Ok(y)
                case _ => NoResult
            }
            case Ok => Ok
            case Err => Err
            case Err(e) => Err(e)
            case NoResult => NoResult
            case Ok(_) => Ok
        }
    }
    public func orDefault(default: T): T {
        match (this) {
            case Ok(x) => x
            case _ => default
        }
    }
    public func orElse(fn: () -> T): T {
        match (this) {
            case Ok(x) => x
            case _ => fn()
        }
    }
    public func orElse(fn: () -> ?T): ?T {
        match (this) {
            case Ok(x) => x
            case _ => fn()
        }
    }
    public func mapper<U>(): ResultMapper<T, U, E> {
        ResultMapper<T, U, E>(this)
    }
}

public class ResultFilter<T, E> {
    ResultFilter(private let origin: Result<T, E>) {}
    private var filterOk_: ?Bool = None
    private var filterOkFn_: ?(T) -> Bool = None
    private var filterErr_: ?Bool = None
    private var filterErrFn_: ?(E) -> Bool = None
    private var filterWithValue_: ?Bool = None
    private var filterWithE_: ?Bool = None
    public func filterOk(predicate: (T) -> Bool) {
        filterOkFn_ = predicate
        this
    }
    public func filterOk() {
        filterOk_ = true
        this
    }
    public func filterErr(predicate: (E) -> Bool) {
        filterErrFn_ = predicate
        this
    }
    public func filterErr() {
        filterErr_ = true
        this
    }
    public func filterWithValue() {
        filterWithValue_ = true
        this
    }
    public func filterWithE() {
        filterWithE_ = true
        this
    }
    public func filter(): Result<T, E> {
        match (origin) {
            case Ok =>
                if (let Some(ok) <- filterOk_ && ok) {
                    origin
                } else {
                    NoResult
                }
            case Ok(v) =>
                if (let Some(ok) <- filterOkFn_) {
                    if (ok(v)) {
                        origin
                    } else if (let Some(ok) <- filterWithValue_ && ok) {
                        origin
                    } else {
                        NoResult
                    }
                } else if (let Some(ok) <- filterOk_ && ok) {
                    origin
                } else if (let Some(ok) <- filterWithValue_ && ok) {
                    origin
                } else {
                    NoResult
                }
            case Err =>
                if (let Some(err) <- filterErr_ && err) {
                    origin
                } else {
                    NoResult
                }
            case Err(e) =>
                if (let Some(err) <- filterErrFn_) {
                    if (err(e)) {
                        origin
                    } else if (let Some(err) <- filterWithE_ && err) {
                        origin
                    } else {
                        NoResult
                    }
                } else if (let Some(err) <- filterErr_ && err) {
                    origin
                } else if (let Some(err) <- filterWithE_ && err) {
                    origin
                } else {
                    NoResult
                }
            case NoResult => origin
        }
    }
}

public class ResultMapper<T, U, E> {
    ResultMapper(private let origin: Result<T, E>) {}
    private var resultMap = {_: T => Result<U, E>.Ok}
    private var okMap = {=> Result<U, E>.Ok}
    private var withErrorMap = {e: E => Result<U, E>.Err(e)}
    private var errorMap = {=> Result<U, E>.Err}
    private var noneMap = {=> Result<U, E>.NoResult}
    public func result(f: (T) -> Result<U, E>): ResultMapper<T, U, E> {
        resultMap = f
        this
    }
    public func ok(f: () -> Result<U, E>): ResultMapper<T, U, E> {
        okMap = f
        this
    }
    public func error(f: (E) -> Result<U, E>): ResultMapper<T, U, E> {
        withErrorMap = f
        this
    }
    public func error(f: () -> Result<U, E>): ResultMapper<T, U, E> {
        errorMap = f
        this
    }
    public func none(f: () -> Result<U, E>): ResultMapper<T, U, E> {
        noneMap = f
        this
    }
    public func map(): Result<U, E> {
        match (origin) {
            case Ok => okMap()
            case Ok(v) => resultMap(v)
            case Err => errorMap()
            case Err(e) => withErrorMap(e)
            case NoResult => noneMap()
        }
    }
}
