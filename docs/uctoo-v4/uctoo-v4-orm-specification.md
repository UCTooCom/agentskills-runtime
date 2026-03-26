# UCTOO V4 ORM 规范文档

## 文档说明

本文档定义了 UCTOO V4 框架中 ORM（对象关系映射）的使用规范，基于 Fountain 框架的 `f_orm` 模块。大模型在生成 ORM 相关代码时，必须严格遵循本规范。

---

## 一、核心概念

### 1.1 架构层次

UCTOO V4 ORM 采用分层架构：

```
┌─────────────────────────────────────┐
│           Service 层                │
│  (业务逻辑，事务管理)                │
├─────────────────────────────────────┤
│           DAO 层                    │
│  (数据访问，SQL 构建)                │
├─────────────────────────────────────┤
│         SqlExecutor                 │
│  (SQL 执行器，参数绑定)              │
├─────────────────────────────────────┤
│           ORM 层                    │
│  (数据源管理，连接池)                │
├─────────────────────────────────────┤
│         数据库                      │
└─────────────────────────────────────┘
```

### 1.2 核心组件

| 组件 | 说明 | 文件位置 |
|------|------|----------|
| `ORM` | ORM 核心类，负责数据源注册和连接管理 | `f_orm/src/ORM.cj` |
| `SqlExecutor` | SQL 执行器，所有增删改查操作的核心类 | `f_orm/src/SqlExecutor.cj` |
| `RootDAO` | DAO 根接口，提供参数绑定和条件构建方法 | `f_orm/src/RootDAO.cj` |
| `@QueryMappersGenerator` | 实体类宏，自动生成对象关系映射 | `f_orm/src/macros/QueryMappersGenerator.cj` |
| `@ORMField` | 字段映射宏，标注主键和列名 | `f_orm/src/macros/ORMField.cj` |
| `@DAO` | DAO 接口宏，将 DAO 扩展到 SqlExecutor | `f_orm/src/macros/DAO.cj` |
| `@Transactional` | 事务注解，声明式事务管理 | `f_orm/src/Transactional.cj` |

---

## 二、实体类定义规范

### 2.1 基本实体类定义

**规范要求：**

1. 必须使用 `@QueryMappersGenerator` 宏标注类
2. 必须使用 `@ORMField` 宏标注字段
3. 字段可以使用 `private var` 或 `public var` 或 `public mut prop` 声明（推荐使用 `private var`）
4. 类名建议以 `PO` (Persistent Object) 结尾
5. 必须提供默认值

**标准模板：**

```cj
package xxx.model.po

import std.time.DateTime
import fountain.data.macros.*
import fountain.orm.macros.*

@DataAssist[fields]  // 可选，提供字段辅助功能
@QueryMappersGenerator[table_name]  // 指定表名
public class UserPO {
    @ORMField[true 'id']  // 主键，列名为 id
    private var id: Int64 = 0
    
    @ORMField['username']  // 列名为 username
    private var username: String = ''
    
    @ORMField['password']
    private var password: String = ''
    
    @ORMField['created_at']
    private var createdAt: ?DateTime = None<DateTime>  // 可空类型
}
```

### 2.2 @QueryMappersGenerator 宏详解

**语法格式：**

```cj
@QueryMappersGenerator[表名或属性配置]
```

**参数说明：**

| 参数 | 类型 | 说明 | 示例 |
|------|------|------|------|
| 第一个参数 | String | 直接指定表名 | `@QueryMappersGenerator[user_info]` |
| `table` | String/Identifier | 表名或命名格式转换 | `table: LowerUnderScore` |
| `classPrefix` | String | 类名前缀裁剪 | `classPrefix: 'PO'` |
| `classSuffix` | String | 类名后缀裁剪 | `classSuffix: 'PO'` |
| `tablePrefix` | String | 表名前缀 | `tablePrefix: 't_'` |
| `tableSuffix` | String | 表名后缀 | `tableSuffix: '_tab'` |

**命名格式转换选项：**

- `LowerUnderScore`: 驼峰转小写下划线 (UserInfo → user_info)
- `UpperUnderScore`: 驼峰转大写下划线 (UserInfo → USER_INFO)
- `Pascal`: 保持帕斯卡命名 (UserInfo → UserInfo)

**使用示例：**

```cj
// 方式1：直接指定表名
@QueryMappersGenerator[user_info]
public class UserPO { ... }

// 方式2：自动转换（类名 UserInfoPO → 表名 t_user_info）
@QueryMappersGenerator[
    classSuffix: 'PO'
    table: LowerUnderScore
    tablePrefix: 't_'
]
public class UserInfoPO { ... }

// 方式3：单参数时直接作为表名
@QueryMappersGenerator[sys_user]
public class SysUserPO { ... }
```

