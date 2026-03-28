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

public interface Negativable<T> where T <: Negativable<T> {
    operator func -(): T
}

public interface Addable<T> where T <: Addable<T> {
    operator func +(right: T): T
}

public interface Subable<T> where T <: Subable<T> {
    operator func -(right: T): T
}

public interface Mulable<T> where T <: Mulable<T> {
    operator func *(right: T): T
}

public interface Divable<T> where T <: Divable<T> {
    operator func /(right: T): T
}

public interface Modable<T> where T <: Modable<T> {
    operator func %(right: T): T
}

public interface Expable<T> where T <: Expable<T> {
    operator func **(right: T): T
}

public interface Cmpable<T> where T <: Cmpable<T> {
    operator func >(right: T): Bool
    operator func <(right: T): Bool
    operator func >=(right: T): Bool
    operator func <=(right: T): Bool
}

public interface Eqable<T> where T <: Eqable<T> {
    operator func ==(right: T): Bool
    operator func !=(right: T): Bool
}

public interface BitAndable<T> where T <: BitAndable<T> {
    operator func &(right: T): T
}

public interface BitOrable<T> where T <: BitOrable<T> {
    operator func |(right: T): T
}

public interface BitXorable<T> where T <: BitXorable<T> {
    operator func ^(right: T): T
}

public interface BitNotable<T> where T <: BitNotable<T> {
    operator func !(): T
}

public interface LeftShiftable<T> where T <: LeftShiftable<T> {
    operator func <<(right: T): T
}

public interface RightShiftable<T> where T <: RightShiftable<T> {
    operator func >>(right: T): T
}
