# 仓颉编译修复

本页整理仓颉编译报错的常见原因、诊断方法、修复方式和验证要点。

代码示例分为可独立编译的最小示例和依赖当前场景的替换片段。替换片段沿用同一场景中已声明的类型、导入和辅助函数，业务接口需接入目标项目的真实实现。

可执行 DT 优先沿用目标项目已有测试结构；项目没有现成用例时参考 `cangjie-coding` 中的 `std.unittest` 文档。

首先记录原始 `cjc`/`cjpm` 命令、退出码、SDK 和从第一条开始的完整诊断，再决定是否执行 `clean`。根因分析从最早且能够解释后续错误的诊断开始。可直接由 `cjc` 编译的最小文件使用稳定诊断：

```shell
cjc --diagnostic-format=json path/to/main.cj
```

一次只验证一个根因假设；修复后重跑原始命令和相关 `cjpm test`。

## 1. 类型转换与 Option

### 1.1 字符串转数值与失败语义

常见表现包括：类型不匹配、泛型推断失败、把 `String` 直接赋给整数，或者为了消除错误准备放宽类型。

`String` 与整数之间不会隐式转换。运行时输入使用 `std.convert` 的 `parse`/`tryParse`；可能缺失的值使用 `?T`，不要用无约束类型或默认值掩盖失败。

错误代码：

```cangjie
main(): Int64 {
    let value: Int64 = "not an integer"
    return value
}
```

问题说明：`String` 不会隐式转换为 `Int64`。若业务值本来就是整数常量，应直接使用整数；若它是运行时输入，则必须明确解析失败是抛异常还是返回 `None`。

修正代码：

```cangjie
import std.convert.*

func parseCount(raw: String): Int64 {
    return Int64.parse(raw)
}

func tryParseCount(raw: String): ?Int64 {
    return Int64.tryParse(raw)
}
```

#### 诊断与修复

1. 保存第一条类型诊断及其源代码位置，确认 `raw` 来自常量、配置、命令行还是外部数据，并让调用方明确解析失败应抛异常还是返回 `None`。用一个合法值和一个非法值编译、运行最小路径，不能只验证错误代码“变得可编译”。

2. `Int64.parse(raw)` 对空字符串、格式非法和超出 `Int64` 范围等解析失败均抛出 `IllegalArgumentException`；`Int64.tryParse(raw)` 对这些失败返回 `None`。DT 同时覆盖合法值、空字符串、非数字、边界值和调用方的 `None` 分支，不把两种 API 的失败结果写成“视实现而定”。

3. 缺少业务输入语义时，只说明可选方案，不擅自决定抛异常、返回 `None` 或静默使用默认值；修复代码和备选示例中也不得写入无业务依据的 `Int64.tryParse(raw) ?? 0`、空字符串或其他默认值。

### 1.2 安全向下转型与 Option

常见表现包括：`as` 表达式之后直接访问目标类型成员、把 `Option<T>` 赋给 `T`，或用异常式强制解包处理正常的类型不匹配。

`value as Target` 返回 `Option<Target>`，运行时类型匹配时为 `Some`，不匹配时为 `None`；它不是 C++ 风格的强制转换，也不会直接返回 `Target`。

错误代码：

```cangjie
open class Animal {}

class Cat <: Animal {
    public func meow(): String { "meow" }
}

main() {
    let animal: Animal = Cat()
    let cat: Cat = animal as Cat // as 的结果是 Option<Cat>
    println(cat.meow())
}
```

问题说明：`animal as Cat` 的静态类型是 `Option<Cat>`，错误代码把它直接赋给了 `Cat`，因此既违反类型约束，也没有处理运行时类型不匹配的 `None` 分支。

修正代码：

```cangjie
main() {
    let animal: Animal = Cat()
    match (animal as Cat) {
        case Some(cat) => println(cat.meow())
        case None => println("not a cat")
    }
}
```

#### 诊断与修复

1. 保存源表达式的静态类型、实际运行时类型、目标类型和第一条诊断；分别构造匹配与不匹配对象确认调用方语义。

2. 使用 `match`、`if-let` 或 `is` 后的受控分支处理结果，DT 同时覆盖 `Some` 与 `None`，不要用无依据默认对象掩盖类型不匹配。

3. 无法确认类型不匹配是正常分支还是程序错误时，只列出两种处理语义，不替业务选择。

### 1.3 泛型约束与不型变

常见表现包括：泛型函数体无法调用 `Hashable`、`Equatable` 或 `ToString` 能力，或者把 `Container<Sub>` 当作 `Container<Base>` 赋值。

泛型能力必须在 `where` 中显式约束；同一类型参数的多个接口上界用 `&`。用户自定义泛型类型默认不型变，即使 `Sub <: Base`，`Box<Sub> <: Box<Base>` 也不成立。

错误代码：

```cangjie
import std.collection.*

func countOne<T>(value: T): Int64 {
    let counts = HashMap<T, Int64>() // T 缺少 Hashable 与 Equatable<T> 约束
    counts.add(value, 1)
    counts.get(value).getOrThrow()
}
```

问题说明：`HashMap` 的键必须满足哈希和相等性约束，但无约束的 `T` 不保证提供这些能力，编译器无法证明 `HashMap<T, Int64>` 合法。

修正代码：

```cangjie
import std.collection.*

func countOne<T>(value: T): Int64 where T <: Hashable & Equatable<T> {
    let counts = HashMap<T, Int64>()
    counts.add(value, 1)
    counts.get(value).getOrThrow()
}
```

#### 诊断与修复

1. 找到第一条约束或赋值诊断，分别记录类型参数、实际类型实参和函数体需要的接口，不要只在调用点增加转换。

2. 为算法实际使用的最小能力增加 `where T <: ...`；型变需求通过只读接口、显式映射或重新设计 API 表达。编译一个满足约束和一个不满足约束的调用。

3. 若修改公共泛型约束会破坏现有调用方，先报告兼容性影响，不擅自扩大或收紧 API。

---

## 2. 包、导入与可见性

### 2.1 包声明与目录路径不一致

常见表现包括：找不到包或符号、同名冲突、声明存在但不可见、单文件可编译而 `cjpm build` 失败。

