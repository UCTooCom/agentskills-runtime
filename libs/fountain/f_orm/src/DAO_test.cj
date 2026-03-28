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
package f_orm

// import std.time.*
// import std.collection.ArrayList
// import std.database.sql.*
// import orm.macros.*
// import orm.exception.*
// // let _ = ORM.register(DriverTest()) // 1
// let _ = ORM.register(DatasourceCreatorImpl()) // 2
// public func topTest(): Unit {
//     let list = TestService().query()
//     println(list.size)
//     println(list)
// }
// // @Transactional[]
// // public class TestService <: RootService {
// //     public func query(): ArrayList<User> {
// //         executor().findUserList("s")
// //     }
// // }
// public class TestService <: RootService {
//     public func query(): ArrayList<String> {
//         func __callee__() {
//             // executor().findUserList("s")
//             ArrayList<String>()
//         }
//         var committing = false
//         let _exe_ = this.executor("")
//         let r = try (exe = _exe_) {
//             let tx = exe.createTransaction(propagation: Propagation.Required)
//             tx.begin()
//             let result = tx.call(__callee__)
//             committing = true
//             _exe_.commit()
//             result
//         } catch (e: Exception) {
//             throw e
//         }
//         r
//     }
// }
// @QueryMappersGenerator[id]
// public class User <: ToString {
//     private var _id_: Int64 = 0
//     private var _username_: String = String.empty
//     private var _logged_: Bool = false
//     private var _registerTime_: DateTime = DateTime.now()
//     public func toString(): String {
//         "id: ${id}; username: ${username}; logged: ${logged}; registerTime: ${registerTime}"
//     }
//     public mut prop id: Int64 {
//         get() {
//             _id_
//         }
//         set(value) {
//             this._id_ = value
//         }
//     }
//     public mut prop username: String {
//         get() {
//             _username_
//         }
//         set(value) {
//             _username_ = value
//         }
//     }
//     public mut prop logged: Bool {
//         get() {
//             _logged_
//         }
//         set(value) {
//             _logged_ = value
//         }
//     }
//     public mut prop registerTime: DateTime {
//         get() {
//             _registerTime_
//         }
//         set(value) {
//             _registerTime_ = value
//         }
//     }
// }
// @DAO
// public interface TestDAO <: RootDAO {
//     func findUserList(namePrefix: String): ArrayList<User> {
//         executor.generateSql {
//             args: SqlArgs => """
//             select *
//               from user_info
//               ${args.meet(!namePrefix.isEmpty(), "username like", "${namePrefix}%", prefix: "where")}
//             """
//         }.list<User>(User.queryMappers())
//     }
// }