### 2.3 @ORMField 宏详解

**语法格式：**

```cj
@ORMField[isPrimaryKey columnName dataType]
```

**参数说明：**

| 参数位置 | 类型 | 说明 | 示例 |
|----------|------|------|------|
| 第一个参数 | Bool | 是否为主键 | `true` 或 `false` |
| 第二个参数 | String/Identifier | 列名或命名格式 | `'id'` 或 `LowerUnderScore` |
| 第三个参数 | Identifier | 数据类型（可选） | `BigInt` |

**命名格式选项：**

- `LowerUnderScore`: 字段名转小写下划线
- `UpperUnderScore`: 字段名转大写下划线
- `Pascal`: 保持帕斯卡命名
- `Camel`: 保持驼峰命名
- `'column_name'`: 直接指定列名

**使用示例：**

```cj
// 主键，指定列名
@ORMField[true 'id']
private var id: Int64 = 0

// 非主键，指定列名
@ORMField['user_name']
private var userName: String = ''

// 非主键，自动转换（userName → user_name）
@ORMField[LowerUnderScore]
private var userName: String = ''

// 主键，自动转换，指定数据类型
@ORMField[true LowerUnderScore BigInt]
private var userId: Int64 = 0
```

### 2.4 支持的数据类型

| 仓颉类型 | 数据库类型 | 说明 |
|----------|------------|------|
| `Int8` | TINYINT | 8位整数 |
| `Int16` | SMALLINT | 16位整数 |
| `Int32` | INT | 32位整数 |
| `Int64` | BIGINT | 64位整数 |
| `UInt8` | TINYINT UNSIGNED | 无符号8位整数 |
| `UInt16` | SMALLINT UNSIGNED | 无符号16位整数 |
| `UInt32` | INT UNSIGNED | 无符号32位整数 |
| `UInt64` | BIGINT UNSIGNED | 无符号64位整数 |
| `Float16` | HALF | 半精度浮点 |
| `Float32` | FLOAT | 单精度浮点 |
| `Float64` | DOUBLE | 双精度浮点 |
| `BigInt` | BIGINT | 大整数 |
| `Decimal` | DECIMAL | 精确小数 |
| `String` | VARCHAR/TEXT | 字符串 |
| `Bool` | BOOLEAN | 布尔值 |
| `DateTime` | TIMESTAMP/DATETIME | 日期时间 |
| `Duration` | INTERVAL | 时间间隔 |
| `Array<Byte>` | BLOB | 二进制数据 |
| `InputStream` | BLOB | 大二进制对象 |
| `?T` / `Option<T>` | NULLABLE | 可空类型 |

### 2.5 实体类定义完整示例

```cj
package order.model.po

import std.time.DateTime
import std.math.numeric.Decimal
import fountain.data.macros.*
import fountain.orm.macros.*

@DataAssist[fields]
@QueryMappersGenerator[t_order]
public class OrderPO {
    @ORMField[true 'order_id']
    private var orderId: Int64 = 0
    
    @ORMField['order_no']
    private var orderNo: String = ''
    
    @ORMField['user_id']
    private var userId: Int64 = 0
    
    @ORMField['total_amount']
    private var totalAmount: Decimal = Decimal(0)
    
    @ORMField['status']
    private var status: Int32 = 0
    
    @ORMField['created_at']
    private var createdAt: DateTime = DateTime.UnixEpoch
    
    @ORMField['updated_at']
    private var updatedAt: ?DateTime = None<DateTime>
    
    @ORMField['remark']
    private var remark: ?String = None<String>
}
```

---

## 三、DAO 接口定义规范

### 3.1 基本 DAO 接口定义

**规范要求：**

1. 必须使用 `@DAO` 宏标注接口
2. 必须继承 `RootDAO` 接口
3. 必须声明 `prop executor: SqlExecutor` 属性
4. 接口必须是 `public`
5. 接口不能带泛型形参

**标准模板：**

```cj
package xxx.dao

import std.collection.*
import fountain.orm.*
import fountain.orm.macros.*
import xxx.model.po.*

@DAO
public interface UserDAO <: RootDAO {
    // 必须声明 executor 属性
    prop executor: SqlExecutor
    
    // 方法定义...
}
```

### 3.2 查询操作

#### 3.2.1 单条查询

