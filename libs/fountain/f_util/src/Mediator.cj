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
package f_util

import std.collection.HashMap

public class Mediator<N, C, A, R> where C <: Colleague<N, A, R>, A <: ColleagueArgument<N>, N <: Hashable & Equatable<N> {
    private let colleagues = HashMap<N, Colleague<N, A, R>>()
    public func register(colleague: Colleague<N, A, R>) {
        colleagues[colleague.name] = colleague
    }
    public func execute(arg: A): R {
        colleagues[arg.name].execute(arg)
    }
}

public interface Colleague<N, A, R> where A <: ColleagueArgument<N>, N <: Hashable & Equatable<N> {
    prop name: N
    func execute(arg: A): R
}

public interface ColleagueArgument<N> where N <: Hashable & Equatable<N> {
    prop name: N
}