包是最小编译单元。`package` 必须匹配源码相对于 `src/` 的目录路径；同一包内文件使用相同声明。`import` 位于 `package` 之后和其他声明之前，且不能导入当前包、循环依赖或不可见声明。顶层 `private`、`internal`、`protected`、`public` 的边界不同，不能靠增加通配导入绕过可见性。

错误代码：

```cangjie
// 文件路径：src/service/client.cj
package default.storage // 与路径要求的 default.service 不一致

public class Client {}
```

问题说明：文件位于 `src/service/`，包声明却指向 `default.storage`，导致目录、编译单元和导入路径表达了不同的包。

修正代码：

```cangjie
// 文件路径：src/service/client.cj
package default.service

public class Client {}
```

#### 诊断与修复

1. 同时检查报错文件路径、`package` 行、导入目标的访问修饰符、`cjpm.toml` 的模块/依赖，以及是否被本地同名声明遮蔽。不要把多包项目抽成改变包结构的单文件后就宣布修复。

2. 优先修正目录、包名或最小必要导入；名称冲突可使用 `import pkg.Name as Alias` 或包名限定。重跑原始 `cjpm build`，再运行直接依赖该包的测试。

3. 未获得移动文件、改变公共可见性或调整模块依赖的授权时，停在根因和最小改动建议。

### 2.2 导入冲突与重命名

常见表现包括：两个包导出同名类型、导入成功但使用处歧义、本地声明遮蔽导入声明，或重命名后仍使用旧名称。

可使用 `import pkg.Name as Alias` 或导入包名后以 `pkg.Name` 限定；本地声明优先于导入声明，同签名函数还会参与重载解析。

错误代码：

```cangjie
import api.v1.User
import api.v2.User

main() {
    let user = User() // User 来自两个包，使用处发生歧义
    println(user)
}
```

问题说明：两个 import 都把名称 `User` 引入当前作用域，使用裸名称时没有唯一目标；继续增加通配导入只会扩大冲突面。

修正代码：

```cangjie
import api.v1.User as V1User
import api.v2.User as V2User

main() {
    let oldUser = V1User()
    let newUser = V2User()
    println("created users from api.v1 and api.v2")
}
```

这里不直接插值输出 `oldUser` 和 `newUser`，因为别名只解决名称冲突；自定义 `User` 是否实现 `ToString` 是另一项独立契约。

#### 诊断与修复

1. 列出冲突名称的所有来源、当前文件的 import、本地同名声明和实际使用点，不通过通配导入扩大冲突面。

2. 只为冲突的声明增加别名或包限定符，编译直接使用两个来源的最小调用，并重跑受影响包测试。

3. 名称属于公共 API 且重命名会影响外部调用方时，保留兼容别名或请求 API 决策。

### 2.3 访问级别与重新导出

常见表现包括：`public` 函数返回 internal/private 类型、外部模块无法访问声明，或误以为普通 import 会重新导出成员。

顶层访问级别为 `private`、`internal`、`protected`、`public`；公开声明签名中使用的类型不能比声明本身更不可见。重新导出使用带访问修饰符的 import，包本身不能被重新导出。

错误代码：

```cangjie
class InternalItem {
    let value = 7
}

public func makeItem(): InternalItem { // public API 暴露 internal 类型
    InternalItem()
}
```

问题说明：`makeItem` 对模块外公开，但返回类型仍是默认的 `internal`，外部调用者无法表达或使用该公开签名。

修正代码：

```cangjie
public class Item {
    public let value = 7
}

public func makeItem(): Item {
    Item()
}
```

#### 诊断与修复

1. 比较声明、参数、返回类型、泛型约束和 import 的访问级别，并确认访问发生在文件、包、模块还是模块外。

2. 采用满足需求的最小可见性，或缩小公共 API；从真实调用边界重新编译，不能只在声明所在文件内验证。

3. 未确认 API 是否应公开时，不把 internal/private 批量改成 public。

---

## 3. 宏包与展开

### 3.1 宏包与调用包边界

常见表现包括：宏符号不可见、宏展开阶段报错、普通源码能编译但带宏调用失败。

宏声明位于 `macro package`；宏定义和调用必须在不同包。直接使用 `cjc` 时先以 `--compile-macro` 编译宏包，再让调用包通过导入路径找到产物；`cjpm` 项目则检查宏包声明和源码依赖，交叉编译时再按需检查 `compile-macros-for-target`，不要把普通包和宏包混为同一编译阶段。

错误代码：

```cangjie
macro package demo

import std.ast.*

public macro Identity(input: Tokens): Tokens { input }

// 宏定义和调用被放进同一个宏包
@Identity
func value(): Int64 { 1 }
```

问题说明：宏实现必须位于专用宏包，而调用代码必须位于另一个普通包；把二者放进同一个 `macro package` 会破坏宏的编译与展开边界。

修正代码：

```cangjie
// macros/src/identity.cj
macro package macros
import std.ast.*

public macro Identity(input: Tokens): Tokens { input }
```

```cangjie
// app/src/main.cj
package app
import macros.*

@Identity
func value(): Int64 { 1 }
```

#### 诊断与修复

1. 区分错误发生在宏包编译、宏导入、展开还是展开后的普通语义分析。保存第一条宏阶段诊断，并检查当前 `cjc --help` 是否支持准备使用的调试或展开参数。

2. 先独立构建宏包，再构建最小调用包，最后重跑整个 `cjpm build`。只修宏输入或展开结果中被诊断指向的最小部分。

3. 看不到展开结果或当前 SDK 不支持目标调试参数时，保留原始宏诊断，不编造展开后的代码。

### 3.2 宏展开阶段与普通语义阶段

常见表现包括：第一条错误来自宏展开，但只修改展开后的普通源码；或者宏生成的代码通过展开后在类型检查阶段失败。

宏包编译、宏导入、Token/Tokens 处理、展开和展开后语义分析是不同阶段；相同源位置附近的后续错误可能只是级联结果。

错误代码：

```cangjie
// macros/src/force_text.cj
macro package macros
import std.ast.*

public macro ForceText(input: Tokens): Tokens {
    quote("text") // 展开得到 String
}
```

```cangjie
// app/src/main.cj（调用包）
package app
import macros.*

let count: Int64 = @ForceText(1) // 展开成功，随后类型检查失败
```