```cj
// 查询单条记录（返回 Option<T>）
func getUserById(id: Int64): Option<UserPO> {
    executor.setSql('''
        select * 
          from user_info 
         where id = ${arg(id)}
    ''').first<UserPO>()
}

// 查询单条记录（返回实体，不存在则抛异常）
func getUserByIdOrThrow(id: Int64): UserPO {
    executor.setSql('''
        select * 
          from user_info 
         where id = ${arg(id)}
    ''').first<UserPO>().getOrThrow()
}

// 查询单个字段
func getUserNameById(id: Int64): Option<String> {
    executor.setSql('''
        select username 
          from user_info 
         where id = ${arg(id)}
    ''').singleFirst<String>()
}

// 查询结果转为 Map
func getUserToMap(id: Int64): Map<String, Any> {
    executor.setSql('''
        select * 
          from user_info 
         where id = ${arg(id)}
    ''').firstToMap()
}
```

#### 3.2.2 列表查询

```cj
// 查询列表
func listAllUsers(): ArrayList<UserPO> {
    executor.setSql('''
        select * from user_info
    ''').list<UserPO>()
}

// 条件查询列表
func listUsersByStatus(status: Int32): ArrayList<UserPO> {
    executor.setSql('''
        select * 
          from user_info 
         where status = ${arg(status)}
    ''').list<UserPO>()
}

// 查询单列列表
func listAllUserIds(): ArrayList<Int64> {
    executor.setSql('''
        select id from user_info
    ''').singleList<Int64>()
}
```

#### 3.2.3 分页查询

```cj
// 基本分页
func listUsersByPage(size: Int64, page: Int64): Pagination<UserPO> {
    executor.setSql('''
        select * from user_info
    ''').page<UserPO>(size, page: page)
}

// 条件分页
func listUsersByCondition(
    username: String, 
    size: Int64, 
    page: Int64
): Pagination<UserPO> {
    executor.setSql('''
        select * 
          from user_info
         where username like ${arg('%' + username + '%')}
    ''').page<UserPO>(size, page: page)
}
```

### 3.3 插入操作

```cj
// 插入并返回自增ID
func insertUser(username: String, password: String): Int64 {
    executor.setSql('''
        insert into user_info(username, password)
        values(${arg(username)}, ${arg(password)}) 
        returning id
    ''').insert
}

// 使用 INTO 子句插入实体
func insertUserByEntity(user: UserPO): Unit {
    executor.INTO<UserPO>()
        .VALUES(user)
        .execute()
}

// 插入并忽略某些字段
func insertUserIgnoreId(user: UserPO): Unit {
    executor.INTO<UserPO>(ignores: ['id'])
        .VALUES(user)
        .execute()
}
```

### 3.4 更新操作

```cj
// 基本更新
func updatePassword(id: Int64, newPassword: String): Int64 {
    executor.setSql('''
        update user_info
           set password = ${arg(newPassword)}
         where id = ${arg(id)}
    ''').update
}

// 使用 UPDATE 子句
func updateUserStatus(id: Int64, status: Int32): Int64 {
    executor.UPDATE<UserPO>()
        .SET{'status = ${arg(status)}'}
        .WHERE{'id = ${arg(id)}'}
        .execute()
}

// 多字段更新
func updateUserInfo(
    id: Int64, 
    username: String, 
    status: Int32
): Int64 {
    executor.setSql('''
        update user_info
           set username = ${arg(username)},
               status = ${arg(status)}
         where id = ${arg(id)}
    ''').update
}
```

### 3.5 删除操作

```cj
// 基本删除
func deleteUser(id: Int64): Int64 {
    executor.setSql('''
        delete from user_info where id = ${arg(id)}
    ''').delete
}

// 使用 FROM 子句删除
func deleteUserByClause(id: Int64): Int64 {
    executor.FROM<UserPO>()
        .WHERE{'id = ${arg(id)}'}
        .DELETE()
}

// 条件删除
func deleteUsersByStatus(status: Int32): Int64 {
    executor.setSql('''
        delete from user_info where status = ${arg(status)}
    ''').delete
}
```

### 3.6 动态条件查询

