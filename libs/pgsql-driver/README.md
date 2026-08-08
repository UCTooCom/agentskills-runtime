<div align="center">
<h1>pgsql-driver</h1>
</div>

<p align="center">
<a href="LICENSE"><img alt="license" src="https://img.shields.io/badge/License-Apache_2.0-D22128?logo=apache&logoColor=white" /></a>
<img alt="cangjie" src="https://img.shields.io/badge/Cangjie-cjc_1.1.3-7d5fff" />
<img alt="dep" src="https://img.shields.io/badge/PostgreSQL-18-4169E1?logo=postgresql&logoColor=white" />
<img alt="feature" src="https://img.shields.io/badge/interface-std.database.sql-0a7e8c" />
<img alt="tests" src="https://img.shields.io/badge/tests-30_passing-2ea44f" />
<img alt="coverage" src="https://img.shields.io/badge/cjcov-86.9%25-2ea44f" />
</p>

## 介绍

`pgsql` 是一个用纯仓颉（Cangjie）实现的生产级 PostgreSQL 驱动。它直接对接 PostgreSQL 前后端协议 3.0（兼容至 PostgreSQL 18），仅依赖标准库 `std`，并完整实现标准 `std.database.sql` 接口，可与 `DriverManager`、`PooledDatasource` 等开箱即用。

### 项目特性

- **自包含、零外部依赖**：仅依赖 `std`。由于 `std.crypto.digest` 只提供抽象接口而未随包发布具体算法，驱动内置了纯仓颉实现的 SHA-256、MD5、HMAC-SHA-256、PBKDF2、Base64，并以 RFC 标准向量验证。
- **完整认证支持**：SCRAM-SHA-256（现代 PostgreSQL 默认）、MD5、明文口令、trust，均经真实服务器验证。
- **标准接口与扩展协议**：实现 `Driver` / `Datasource` / `Connection` / `Statement` / `QueryResult` / `UpdateResult` / `Transaction` / `ColumnInfo`；预处理语句走扩展查询协议（Parse/Bind/Describe/Execute/Sync），参数化查询防注入，`?` 占位符自动转 `$n`。
- **丰富类型与事务**：覆盖布尔、各宽度整数、浮点（二进制传输保精度）、文本、`bytea`、`numeric`、日期时间；支持 `NULL`、事务与保存点、隔离级别与读写模式、连接串解析与连接池。

## 项目架构

驱动按职责自底向上分层，上层只依赖下层，边界清晰：

| 层 | 模块 | 职责 |
| --- | --- | --- |
| 密码学层 | `crypto.cj`、`scram.cj` | 摘要/HMAC/PBKDF2/Base64 原语与 SCRAM-SHA-256 客户端 |
| 协议层 | `buffer.cj`、`messages.cj`、`oids.cj` | 报文字节读写、分帧、Error/Notice 解析、类型 OID |
| 编解码层 | `value.cj` | 仓颉类型 ↔ PostgreSQL 文本/二进制 值编解码、列信息 |
| 核心层 | `connection.cj`、`statement.cj`、`resultset.cj`、`transaction.cj` | 连接/认证/协议状态机、预处理语句、结果集、事务 |
| 接入层 | `datasource.cj`、`driver.cj`、`pgsql.cj` | 连接串解析、`Driver` 实现与自动注册、包入口 |

### 源码目录

```shell
.
├── README.md             # 本文档
├── LICENSE               # 开源协议(Apache-2.0)
├── cjpm.toml             # 包配置(name=pgsql / output-type=static)
├── cjpm.lock             # 依赖锁定
├── docs                  # 文档
│   └── protocol          #   PostgreSQL 18 前后端协议官方原文(纯文本)
└── src                   # 源码目录
    ├── pgsql.cj          #   包入口 / 版本
    ├── crypto.cj         #   SHA-256 / MD5 / HMAC / PBKDF2 / Base64
    ├── scram.cj          #   SCRAM-SHA-256 客户端状态机
    ├── oids.cj           #   PostgreSQL 类型 OID 常量
    ├── buffer.cj         #   报文读写原语(大端整数 / C 字符串 / 字节序列)
    ├── messages.cj       #   报文类型常量 / 分帧读取 / 错误字段解析
    ├── value.cj          #   值编解码 / ColumnInfo
    ├── connection.cj     #   连接 / 认证 / 协议状态机
    ├── statement.cj      #   预处理语句 / 占位符转换
    ├── resultset.cj      #   QueryResult / UpdateResult
    ├── transaction.cj    #   事务 / 保存点
    ├── datasource.cj     #   数据源 / 连接串解析
    ├── driver.cj         #   Driver 实现 / DriverManager 注册
    └── *_test.cj         #   单元测试与集成测试
```