问题说明：宏本身成功返回了 Tokens，但生成的是 `String` 字面量；错误直到展开后的普通类型检查阶段才出现，因此应修复宏生成逻辑，而不是修改展开产物。

修正代码：

```cangjie
// macros/src/keep_value.cj
macro package macros
import std.ast.*

public macro KeepValue(input: Tokens): Tokens {
    input
}
```

```cangjie
// app/src/main.cj
package app
import macros.*

let count: Int64 = @KeepValue(1)
```

#### 诊断与修复

1. 保存第一条带阶段和位置的诊断，确认失败发生在宏定义、宏输入、展开动作还是生成代码的普通语义检查。

2. 为宏输入和生成结构建立最小调用，先独立通过宏包，再验证调用包；每次只修复一个阶段的首因。

3. 当前 SDK 无法展示所需展开证据时，不编造生成代码；报告可见诊断和工具门禁。

### 3.3 宏依赖与构建配置

常见表现包括：宏源码本身可编译，但调用模块没有声明宏包依赖、依赖路径错误，或交叉编译时没有按目标平台配置宏产物。

宏定义必须位于以 `macro package` 声明的包中。直接使用 `cjc` 编译宏包时需要 `--compile-macro`；`cjpm` 通过源码依赖识别宏包，无需在 `[package]` 中额外填写 `compile-option = "--compile-macro"`。直接 `cjc` 与 `cjpm` 使用不同的依赖和产物查找方式。

错误代码：

```toml
# app/cjpm.toml
[package]
cjc-version = "1.0.5"
name = "app"
version = "1.0.0"
output-type = "executable"

[dependencies]
macros = { path = "../macro" } # 实际宏模块目录是 ../macros
```

问题说明：调用代码已经导入 `macros` 中的宏，但依赖路径指向不存在的目录，`cjpm build` 无法加载宏包。给普通模块增加 `--compile-macro` 不能修复路径错误。

修正代码：

```toml
# app/cjpm.toml
[package]
cjc-version = "1.0.5"
name = "app"
version = "1.0.0"
output-type = "executable"

[dependencies]
macros = { path = "../macros" }
```

#### 诊断与修复

1. 保存宏模块和调用模块的 `cjpm.toml`、宏包的 `macro package` 声明、依赖路径、实际构建命令及首条产物查找诊断。

2. 修正最小依赖边或宏包声明，分别构建宏包和调用包，再运行完整项目测试；交叉编译需要目标平台宏产物时再检查 `compile-macros-for-target`。

3. 缺少完整 workspace 或宏模块配置时，不凭单文件成功推断项目构建已修复。

---

## 4. CFFI、链接与目标架构

### 4.1 CFFI 类型映射与 unsafe 边界

常见表现包括：`foreign` 声明通过语义检查但链接失败、符号未定义、动态库找不到、产物可链接却无法启动，或者库架构与仓颉目标不一致。

CFFI 问题至少分为仓颉声明、链接和运行时装载三层。`cjc -v` 的 `Target` 必须与 C 库架构一致；直接编译时检查 `-L`/`-l`，`cjpm` 项目检查 `[ffi.c]` 和目标平台库路径。Linux、macOS、Windows 的动态库扩展名和装载规则不同。

错误代码：

```cangjie
foreign func strlen(value: CString): UIntNative

main() {
    let value = unsafe { LibC.mallocCString("hello") }
    let length = strlen(value) // foreign 调用缺少 unsafe 上下文
    println(length)
    unsafe { LibC.free(value) }
}
```

问题说明：`foreign` 函数可能访问仓颉无法验证的外部内存和 ABI，调用具有 `unsafe` 传染性；只把 CString 分配放入 `unsafe` 并不能覆盖后续的 C 调用。

修正代码：

```cangjie
foreign func strlen(value: CString): UIntNative

main() {
    let value = unsafe { LibC.mallocCString("hello") }
    let length = unsafe { strlen(value) }
    println(length)
    unsafe { LibC.free(value) }
}
```

#### 诊断与修复

1. 保存完整链接器或装载器消息；记录目标三元组、库文件架构、导出符号、实际库路径和启动环境。不要把“链接成功”当成“运行时能够找到动态库”。

2. 先用最小 C 函数验证声明与 ABI，再按原构建方式链接，最后直接运行真实产物验证动态库装载。修改 rpath、环境变量或系统搜索路径前先说明影响范围。

3. 函数签名以目标平台库、头文件、ABI 说明和导出符号为依据；材料不完整时记录已确认的失败层级和待验证项。

### 4.2 链接符号与库搜索路径

常见表现包括：仓颉声明通过但链接器报告 undefined symbol、找不到 `-l` 对应库，或静态库顺序改变结果。

foreign 声明只证明仓颉侧签名可解析；链接还取决于导出符号名、`-L`/`-l`、`[ffi.c]`、库类型和平台链接器规则。

错误代码：

```cangjie
// 链接的 native 库没有导出此符号
foreign func functionThatLibraryDoesNotExport(): Int32

main() {
    println(unsafe { functionThatLibraryDoesNotExport() })
}
```

问题说明：`foreign` 只声明仓颉侧签名，不会创建 C 符号；链接库必须真正导出完全匹配的符号和 ABI。

修正代码：

```c
// native.c
#include <stdint.h>

int32_t exported_value(void) {
    return 7;
}
```

```cangjie
foreign func exported_value(): Int32

main() {
    println(unsafe { exported_value() })
}
```

#### 诊断与修复

1. 保存完整链接命令、首个未定义符号、库导出符号和实际搜索路径；区分 C 符号、C++ 名字修饰和条件编译未导出。

2. 用一个最小 C 导出函数确认符号与签名，再按项目原方式链接；不通过全局复制库文件绕过构建配置。

3. foreign 签名以目标库导出、头文件和 ABI 契约为依据；材料不完整时保留待验证项。

### 4.3 目标架构、ABI 与动态库装载

常见表现包括：链接器报告架构不兼容、程序启动时报动态库缺失，或同一库在 macOS/Linux/Windows 表现不同。

`cjc -v` 的 Target、C 库架构、调用约定和运行时装载路径必须一致；链接成功不等于启动时能定位动态库。

错误代码：

```shell
# 当前 cjc target 是 aarch64-apple-darwin，却链接 x86_64 目录中的库
cjc -L ./native/x86_64 -l native src/main.cj -o build/main
./build/main
```