```cj
// 使用 meet 函数构建动态条件
func searchUsers(
    username: String, 
    password: String, 
    minAge: ?Int32
): ArrayList<UserPO> {
    executor.setSql('''
        select * 
          from user_info
         ${WHERE('and'){
             '''
             ${meet(username.size > 0, ' username like '){
                 '%${username}%'
             }}
             ${meet(password.size > 0, ' and password like '){
                 '%${password}%'
             }}
             ${meet(minAge.isSome(), ' and age >= '){
                 arg(minAge.getOrThrow())
             }}
             '''
         }}
    ''').list<UserPO>()
}

// 使用 IN 条件
func listUsersByIds(ids: ArrayList<Int64>): ArrayList<UserPO> {
    executor.setSql('''
        select * 
          from user_info 
         where id ${IN(ids)}
    ''').list<UserPO>()
}

// 使用 EXISTS 条件
func listUsersWithOrders(): ArrayList<UserPO> {
    executor.setSql('''
        select * 
          from user_info u
         where ${EXISTS{
             '''
             select 1 
               from order_info o 
              where o.user_id = u.id
             '''
         }}
    ''').list<UserPO>()
}
```

---

## 四、表子句 API 规范

### 4.1 FROM 子句

**基本用法：**

```cj
// 查询所有
executor.FROM<UserPO>().list<UserPO>()

// 条件查询
executor.FROM<UserPO>()
    .WHERE{'id = ${arg(id)}'}
    .list<UserPO>()

// 分页查询
executor.FROM<UserPO>()
    .WHERE{'status = 1'}
    .page<UserPO>(10, page: 1)

// 排序
executor.FROM<UserPO>()
    .WHERE{'status = 1'}
    .ORDER_BY{'id desc'}
    .list<UserPO>()

// 限制条数
executor.FROM<UserPO>()
    .LIMIT(10)
    .list<UserPO>()

// 统计数量
executor.FROM<UserPO>()
    .WHERE{'status = 1'}
    .count()
```

**JOIN 查询：**

```cj
// INNER JOIN
executor.FROM<UserPO>()
    .INNER_JOIN<OrderPO>(AS: 'o', ON: 'user.id = o.user_id')
    .WHERE{'o.status = 1'}
    .list<UserPO>()

// LEFT JOIN
executor.FROM<UserPO>()
    .LEFT_JOIN<OrderPO>(AS: 'o', ON: 'user.id = o.user_id')
    .list<UserPO>()

// RIGHT JOIN
executor.FROM<UserPO>()
    .RIGHT_JOIN<OrderPO>(AS: 'o', ON: 'user.id = o.user_id')
    .list<UserPO>()

// FULL JOIN
executor.FROM<UserPO>()
    .FULL_JOIN<OrderPO>(AS: 'o', ON: 'user.id = o.user_id')
    .list<UserPO>()
```

**复杂条件：**

```cj
// AND/OR 组合
executor.FROM<UserPO>()
    .WHERE{'status = 1'}
    .AND{'age > 18'}
    .OR{'vip = true'}
    .list<UserPO>()

// 括号分组
executor.FROM<UserPO>()
    .WHERE{'status = 1'}
    .PAREN(CondRelOp.AND){
        '''
        age > 18
        or vip = true
        '''
    }
    .list<UserPO>()

// NOT 条件
executor.FROM<UserPO>()
    .WHERE{'status = 1'}
    .NOT{'deleted = true'}
    .list<UserPO>()

// GROUP BY
executor.FROM<UserPO>()
    .WHERE{'status = 1'}
    .GROUP_BY{'department'}
    .list<UserPO>()
```

### 4.2 UPDATE 子句

```cj
// 基本更新
executor.UPDATE<UserPO>()
    .SET{'status = ${arg(1)}'}
    .WHERE{'id = ${arg(userId)}'}
    .execute()

// 多字段更新
executor.UPDATE<UserPO>()
    .SET{
        '''
        status = ${arg(1)},
        updated_at = ${arg(DateTime.now())}
        '''
    }
    .WHERE{'id = ${arg(userId)}'}
    .execute()
```

### 4.3 INTO 子句

```cj
// 插入实体
executor.INTO<UserPO>()
    .VALUES(userPO)
    .execute()

// 插入并忽略字段
executor.INTO<UserPO>(ignores: ['id', 'created_at'])
    .VALUES(userPO)
    .execute()

// 插入查询结果
executor.INTO<UserPO>()
    .SELECT<UserPO>('id, username, password') { from =>
        from.WHERE{'status = 1'}
    }
    .execute()
```

---

## 五、参数绑定规范

### 5.1 arg 函数

**基本用法：**

```cj
// 绑定各种类型的参数
${arg(id)}           // Int64
${arg(username)}     // String
${arg(status)}       // Int32
${arg(price)}        // Decimal
${arg(createdAt)}    // DateTime
${arg(isValid)}      // Bool
```

**可空类型处理：**

```cj
// Option 类型自动处理 NULL
${arg(nullableValue)}  // 如果是 None，绑定 NULL

// 手动处理
match(nullableValue) {
    case Some(v) => arg(v)
    case None => argNull()
}
```

