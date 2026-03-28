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
package f_orm.wrap

/*
 * RequiresNew 和 NotSupported 会创建新连接，在这两个特性的作用范围内如果有其它传播特性判定还是以原连接是否创建了事务为依据。
 * 多个指定事务的函数嵌套调用的时候由事务传播枚举决定是创建新的事务还是复用外层函数的事务。
 */
public enum Propagation {
    | Required //外层函数开启了事务就使用这个事务，如果没有事务就创建一个新事务。
    | Supports //外层函数开启了事务就使用这个事务，如果没有事务就不用事务。
    | Mandatory //外层函数开启了事务就使用这个事务，没有事务就抛异常
    | RequiresNew //创建一个新连接，创建新事务。
    | Never //不使用事务，如果外层函数开启了事务就抛出异常。
    | NotSupported //不使用事务，如果外层函数开启了事务就创建一个新的数据库连接执行当前函数的业务。
    | Nested //如果外层函数开启了事务就开启一个新事务，如果没有当前函数也不使用事务。
}