问题说明：仓颉产物是 `aarch64`，输入库却是 `x86_64`，两者无法组成同一链接映像；即使链接阶段找到库，启动时还必须能定位相同架构的动态库。

修正代码：

```shell
# 使用与 cjc target 一致的 aarch64 库，并在启动时提供同一库目录
cjc -L ./native/aarch64 -l native src/main.cj -o build/main
DYLD_LIBRARY_PATH=./native/aarch64 ./build/main
```

#### 诊断与修复

1. 记录仓颉 target triple、库文件架构、平台、ABI、rpath/装载环境和实际启动命令。

2. 为目标平台重新构建匹配库或修正项目内装载配置，直接运行最终产物并覆盖部署环境，不只运行编译步骤。

3. 没有目标平台或匹配库时明确说明平台限制，不在当前机器伪造跨平台通过。

---

## 5. 语法、声明与表达式

### 5.1 关键字、声明位置与源码结构

常见表现包括：把关键字作为普通标识符、在函数内定义只能位于顶层的类型、`package`/`import` 位置错误，或者把独立的 `{ ... }` 代码块当成表达式。

仓颉关键字不能直接作为标识符，确有需要时使用反引号写成原始标识符，例如 ``let `type` = "demo"``。`class`、`struct`、`enum`、`interface` 和类型别名只能在顶层声明；`package` 必须位于文件第一条非注释语句，`import` 位于 `package` 之后和其他声明之前。仓颉的代码块依附于函数、`if`、`match`、循环等复合表达式，不能单独写成可赋值的块表达式。

错误代码：

```cangjie
main() {
    class LocalType {} // class 不能声明在函数内部
    let value = LocalType()
    println(value)
}
```

问题说明：仓颉类型声明只能位于顶层，函数体内只能使用已经声明的类型；错误代码在 `main` 的局部作用域中声明了 class。

修正代码：

```cangjie
class LocalType {
    public let name: String = "local"
}

main() {
    let value = LocalType()
    println(value.name)
}
```

#### 诊断与修复

1. 从第一条 parser 或 declaration 诊断定位非法 token 和声明边界，同时查看前一行是否缺少括号、引号或大括号；不要只修改编译器最后标出的行。

2. 关键字命名优先改成含义明确的新名称；只有外部协议强制名称时才使用反引号。将类型和类型别名移动到顶层，并恢复 `package`、`import`、声明的正确顺序。重新编译整个包，确认移动没有改变可见性和初始化顺序。

3. 宏展开或生成代码中的结构错误先回到生成源修复；没有生成规则或展开结果时，不直接维护下一次构建会被覆盖的产物。

### 5.2 let、var、const 与初始化状态

常见表现包括：重新赋值 `let`、在赋值前读取局部变量、未初始化全局/静态变量，或者把运行时值写入 `const`。

`let` 只能赋值一次，`var` 才允许重新赋值，`const` 必须具有编译期可求值的初始化器。全局和静态变量必须初始化；局部变量可以延迟初始化，但所有控制流路径都必须在读取前完成赋值。函数参数同样不可重新赋值。

错误代码：

```cangjie
main() {
    let retries = 0
    retries += 1 // let 只能赋值一次
    println(retries)
}
```

问题说明：`retries` 使用 `let` 声明后只能赋值一次，`+=` 是第二次写入。对于引用类型，`let` 禁止变量重新指向其他对象，但不必然禁止修改对象内部的 `var` 成员；对于值类型，`let` 会阻止对值本身的修改。

修正代码：

```cangjie
main() {
    var retries = 0
    retries += 1
    println(retries)
}
```

#### 诊断与修复

1. 记录被修改名称的声明位置、类型和所有写入点，区分变量重新赋值、对象成员修改、结构体值修改以及尚未初始化四类问题。

2. 状态确实需要变化时才将局部 `let` 改为 `var`；否则改为计算新值或缩小可变作用域。对延迟初始化检查 `if`、`match`、异常和提前返回的每条路径，确保读取前已赋值。

3. 无法说明变量为何必须可变时，保留 `let` 并修正数据流；不要用全局可变状态绕过局部初始化诊断。

### 5.3 Bool 条件与复合表达式类型

常见表现包括：把整数、字符串或 Option 直接放入 `if`/`while` 条件，`if` 缺少 `else` 却被当成值使用，或者复合表达式最后一项与期望类型不匹配。

仓颉没有 C/C++ 风格的 truthy/falsy 转换，`if`、`while` 和模式守卫的条件必须是 `Bool`。带 `else` 的 `if` 可以作为值，其类型由上下文或各分支的最小公共父类型决定；没有 `else` 的 `if` 类型始终为 `Unit`。函数体和分支代码块通常以最后一个表达式作为值。

错误代码：

```cangjie
main() {
    let count = 1
    if (count) { // Int64 不能作为 Bool 条件
        println("positive")
    }
}
```

问题说明：仓颉不把非零整数隐式解释为 `true`，`if` 条件的静态类型必须是 `Bool`；比较规则应显式表达业务含义。

修正代码：

```cangjie
main() {
    let count = 1
    if (count > 0) {
        println("positive")
    }
}
```

#### 诊断与修复

1. 保存条件表达式的静态类型和上下文期望类型；对 `Option` 明确检查 `Some/None`，对集合和字符串明确比较 `size` 或业务状态，条件语义以仓颉的 `Bool` 类型要求为准。

2. 为作为值使用的 `if` 补齐语义真实的 `else`，并检查每个分支最后一个表达式。DT 至少覆盖条件为真、为假以及导致不同返回分支的边界输入。

3. 业务没有定义空值、零值或空集合的真假含义时，不擅自选择比较条件；先明确业务规则。

---

## 6. 函数、Lambda 与重载

### 6.1 位置参数、命名参数与默认值

常见表现包括：参数数量或顺序错误、把命名参数按位置传递、调用时写成 `name!:`，或者把默认值放在非命名参数上。

普通形参写作 `name: Type`，按位置传递；命名形参写作 `name!: Type`，调用时使用 `name: value`，不带 `!`。只有命名参数可以设置默认值，且普通参数必须位于命名参数之前。命名实参之间可以调整顺序，但仍须提供所有没有默认值的参数。