### 5.2 IN 和 NOT IN

```cj
// IN 条件
where id ${IN(idList)}

// NOT IN 条件
where id ${NOT_IN(idList)}
```

### 5.3 EXISTS 和 NOT EXISTS

```cj
// EXISTS 子查询
where ${EXISTS{
    '''
    select 1 
      from order_info 
     where user_id = u.id
    '''
}}

// NOT EXISTS 子查询
where ${NOT_EXISTS{
    '''
    select 1 
      from blacklist 
     where user_id = u.id
    '''
}}
```

---

## 六、事务管理规范

### 6.1 声明式事务（推荐）

**使用 @Transactional 注解：**

```cj
import fountain.orm.*

public class UserService {
    @Transactional[propagation: RequiresNew]
    public func transfer(from: Int64, to: Int64, amount: Decimal): Unit {
        // 业务代码自动在事务中执行
        // 异常自动回滚，正常结束自动提交
    }
}
```

**事务传播行为：**

| 传播行为 | 说明 |
|----------|------|
| `Required` | 有事务就用，没有就创建（默认） |
| `Supports` | 有事务就用，没有就不用 |
| `Mandatory` | 必须有事务，没有就抛异常 |
| `RequiresNew` | 创建新事务，挂起当前事务 |
| `NotSupported` | 不用事务，挂起当前事务 |
| `Never` | 不用事务，有事务就抛异常 |
| `Nested` | 嵌套事务 |

**完整配置：**

```cj
@Transactional[
    driverName: 'primary',           // 可选，指定数据源名称
    propagation: RequiresNew,
    isoLevel: ReadCommitted,
    accessMode: ReadWrite,
    deferrableMode: NotDeferrable,   // 可选，事务延迟模式
    rollbackFor: 'BusinessException',
    noRollbackFor: 'ValidationException'
]
public func complexOperation(): Unit {
    // 业务代码
}
```

**参数说明：**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `driverName` | String | '' | 数据源名称，用于多数据源场景 |
| `propagation` | ?Propagation | None | 事务传播行为 |
| `isoLevel` | ?TransactionIsoLevel | None | 事务隔离级别 |
| `accessMode` | ?TransactionAccessMode | None | 事务访问模式 |
| `deferrableMode` | ?TransactionDeferrableMode | None | 事务延迟模式（PostgreSQL特性） |
| `rollbackFor` | String | '' | 触发回滚的异常类名 |
| `noRollbackFor` | String | '' | 不触发回滚的异常类名 |

### 6.2 编程式事务

**使用 execute 方法：**

```cj
// 推荐方式：自动提交/回滚
func transfer(from: Int64, to: Int64, amount: Decimal): Unit {
    executor.execute<Unit>{
        exe: SqlExecutor =>
        // 业务代码
        exe.setSql("update account set balance = balance - ? where id = ?")
            .add(amount).add(from).update
        exe.setSql("update account set balance = balance + ? where id = ?")
            .add(amount).add(to).update
        ((), true)  // true 表示提交，false 表示回滚
    }
}
```

**手动控制事务：**

```cj
func manualTransaction(): Unit {
    try {
        executor.newTxAndBegin()
        // 业务代码
        executor.commit()
    } catch (e: Exception) {
        executor.rollback()
        throw e
    } finally {
        executor.close()
    }
}
```

**使用保存点：**

```cj
func transactionWithSavepoint(): Unit {
    executor.newTxAndBegin()
    try {
        // 操作1
        executor.save('sp1')
        
        // 操作2
        executor.setSql("...").update
        
        // 如果需要回滚到保存点
        executor.rollback('sp1')
        
        executor.commit()
    } catch (e: Exception) {
        executor.rollback()
    }
}
```

---

## 七、数据库配置规范

### 7.1 数据源注册

```cj
import fountain.orm.*
import std.database.DriverManager

main() {
    // 方式1：使用 Driver 对象
    let driver = DriverManager.getDriver("opengauss").getOrThrow()
    let url = "postgresql://user:password@host:5432/database"
    ORM.register(driver, url, default: true)
    
    // 方式2：使用驱动名称
    ORM.register("mysql", "mysql://user:password@host:3306/database")
    
    // 方式3：使用 NamedDatasource
    let datasource = NamedDatasource.new(driver, url, [])
    ORM.register(datasource, default: true)
}
```

### 7.2 多数据源配置