### 接口说明

驱动的公共类型均实现 `std.database.sql` 中的对应接口；业务代码通常只需通过 `DriverManager` 拿到 `Driver`，其余对象由接口返回。

| 类型 / 接口 | 说明 | 文档 |
| --- | --- | --- |
| `PostgresDriver` | `Driver` 实现，注册名 `"postgres"` | [src/driver.cj](src/driver.cj) |
| `registerDriver()` | 幂等注册驱动（包加载时自动调用一次） | [src/driver.cj](src/driver.cj) |
| `PgDatasource` | `Datasource`，连接串解析与选项 | [src/datasource.cj](src/datasource.cj) |
| `PgConnection` | `Connection`，认证与协议状态机 | [src/connection.cj](src/connection.cj) |
| `PgStatement` | `Statement`，预处理语句（`set<T>` / `query` / `update`） | [src/statement.cj](src/statement.cj) |
| `PgQueryResult` / `PgUpdateResult` | `QueryResult` / `UpdateResult`（`next` / `get<T>` / `getOrNull<T>`） | [src/resultset.cj](src/resultset.cj) |
| `PgTransaction` | `Transaction`，事务与保存点 | [src/transaction.cj](src/transaction.cj) |
| `PgColumnInfo` | `ColumnInfo`，列元信息 | [src/value.cj](src/value.cj) |

公共 API 的语义与 `std.database.sql` 接口一致；协议细节参见 [docs/protocol](docs/protocol/00-INDEX.txt)。

## 使用说明

### 编译构建

**环境依赖**：

- 仓颉工具链 `cjc` / `cjpm` **1.1.3**（cjnative 后端）。
- macOS 上链接可执行文件 / 测试时需指定 SDK 根目录（库本身为 `static`，仅链接阶段需要）：

  ```shell
  export SDKROOT="$(xcrun --show-sdk-path)"
  ```

**构建**：

```shell
cjpm update
cjpm build
```

**测试**：

测试包含三组——密码学向量、纯函数单元测试（均不依赖数据库），以及针对真实 PostgreSQL 的集成测试。运行集成测试前先启动一个数据库容器：

```shell
docker run -d --name cj_pg_test \
  -e POSTGRES_PASSWORD=secret -e POSTGRES_USER=testuser -e POSTGRES_DB=testdb \
  -e POSTGRES_HOST_AUTH_METHOD=scram-sha-256 \
  -p 5433:5432 postgres:18

export SDKROOT="$(xcrun --show-sdk-path)"   # 仅 macOS 需要
cjpm test
```

**作为依赖引入**（其它仓颉项目的 `cjpm.toml`）：

```toml
[dependencies]
  pgsql = { git = "https://gitcode.com/aibrary/pgsql-driver.git", branch = "main" }
```

### 功能示例

#### CRUD 示例

获取驱动、建表、参数化插入、按条件查询并遍历结果：

示例代码：