错误代码：

```cangjie
func format(value: Int64, width!: Int64 = 2): String {
    "${value}:${width}"
}

main() {
    println(format(7, 4)) // width 是命名参数，不能按位置传递
}
```

问题说明：`width!` 在声明处表示命名参数，调用时必须写成 `width: value`；按位置传递会缺少编译器要求的参数标签。

修正代码：

```cangjie
func format(value: Int64, width!: Int64 = 2): String {
    "${value}:${width}"
}

main() {
    println(format(7, width: 4))
}
```

#### 诊断与修复

1. 将诊断中的实参位置、标签和类型与目标函数完整签名逐项对齐，同时检查是否因同名重载选择了另一签名。

2. 保留 API 原本的位置/命名语义，只修改错误调用；若要调整公共函数参数形式，先评估所有调用方和二进制兼容影响。DT 覆盖显式命名参数、默认值和错误类型边界。

3. 不通过增加大量重载来掩盖一次调用错误；只有不同调用语义确实构成稳定 API 时才新增重载。

### 6.2 返回类型、函数类型与 Lambda 推断

常见表现包括：声明返回 `Int64` 的函数最后得到 `Unit`、Lambda 各分支返回类型不一致、无上下文 Lambda 无法推断参数类型，或者把错误签名的函数传给高阶函数。

显式返回类型约束所有 `return` 和函数体最后一个表达式；`return` 本身类型为 `Nothing`。Lambda 不能显式声明返回类型，其参数和返回值从变量标注、函数形参或 Lambda 体推断。函数类型写作 `(ParamTypes) -> ReturnType`，参数位置逆变、返回位置协变，不能只比较函数名。

错误代码：

```cangjie
func render(value: Int64): String {
    println(value) // 最后一个表达式为 Unit，与 String 返回类型不匹配
}
```

问题说明：函数体最后一个表达式决定返回值，`println` 返回 `Unit`，不能满足显式声明的 `String` 返回类型。

修正代码：

```cangjie
func render(value: Int64): String {
    println(value)
    "value=${value}"
}
```

#### 诊断与修复

1. 写出上下文要求的完整函数类型，再检查 Lambda 参数、每条 `return`、每个分支最后表达式以及空函数体产生的 `Unit`。

2. 优先补充变量或形参的函数类型标注，避免给 Lambda 虚构返回类型语法。用正常分支、提前返回、空输入和异常分支验证所有返回路径。

3. 如果高阶 API 的真实契约未知，不用 `Any` 或宽泛 Lambda 消除诊断；先确定输入、输出和副作用边界。

### 6.3 重载歧义与闭包逃逸

常见表现包括：同名重载没有唯一最佳匹配、把重载函数直接赋给无类型变量，静态函数与实例函数同名，或者捕获局部 `var` 的闭包被返回、保存或传递。

有效重载依赖不同的参数数量或类型，返回类型和泛型约束本身不能独立区分重载。同一 class/interface/struct 中静态函数与实例函数不能同名。重载函数作为值时通常需要显式函数类型消除歧义。捕获局部 `var` 的闭包不能逃逸，只能在允许的当前位置直接调用；静态或全局 `var` 不属于这种局部捕获。

错误代码：

```cangjie
func convert(value: Int64): String { "number=${value}" }
func convert(value: String): String { "text=${value}" }

main() {
    let converter = convert // 缺少函数类型，无法确定选择哪个重载
    println(converter(7))
}
```

问题说明：`convert` 同时表示两个不同签名的重载，缺少上下文函数类型时，编译器无法选择要保存的函数值。

修正代码：

```cangjie
func convert(value: Int64): String { "number=${value}" }
func convert(value: String): String { "text=${value}" }

main() {
    let converter: (Int64) -> String = convert
    println(converter(7))
}
```

#### 诊断与修复

1. 收集当前作用域全部同名候选及其完整参数类型，确认歧义来自调用、函数值赋值、继承层次还是静态/实例冲突；闭包问题则列出每个捕获变量及其 `let/var` 状态。

2. 为函数值添加准确类型标注，或重命名语义不同的 API；闭包需要逃逸时改为捕获不可变快照、封装状态对象或调整生命周期。分别编译直接调用和函数值传递路径。

3. 不通过任意类型转换强行选择重载，也不把局部 `var` 搬成全局变量绕过逃逸限制。

---

## 7. class、struct 与 interface

### 7.1 struct 值语义与 mut 修改

常见表现包括：普通 struct 成员函数修改实例字段、`let` 结构体调用 `mut` 函数、被修改成员仍是 `let`，或者误以为结构体赋值后共享同一份值。

struct 是值类型，赋值和传参会复制结构体值；普通成员函数不能修改实例字段，需要声明 `mut func`。调用端持有结构体的变量必须是 `var`，被修改的字段也必须是 `var`。`mut` 只用于 interface、struct 和 struct 扩展，不能用于 class 或静态函数。

错误代码：

```cangjie
struct Counter {
    var value = 0

    public func increment() { // 缺少 mut
        value += 1
    }
}

main() {
    var counter = Counter()
    counter.increment()
    println(counter.value)
}
```

问题说明：struct 的普通成员函数以不可变接收者执行，即使字段声明为 `var`，没有 `mut` 的函数仍不能原地修改该字段。

修正代码：

```cangjie
struct Counter {
    var value = 0

    public mut func increment() {
        value += 1
    }
}

main() {
    var counter = Counter()
    counter.increment()
    println(counter.value)
}
```

#### 诊断与修复

1. 同时检查接收者变量、字段和函数的可变性，并确认调用发生在具体 struct 类型还是 interface 类型；接口变量可能持有结构体副本。

2. 只给实际修改状态的函数增加 `mut`，调用端只在需要原地修改时使用 `var`。DT 验证修改后的值、赋值副本不受影响以及 interface 调用是否符合预期。

3. 如果业务需要共享身份、继承或多个引用观察同一状态，先评估是否应使用 class，而不是继续扩大 struct 的可变范围。

### 7.2 接口与抽象成员实现契约

常见表现包括：类型声明实现接口但缺少成员、实现函数没有 `public`、参数或返回类型不匹配、struct 的 `mut` 与接口声明不同，或者非抽象子类没有实现抽象成员。