```cj
// 注册多个数据源
ORM.register(driver1, url1, default: true)  // 默认数据源
ORM.register(driver2, url2, default: false) // 命名数据源

// 使用指定数据源
let executor1 = ORM.executor()              // 默认数据源
let executor2 = ORM.executor("secondary")   // 命名数据源
```

### 7.3 连接池配置

```cj
import fountain.orm.DatabasePool

let pool = DatabasePool(
    driver: driver,
    initSize: 5,
    minSize: 5,
    maxSize: 20,
    checkOnBorrowing: true,
    connectionLife: Duration.hour,
    checkInterval: Duration.minute * 5,
    checkSql: "select 1"
)
```

---

## 八、数据库方言支持

### 8.1 支持的数据库

| 数据库 | 方言类 | 说明 |
|--------|--------|------|
| MySQL | `MySqlDialect` | MySQL 5.7+ |
| PostgreSQL | `PostgresDialect` | PostgreSQL 10+ |
| OpenGauss | `OpenGaussDialect` | OpenGauss |
| Oracle | `OracleDialect` | Oracle 11g+ |
| DB2 | `DB2Dialect` | IBM DB2 |

### 8.2 方言特性

不同数据库的 SQL 语法差异由方言自动处理：

- **分页语法**：MySQL 使用 `LIMIT offset, size`，Oracle 使用 `OFFSET ... FETCH NEXT ...`
- **自增ID返回**：PostgreSQL 使用 `RETURNING`，MySQL 使用 `last_insert_id()`
- **序列**：Oracle 使用序列，PostgreSQL 使用序列或 SERIAL

---

## 九、最佳实践

### 9.1 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 实体类 | 名词 + PO | `UserPO`, `OrderPO` |
| DAO 接口 | 名词 + DAO | `UserDAO`, `OrderDAO` |
| Service 类 | 名词 + Service | `UserService`, `OrderService` |
| 表名 | 小写下划线 | `user_info`, `order_detail` |
| 列名 | 小写下划线 | `user_name`, `created_at` |

### 9.2 包结构规范

```
com.example.module/
├── model/
│   ├── po/           # 持久化对象
│   │   ├── UserPO.cj
│   │   └── OrderPO.cj
│   └── dto/          # 数据传输对象
│       └── UserDTO.cj
├── dao/              # 数据访问层
│   ├── UserDAO.cj
│   └── OrderDAO.cj
└── service/          # 业务逻辑层
    ├── UserService.cj
    └── impl/
        └── UserServiceImpl.cj
```

### 9.3 异常处理

```cj
// DAO 层：抛出具体异常
func getUserById(id: Int64): UserPO {
    executor.setSql("select * from user_info where id = ?")
        .add(id)
        .first<UserPO>()
        .getOrThrow{ORMException("用户不存在: ${id}")}
}

// Service 层：捕获并转换异常
public func getUser(id: Int64): UserDTO {
    try {
        let po = userDAO.getUserById(id)
        convertToDTO(po)
    } catch (e: ORMException) {
        throw BusinessException("获取用户失败: ${e.message}")
    }
}
```

### 9.4 性能优化建议

1. **使用分页查询**：避免一次性查询大量数据
2. **合理使用索引**：WHERE 条件字段应建立索引
3. **批量操作**：使用批量插入代替循环插入
4. **连接池配置**：根据并发量合理配置连接池大小
5. **SQL 优化**：避免 SELECT *，只查询需要的字段

---

## 十、常见问题与解决方案

### 10.1 字段映射错误

**问题**：查询结果字段为 null 或默认值

**原因**：列名与字段名不匹配

**解决方案**：

```cj
// 错误：列名是 user_name，字段名是 username
@ORMField['user_name']
private var username: String = ''

// 正确：明确指定列名
@ORMField['user_name']
private var userName: String = ''

// 或使用自动转换
@ORMField[LowerUnderScore]  // userName → user_name
private var userName: String = ''
```

### 10.2 事务不生效

**问题**：@Transactional 注解的方法事务不生效

**原因**：
1. 方法不是 public
2. 同类方法调用（绕过代理）
3. 异常被捕获未抛出

**解决方案**：

```cj
// 错误：私有方法
@Transactional
private func doSomething() { }  // 事务不生效

// 正确：公共方法
@Transactional
public func doSomething() { }

// 错误：同类调用
public func methodA() {
    methodB()  // 事务不生效
}
@Transactional
public func methodB() { }

// 正确：注入其他 Service 调用
public func methodA() {
    otherService.methodB()  // 事务生效
}
```

### 10.3 参数绑定问题

**问题**：SQL 执行报参数类型错误

**原因**：参数类型与数据库字段类型不匹配