```cangjie
import std.database.sql.*
import pgsql.*

main() {
    // 驱动在包加载时已自动注册为 "postgres"。
    let drv = DriverManager.getDriver("postgres") ?? return
    let ds = drv.open("postgres://testuser:secret@localhost:5433/testdb", [])
    let conn = ds.connect()

    // 建表。
    let create = conn.prepareStatement(
        "CREATE TABLE IF NOT EXISTS t (id int4 PRIMARY KEY, name text)")
    create.update()
    create.close()

    // 参数化插入。
    let ins = conn.prepareStatement("INSERT INTO t (id, name) VALUES (?, ?)")
    ins.set<Int32>(0, 1)
    ins.set<String>(1, "li lei")
    println("inserted ${ins.update().rowCount} row(s)")
    ins.close()

    // 查询并遍历。
    let sel = conn.prepareStatement("SELECT id, name FROM t WHERE id = ?")
    sel.set<Int32>(0, 1)
    let qr = sel.query()
    while (qr.next()) {
        println("id=${qr.get<Int32>(0)}, name=${qr.get<String>(1)}")
    }
    sel.close()

    conn.close()
}
```

执行结果：

```shell
inserted 1 row(s)
id=1, name=li lei
```

#### 事务与保存点示例

```cangjie
let tx = conn.createTransaction()
tx.isoLevel = TransactionIsoLevel.Serializable
tx.begin()
try {
    // ... 执行若干语句 ...
    tx.save("sp1")
    // ... 更多语句 ...
    tx.rollback("sp1")   // 回滚到保存点(不结束事务)
    tx.commit()
} catch (e: SqlException) {
    tx.rollback()        // 整体回滚
}
```

#### 连接池示例

```cangjie
let pooled = PooledDatasource(drv.open("postgres://testuser:secret@localhost:5433/testdb", []))
pooled.maxSize = 8
let conn = pooled.connect()   // 从池中获取
// ... 使用 ...
conn.close()                  // 归还连接池
pooled.close()
```

## 约束与限制

- **工具链**：`cjc` / `cjpm` 1.1.3（cjnative）；`output-type = static`；`compile-option = "-Woff deprecated"`（接口签名需引用已废弃的 `SqlDbType` 类型）。
- **依赖**：仅标准库 `std`；目标数据库为 PostgreSQL（协议 3.0，已在 PostgreSQL 18 上验证），认证支持 SCRAM-SHA-256 / MD5 / 明文 / trust。
- **平台**：已在 **macOS aarch64（darwin）** 上验证；Linux / Windows 理论可行（仅用到 `std.net` 等标准库）但尚未验证。
- **功能边界**：
  - **暂不支持 TLS/SSL**：连接为明文；若 `ssl.mode` 被设为 `required` / `verify_ca` / `verify_full`，驱动会显式报错而非静默降级为明文。
  - **不支持已废弃的 `SqlDbType` 接口形态**：`Statement.query/update(Array<SqlDbType>)` 与 `QueryResult.next(Array<SqlDbType>)` 仅作为接口要求的桩存在，调用会抛 `SqlException`；请改用原生类型的 `set<T>` / `get<T>` / `getOrNull<T>`。
  - `INSERT` 的 `lastInsertId` 恒为 0（PostgreSQL 已不返回 OID）；获取自增主键请用 `INSERT ... RETURNING id` 并以 `query()` 读取。
  - 占位符仅支持 `?`（与 `std.database.sql` 约定一致），内部转换为 `$n`。
  - 单个 `Connection` 对象非线程安全；并发请使用连接池为每个线程分配独立连接。

## 开源协议

本项目采用 [Apache License 2.0](LICENSE)。内置的密码学实现（SHA-256 / MD5 / HMAC / PBKDF2 / Base64）为本项目依据公开标准（RFC 6234 / 1321 / 2104 / 8018、RFC 4648）自行实现，不含第三方代码。

## 参与贡献

欢迎给我们提交 PR，欢迎给我们提交 Issue，欢迎参与任何形式的贡献。

- **提交前请确保测试全绿**：启动上文的 PostgreSQL 容器后运行 `SDKROOT="$(xcrun --show-sdk-path)" cjpm test`，30 个用例应全部通过。
- **提交信息遵循 [Conventional Commits](https://www.conventionalcommits.org/)**（如 `feat:` / `fix:` / `docs:` / `refactor:` / `test:`），以便据此推导语义化版本。
- **代码风格**：类与方法使用文档注释，关键代码片段在其上方添加行注释，与现有源码保持一致。