接口成员隐式为 `public`，实现者必须使用 `public`。函数名称、参数列表和返回类型需要匹配；接口返回 class 时，实现可以返回其子类。struct 实现 `mut` 接口函数时必须精确匹配 `mut`，class 实现时忽略接口上的 `mut`。非抽象子类必须实现继承的全部抽象成员。

错误代码：

```cangjie
interface Renderable {
    func render(): String
}

class Page <: Renderable {
    func render(): String { "page" } // 实现默认为 internal，弱于 public 接口成员
}
```

问题说明：接口成员隐式为 `public`，实现成员的可见性不能比接口契约更弱；默认的 `internal` 实现不满足该契约。

修正代码：

```cangjie
interface Renderable {
    func render(): String
}

class Page <: Renderable {
    public func render(): String { "page" }
}
```

#### 诊断与修复

1. 从诊断指出的类型出发，递归列出直接接口、父接口和抽象父类要求的成员，比较名称、参数标签、类型、`public`、`mut` 和泛型约束。

2. 按契约补齐最小成员或修正签名；多个接口提供同名默认实现发生冲突时，由实现类型提供自己的实现。以接口类型和具体类型两种调用方式编译运行 DT。

3. 不通过删除接口继承或把类型改成 abstract 隐藏未实现成员，除非设计本身确认该类型不应被实例化。

### 7.3 继承、override、redef 与构造链

常见表现包括：继承非 `open` 类、覆盖非 `open` 实例成员、用 `override` 处理静态函数、子类构造函数找不到父类无参构造，或者命名参数与父成员不一致。

class 采用单继承，父类必须为 `open` 或 `abstract`。实例函数的运行时多态使用重写，父成员须为 `open`，子类可写 `override`；静态函数是基于类型名的重定义，使用 `redef`。子类构造函数的第一个表达式可以是 `super(args)` 或 `this(args)`；都未写时编译器插入 `super()`，因此父类必须有可访问的无参构造函数。

错误代码：

```cangjie
open class Base {
    public func name(): String { "base" } // 成员本身没有 open
}

class Child <: Base {
    public override func name(): String { "child" }
}
```

问题说明：父类虽然允许继承，但 `name` 成员本身没有声明为 `open`，子类不能用 `override` 覆盖它。

修正代码：

```cangjie
open class Base {
    public open func name(): String { "base" }
}

class Child <: Base {
    public override func name(): String { "child" }
}
```

#### 诊断与修复

1. 记录父类/子类完整签名、成员是实例还是静态、`open` 状态、命名参数以及实际构造链，先区分重载、重写和重定义。

2. 需要动态分派时只开放目标实例成员并使用匹配签名；静态成员按类型名调用并使用重定义语义。为父类无参和有参构造路径分别编译测试。

3. 公共父类原本未开放扩展时，不为消除错误批量增加 `open`；这会扩大继承和安全边界，应先获得 API 设计确认。

---

## 8. match 与模式匹配

### 8.1 match 穷举与不可达分支

常见表现包括：枚举或 Option 的 `match` 缺少分支、非穷举枚举没有兜底、通配符位于具体模式之前导致后续分支不可达。

有匹配值的 `match` 必须覆盖所有可能值，否则编译失败。枚举应优先明确列出稳定构造器；非穷举枚举需要 `_` 或绑定模式兜底。分支自上而下匹配且没有穿透，提前出现的通配符或不可反驳绑定会覆盖后续分支。

错误代码：

```cangjie
func describe(value: ?Int64): String {
    match (value) {
        case Some(number) => "value=${number}"
        // 缺少 None 分支，match 不穷举
    }
}
```

问题说明：`?Int64` 可能是 `Some` 或 `None`，错误代码只覆盖了一个构造器，因此 `match` 不是穷举的。

修正代码：

```cangjie
func describe(value: ?Int64): String {
    match (value) {
        case Some(number) => "value=${number}"
        case None => "missing"
    }
}
```

#### 诊断与修复

1. 确认匹配值的准确静态类型、全部枚举构造器和分支顺序；不要只看到编译器要求穷举就立即添加 `_`。

2. 对业务已知的封闭枚举显式处理每个构造器；只有未来值或业务确实允许统一处理时使用兜底。DT 为每个构造器和兜底路径提供断言。

3. 新增 `_` 会掩盖未来枚举分支时，应保留显式穷举，让编译器帮助发现后续变更。

### 8.2 match/if 分支类型与 Unit

常见表现包括：把不同类型的 case 结果赋给明确类型变量、某个分支最后是 `println()` 导致 `Unit`，或者有分支只声明变量而没有返回结果。

有上下文类型时，每个 `match` 分支体必须是期望类型的子类型；没有上下文时取所有分支的最小公共父类型。分支最后一个表达式决定该分支的值，变量声明、函数声明或空分支产生 `Unit`。结果未被使用时，`match` 整体可以按 `Unit` 处理，但这不能证明各分支返回了业务值。

错误代码：

```cangjie
func describe(value: ?Int64): String {
    match (value) {
        case Some(number) => "value=${number}"
        case None => println("missing") // 此分支结果为 Unit
    }
}
```

问题说明：`Some` 分支产生 `String`，`None` 分支最后执行 `println` 并产生 `Unit`，两个分支无法满足函数声明的统一 `String` 结果。

修正代码：

```cangjie
func describe(value: ?Int64): String {
    match (value) {
        case Some(number) => "value=${number}"
        case None =>
            println("missing")
            "missing"
    }
}
```

#### 诊断与修复

1. 为每个 case 写出最后一个表达式及其类型，并标出上下文期望类型；同时检查提前 `return`/`throw` 的 `Nothing` 是否已正确终止路径。

2. 让各分支返回同一业务抽象，而不是统一转换成 `Any`。日志放在结果表达式之前，保证最后一项仍是期望值。DT 覆盖每个分支。

3. 如果分支本来只执行副作用，则把上下文明确为 `Unit`；不要制造无意义默认值迎合错误类型。

### 8.3 模式守卫、可反驳模式与绑定作用域

常见表现包括：在 `match` 守卫中写 `if` 而不是 `where`、在 `if-let` 中写 `where` 而不是 `&&`、把可反驳模式用于普通变量定义，或者在 `else` 中访问只在匹配成功分支绑定的变量。