**解决方案**：

```cj
// 错误：字符串类型传给数字字段
executor.setSql("select * from user where id = ?")
    .add("123")  // 错误
    .list<UserPO>()

// 正确：类型匹配
executor.setSql("select * from user where id = ?")
    .add(123)    // 正确
    .list<UserPO>()
```

---

## 十一、完整示例

### 11.1 实体类

```cj
// UserPO.cj
package user.model.po

import std.time.DateTime
import fountain.data.macros.*
import fountain.orm.macros.*

@DataAssist[fields]
@QueryMappersGenerator[t_user]
public class UserPO {
    @ORMField[true 'id']
    private var id: Int64 = 0
    
    @ORMField['username']
    private var username: String = ''
    
    @ORMField['password']
    private var password: String = ''
    
    @ORMField['email']
    private var email: ?String = None<String>
    
    @ORMField['phone']
    private var phone: ?String = None<String>
    
    @ORMField['status']
    private var status: Int32 = 0
    
    @ORMField['created_at']
    private var createdAt: DateTime = DateTime.UnixEpoch
    
    @ORMField['updated_at']
    private var updatedAt: ?DateTime = None<DateTime>
}
```

### 11.2 DAO 接口

```cj
// UserDAO.cj
package user.dao

import std.collection.*
import fountain.orm.*
import fountain.orm.macros.*
import user.model.po.*

@DAO
public interface UserDAO <: RootDAO {
    prop executor: SqlExecutor
    
    // 插入用户
    func insert(user: UserPO): Int64 {
        executor.INTO<UserPO>()
            .VALUES(user)
            .execute()
        executor.setSql("select last_insert_id()").singleFirst<Int64>() ?? 0
    }
    
    // 根据ID查询
    func findById(id: Int64): Option<UserPO> {
        executor.FROM<UserPO>()
            .WHERE{'id = ${arg(id)}'}
            .first<UserPO>()
    }
    
    // 根据用户名查询
    func findByUsername(username: String): Option<UserPO> {
        executor.FROM<UserPO>()
            .WHERE{'username = ${arg(username)}'}
            .first<UserPO>()
    }
    
    // 分页查询
    func findByPage(
        username: String,
        status: ?Int32,
        page: Int64,
        size: Int64
    ): Pagination<UserPO> {
        executor.FROM<UserPO>()
            .WHERE{
                '''
                ${meet(username.size > 0, ' username like '){
                    '%${username}%'
                }}
                ${meet(status.isSome(), ' and status = '){
                    arg(status.getOrThrow())
                }}
                '''
            }
            .ORDER_BY{'id desc'}
            .page<UserPO>(size, page: page)
    }
    
    // 更新用户信息
    func update(user: UserPO): Int64 {
        executor.UPDATE<UserPO>()
            .SET{
                '''
                username = ${arg(user.username)},
                email = ${arg(user.email)},
                phone = ${arg(user.phone)},
                updated_at = ${arg(DateTime.now())}
                '''
            }
            .WHERE{'id = ${arg(user.id)}'}
            .execute()
    }
    
    // 更新状态
    func updateStatus(id: Int64, status: Int32): Int64 {
        executor.UPDATE<UserPO>()
            .SET{'status = ${arg(status)}'}
            .WHERE{'id = ${arg(id)}'}
            .execute()
    }
    
    // 删除用户
    func deleteById(id: Int64): Int64 {
        executor.FROM<UserPO>()
            .WHERE{'id = ${arg(id)}'}
            .DELETE()
    }
    
    // 批量查询
    func findByIds(ids: ArrayList<Int64>): ArrayList<UserPO> {
        executor.FROM<UserPO>()
            .WHERE{'id ${IN(ids)}'}
            .list<UserPO>()
    }
    
    // 统计数量
    func countByStatus(status: Int32): Int64 {
        executor.FROM<UserPO>()
            .WHERE{'status = ${arg(status)}'}
            .count()
    }
}
```

### 11.3 Service 层