`match` 模式守卫使用 `where BoolExpr`；`if`/`while` 条件匹配使用 `let pattern <- expression`，附加条件使用 `&&`。普通变量定义和 `for-in` 解构要求不可反驳模式。匹配产生的绑定只在对应 case、if 分支或循环体内可见；`||` 连接的条件模式不能引入变量绑定。

错误代码：

```cangjie
enum State { | Active(Int64) | Done }

func describe(state: State): String {
    match (state) {
        case Active(value) if value > 0 => "active" // match 守卫应使用 where
        case Active(_) => "inactive"
        case Done => "done"
    }
}
```

问题说明：仓颉的 `match` 模式守卫关键字是 `where`，不是其他语言常见的 `if`；错误关键字会在模式解析阶段失败。

修正代码：

```cangjie
enum State { | Active(Int64) | Done }

func describe(state: State): String {
    match (state) {
        case Active(value) where value > 0 => "active"
        case Active(_) => "inactive"
        case Done => "done"
    }
}
```

#### 诊断与修复

1. 确认当前语法位置是 match、if-let、while-let、普通变量定义还是 for-in，并判断模式是否可能失败以及绑定变量的合法作用域。

2. 按语法位置改用 `where` 或 `&&`，把可能失败的解构移动到 if-let/match 中；将依赖绑定值的代码留在成功分支。分别测试匹配与不匹配输入。

3. 不通过 `_` 丢弃业务需要的数据，也不把绑定变量复制到外层可变占位符绕过作用域错误。

---

## 9. cjpm 配置、依赖与构建上下文

### 9.1 package/workspace 与版本字段

常见表现包括：`cjpm.toml` 缺少必填字段、同时声明 `[package]` 和 `[workspace]`、`output-type` 与入口代码不匹配，或者当前 cjc 低于 `cjc-version` 要求。

单模块的 `[package]` 必须包含 `cjc-version`、`name`、`version` 和 `output-type`；`output-type` 使用 `executable`、`static` 或 `dynamic`。工作空间使用 `[workspace]` 和 `members`，与 `[package]` 互斥。`cjc-version` 表示项目要求的最低编译器版本，应按兼容性范围设置。

错误代码：

```toml
[package]
cjc-version = "1.0.5"
name = "demo"
version = "1.0.0"
output-type = "executable"

[workspace]
members = ["libs/core"] # [package] 与 [workspace] 不能同时存在
```

问题说明：同一个 `cjpm.toml` 只能描述单模块 package 或 workspace 根，两种顶层模型互斥；混写后 cjpm 无法确定当前配置角色。

修正代码：

```toml
[package]
cjc-version = "1.0.5"
name = "demo"
version = "1.0.0"
output-type = "executable"
```

#### 诊断与修复

1. 保存 cjpm 的第一条配置诊断，确认当前目录真正使用的 `cjpm.toml`、cjc 版本、项目是单模块还是 workspace，以及目标产物类型。

2. 只补齐或修正与失败直接相关的字段；版本不满足时切换到符合要求的 SDK，或在确认源码兼容后调整最低版本。重跑 `cjpm check` 和原始构建命令。

3. 调整 `cjc-version` 或 workspace/package 结构时，以项目兼容性要求和原工程构建结果作为验证依据。

### 9.2 依赖路径、循环依赖与锁文件

常见表现包括：本地依赖路径不存在、Git 依赖引用不可达、测试依赖放错节、间接依赖冲突、循环依赖，或者 `cjpm.toml` 已变更但锁文件仍指向旧版本。

普通依赖、测试依赖和构建脚本依赖分别位于 `[dependencies]`、`[test-dependencies]` 和 `[script-dependencies]`。本地 `path` 相对当前模块配置解析；Git 依赖选择优先级为 `commitId`、`branch`、`tag`。`cjpm tree` 展示实际加载的依赖树，`cjpm build` 会报告参与编译包之间的循环，`cjpm update` 根据配置更新锁文件。

错误代码：

```toml
# app/cjpm.toml
[dependencies]
core = { path = "../core" }
```

```toml
# core/cjpm.toml
[dependencies]
app = { path = "../app" } # app 与 core 形成循环依赖
```

```cangjie
// app/src/main.cj
package app
import core.*
```

```cangjie
// core/src/core.cj
package core
import app.*
```

问题说明：`app` 与 `core` 不仅在配置中互相声明依赖，源码也互相导入，使两个包同时进入实际编译图，`cjpm tree` 或 `cjpm build` 会报告 `core -> app -> core`。只有配置、源码没有加载反向包时，当前 SDK 可能不会报告循环；因此配置片段不能脱离 import 关系单独作为复现证据。删除缓存或锁文件不会消除已经激活的结构性环。

修正代码：

```toml
# app/cjpm.toml：上层应用依赖基础库
[dependencies]
core = { path = "../core" }
```

```toml
# core/cjpm.toml：删除对 app 的反向依赖
# core 需要的共享接口应移动到独立的 contracts 模块，或由 app 注入实现。
```

#### 诊断与修复

1. 保存配置、锁文件、依赖树和首条解析失败，逐个确认直接依赖来源、实际路径/引用及其输出类型；不要先删除整个锁文件或依赖缓存。

2. 修正最小依赖边、路径或固定版本；循环依赖通过提取共享包、反转接口依赖或移除多余 import 解决。运行 `cjpm check` 后重跑构建和受影响测试。

3. 远程访问、权限或私有仓库凭据缺失时明确外部阻塞，不把远程依赖替换成未经授权的本地实现。

### 9.3 单文件与项目构建、Profile 和子命令参数

常见表现包括：`cjc file.cj` 成功但 `cjpm build` 失败、测试文件只在 `cjpm test` 出错、构建脚本中止流程，或者把某个 cjpm 子命令的参数照搬给另一个子命令。

单文件编译不会自动复现项目的包图、依赖、Profile、条件编译、构建脚本和目标平台配置。`cjpm build`、`run`、`test`、`bench` 的选项集合不同，参数以当前 SDK 的 `cjpm <subcommand> --help` 为准。命令行、Profile、target 和 package-configuration 还可能对同一包产生不同编译选项。

错误代码：

```shell
# 把 test/bench 的参数照搬给 run；当前 SDK 的 run 不接受这些选项
cjpm run --no-color -i
```