```cj
// UserService.cj
package user.service

import std.collection.*
import fountain.orm.*
import user.model.po.*
import user.dao.*

public interface UserService {
    func createUser(user: UserPO): Int64
    func getUserById(id: Int64): Option<UserPO>
    func getUserByUsername(username: String): Option<UserPO>
    func listUsers(page: Int64, size: Int64): Pagination<UserPO>
    func updateUser(user: UserPO): Unit
    func deleteUser(id: Int64): Unit
}

// UserServiceImpl.cj
package user.service.impl

import std.collection.*
import fountain.orm.*
import user.model.po.*
import user.dao.*
import user.service.*

public class UserServiceImpl <: UserService {
    private let userDAO: UserDAO = ORM.executor()
    
    @Transactional[propagation: RequiresNew]
    public func createUser(user: UserPO): Int64 {
        // 检查用户名是否已存在
        if (userDAO.findByUsername(user.username).isSome()) {
            throw BusinessException("用户名已存在")
        }
        userDAO.insert(user)
    }
    
    public func getUserById(id: Int64): Option<UserPO> {
        userDAO.findById(id)
    }
    
    public func getUserByUsername(username: String): Option<UserPO> {
        userDAO.findByUsername(username)
    }
    
    public func listUsers(page: Int64, size: Int64): Pagination<UserPO> {
        userDAO.findByPage("", None<Int32>, page, size)
    }
    
    @Transactional
    public func updateUser(user: UserPO): Unit {
        let existing = userDAO.findById(user.id)
            .getOrThrow{BusinessException("用户不存在")}
        userDAO.update(user)
    }
    
    @Transactional
    public func deleteUser(id: Int64): Unit {
        userDAO.deleteById(id)
    }
}
```

---

## 十二、附录

### 12.1 RootDAO 接口方法列表

| 方法 | 说明 |
|------|------|
| `arg(value: T): String` | 参数绑定，返回 `?` |
| `argNull()` | 绑定 NULL 值 |
| `meet(condition: Bool, partial: String): MeetCondition` | 条件匹配 |
| `meet(condition: Bool, partial: ()->String): String` | 条件匹配（闭包） |
| `IN<I, T>(value: I): String` | IN 条件 |
| `NOT_IN<I, T>(value: I): String` | NOT IN 条件 |
| `EXISTS(exists: ()->String): String` | EXISTS 子查询 |
| `NOT_EXISTS(notExists: ()->String): String` | NOT EXISTS 子查询 |
| `WHERE(partial: ()->String): String` | WHERE 子句 |
| `WHERE(delimiter: String, partial: ()->String): String` | WHERE 子句（指定分隔符） |
| `SET(partial: ()->String): String` | SET 子句 |
| `trim(prefix: String, suffix: String, partial: ()->String): String` | 去除前缀后缀 |

### 12.2 SqlExecutor 方法列表

| 方法 | 说明 |
|------|------|
| `setSql(sql: String): SqlExecutor` | 设置 SQL 语句 |
| `add(value: T): SqlExecutor` | 添加参数 |
| `addNull(): SqlExecutor` | 添加 NULL 参数 |
| `first<T>(): Option<T>` | 查询单条记录 |
| `list<T>(): ArrayList<T>` | 查询列表 |
| `one<T>(): Option<T>` | 查询单条（严格模式） |
| `singleFirst<T>(): Option<T>` | 查询单列单条 |
| `singleList<T>(): ArrayList<T>` | 查询单列列表 |
| `firstToMap(): Map<String, Any>` | 查询结果转 Map |
| `mapList(): ArrayList<HashMap<String, Any>>` | 查询结果列表转 Map |
| `page<T>(size: Int64, page: Int64): Pagination<T>` | 分页查询 |
| `update: Int64` | 执行更新，返回影响行数 |
| `delete: Int64` | 执行删除，返回影响行数 |
| `insert: Int64` | 执行插入，返回自增ID |
| `FROM<T>(): FromClause<T>` | 创建 FROM 子句 |
| `UPDATE<T>(): UpdateClause<T>` | 创建 UPDATE 子句 |
| `INTO<T>(): IntoClause<T>` | 创建 INSERT 子句 |
| `newTxAndBegin(): SqlExecutor` | 开启事务 |
| `commit()` | 提交事务 |
| `rollback()` | 回滚事务 |
| `execute<T>(executor: (SqlExecutor)->(T, Bool)): T` | 事务执行 |

### 12.3 MeetCondition 方法列表

| 方法 | 说明 |
|------|------|
| `value(v: Any): MeetCondition` | 设置条件值 |
| `value(v: ()->Any): MeetCondition` | 设置条件值（闭包） |
| `BETWEEN(a: Any, b: Any): String` | BETWEEN 条件 |
| `done(): String` | 完成条件构建 |

---

## 文档版本

- **版本**: v1.0
- **创建日期**: 2025-03-16
- **适用框架**: UCTOO V4 (基于 Fountain f_orm)
- **仓颉语言版本**: cjpm 0.53.4+

---

**注意**: 本规范文档会随着框架版本更新而持续完善。如有疑问或建议，请联系框架维护团队。