问题说明：cjpm 各子命令的参数集合不同，`test` 或 `bench` 支持的选项不能推断为 `run` 也支持；错误命令在参数解析阶段就会停止。

修正代码：

```shell
# 先查看当前 SDK 的 run 选项，再使用 run 实际支持的参数
cjpm run --help
cjpm run
```

#### 诊断与修复

1. 保留原始子命令及工作目录，使用详细构建输出定位失败发生在依赖检查、build.cj、普通源码、测试源码、链接还是运行阶段。

2. 在不改变 Profile、target、member 和 cfg 的前提下做最小修复，重跑完全相同的原始命令；需要补充命令时先检查该子命令自身帮助。

3. 单文件验证只能证明局部语法/类型成立，不能替代真实 `cjpm build/test`；反过来也不要把运行期失败记成编译失败。

---

## 10. 诊断升级与编译器问题

### 10.1 首个根因与级联诊断

常见表现包括：一处语法或类型错误产生大量后续错误、Agent 从最后一条诊断开始批量修改，或者清理缓存后原始失败证据消失。

parser、名称解析和类型检查的早期错误可能让后续语法树或类型信息不完整，产生级联诊断。错误数量不等于独立根因数量。JSON 诊断适合保存稳定错误代码和源位置，但仍需要结合第一条用户源码诊断理解上下文。

错误代码：

```cangjie
func classify(value: Int64): String {
    if (value > 0) {
        return "positive"
    // 此处缺少结束 if 的右大括号，可能引发后续级联诊断
}

func next(value: Int64): Int64 { value + 1 }
```

问题说明：缺失的右大括号破坏了后续源码结构，编译器可能把 `next` 及之后的声明放进错误上下文，从而产生大量与真正首因无关的级联诊断。

修正代码：

```cangjie
func classify(value: Int64): String {
    if (value > 0) {
        "positive"
    } else {
        "non-positive"
    }
}

func next(value: Int64): Int64 { value + 1 }
```

#### 诊断与修复

1. 原样保存命令、退出码和从第一条开始的完整输出，按编译阶段和源位置聚类，先选择最早且能解释后续错误的一条作为假设。

2. 只修这一处后立即重跑原命令；若大量后续错误同时消失，记录为级联结果。若仍存在独立首因，再进入下一轮。

3. 未保存原始证据前不执行 `clean`、升级 SDK 或批量格式化；这些动作可能改变复现条件。

### 10.2 编译器崩溃、内部错误与最小复现

常见表现包括：cjc 无普通用户诊断便异常退出、打印 internal compiler error、收到信号或在相同源码上稳定崩溃。

编译器崩溃不应通过随机改写业务代码掩盖。首先确认退出来自 cjc 本身，而不是 cjpm、构建脚本、链接器、OOM killer 或运行生成产物。最小复现必须保留触发崩溃所需的包结构、编译选项、宏、泛型或目标平台条件。

错误代码：

```shell
# minimized.cj 必须由真实崩溃工程逐步裁剪得到；不存在通用的“崩溃源码”
cjc --diagnostic-format=json minimized.cj -o minimized
# 实际现象：cjc 无普通用户诊断便异常退出、收到信号或报告 internal compiler error
```

问题说明：编译器崩溃不是普通业务源码诊断，不能假定改写源码就是根本修复。必须保留真实 `minimized.cj`，再区分已验证的版本规避和编译器本身的修复。

修正代码：

```shell
# 仅当对照已证明上一版本可用时，才能把它记录为临时规避；minimized.cj 保持不变
/path/to/last-good-sdk/bin/cjc --diagnostic-format=json minimized.cj -o minimized

# 当前失败版本仍需携带最小复现、版本、target 和崩溃信息提交编译器问题
/path/to/failing-sdk/bin/cjc -v
```

#### 诊断与修复

1. 记录准确命令、工作目录、SDK 版本、target、退出状态、标准输出/错误和系统崩溃信息；先在不清理、不并行改动的同一环境复现两次。

2. 通过逐步删除无关声明和依赖缩小复现，同时每一步重跑相同命令。若最小源码仍稳定触发 cjc 崩溃，保留原项目复现和最小复现两份材料。

3. 没有普通源码修复依据时，不用语义改变绕过编译器缺陷；可以报告受影响版本、临时规避及其行为差异，但把根本问题升级为编译器缺陷。

### 10.3 SDK、target 与版本回归

常见表现包括：同一提交在另一台机器或升级后不能编译、`cjc` 与 `cjpm` 来自不同 SDK、目标三元组变化，或者只有 Debug/Release/特定 target 失败。

复现环境不仅包含语言版本，还包含 cjc/cjpm 实际路径、SDK 组件、target triple、构建 Profile、条件编译、标准库/扩展库和链接工具。版本回归结论应来自同一源码、同一命令和可控环境下的对照结果。

错误代码：

```shell
# PATH 中的 cjc 来自旧 SDK，调用的 cjpm 却来自另一套 SDK
export PATH="/opt/cangjie-1.0/bin:$PATH"
/opt/cangjie-1.1/bin/cjpm build
```

问题说明：进程实际解析到的 `cjc` 和 `cjpm` 不属于同一套 SDK，编译器、标准库和项目工具的版本契约可能互相冲突。

修正代码：

```shell
# 只加载一套 SDK，并确认两个命令都来自该 SDK
source /path/to/cangjie-1.1/envsetup.sh
command -v cjc
command -v cjpm
cjc -v
cjpm build
```

#### 诊断与修复

1. 记录实际解析到的 cjc/cjpm 路径、版本与 target，比较成功和失败环境的 SDK、环境变量、配置、锁文件和命令；检查是否混用了多个 SDK。

2. 在隔离环境中对最后成功版本和首个失败版本运行同一最小复现，确定是源码兼容变化、配置变化还是工具链回归。修复后回到目标 SDK 和真实项目复测。

3. 提交问题时包含最小源码、准确命令、期望/实际结果和版本区间；不得上传凭据、私有源码或未经脱敏的内部路径。

---

## 11. 完成门槛

- 原始失败命令返回成功；
- 首个根因诊断消失，且没有新增错误；
- 相关 DT 通过；
- 可用时运行 `cjfmt`/`cjlint`，不可用时明确记录；
- 汇报修改的最小范围和仍未验证的平台。
