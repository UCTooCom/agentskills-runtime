## 类

### `public class Blowfish <: BlockCipher`

#### 构造函数 (Initializers)

*   `public init(key: Array<Byte>)`
    *   使用给定的密钥初始化 Blowfish 密码实例。
    *   **参数:**
        *   `key`: `Array<Byte>` - 密钥字节数组，长度必须在 1 到 56 字节之间。
    *   **抛出:** `KeySizeException` - 如果密钥长度无效。

*   `public init(key: Array<Byte>, salt: Array<Byte>)`
    *   使用给定的密钥和 Salt 初始化 Blowfish 密码实例。
    *   如果 `salt` 为空，则行为与 `init(key: Array<Byte>)` 相同（密钥长度 1-56 字节）。
    *   如果 `salt` 不为空，则使用密钥和 Salt 进行密钥扩展，此时密钥长度至少为 1 字节。
    *   **参数:**
        *   `key`: `Array<Byte>` - 密钥字节数组。
        *   `salt`: `Array<Byte>` - Salt 字节数组。
    *   **抛出:** `KeySizeException` - 如果密钥长度无效。

#### 属性 (Properties)

*   `public prop blockSize: Int64 { get }`
    *   返回算法的分组大小（字节）。对于 Blowfish，始终为 `8`。
*   `public prop algorithm: String { get }`
    *   返回算法的名称。对于此实现，始终为 `"blowfish"`。

#### 方法 (Methods)

*   `public func encrypt(input: Array<Byte>): Array<Byte>`
    *   加密单个 8 字节的数据块。
    *   **参数:**
        *   `input`: `Array<Byte>` - 长度必须为 8 字节的明文数据块。
    *   **返回:** `Array<Byte>` - 包含 8 字节加密结果的新数组。
    *   **抛出:** `IllegalArgumentException` - 如果输入块大小不是 8 字节。

*   `public func decrypt(input: Array<Byte>): Array<Byte>`
    *   解密单个 8 字节的数据块。
    *   **参数:**
        *   `input`: `Array<Byte>` - 长度必须为 8 字节的密文数据块。
    *   **返回:** `Array<Byte>` - 包含 8 字节解密结果的新数组。
    *   **抛出:** `IllegalArgumentException` - 如果输入块大小不是 8 字节。

*   `public func encrypt(input: Array<Byte>, to!: Array<Byte>): Int64`
    *   加密单个 8 字节的数据块，并将结果写入提供的目标数组。
    *   **参数:**
        *   `input`: `Array<Byte>` - 长度必须为 8 字节的明文数据块。
        *   `to`: `Array<Byte>` - 长度必须为 8 字节的预分配数组，用于存储加密结果。
    *   **返回:** `Int64` - 成功加密的字节数（始终为 8）。
    *   **抛出:** `IllegalArgumentException` - 如果输入或目标块大小不是 8 字节。

*   `public func decrypt(input: Array<Byte>, to!: Array<Byte>): Int64`
    *   解密单个 8 字节的数据块，并将结果写入提供的目标数组。
    *   **参数:**
        *   `input`: `Array<Byte>` - 长度必须为 8 字节的密文数据块。
        *   `to`: `Array<Byte>` - 长度必须为 8 字节的预分配数组，用于存储解密结果。
    *   **返回:** `Int64` - 成功解密的字节数（始终为 8）。
    *   **抛出:** `IllegalArgumentException` - 如果输入或目标块大小不是 8 字节。

## 异常

### `public class KeySizeException <: Exception`

当提供的 Blowfish 密钥长度无效时抛出此异常。

#### 构造函数 (Initializer)

*   `public init(keySize: Int64)`
    *   创建一个新的 `KeySizeException` 实例。
    *   **参数:**
        *   `keySize`: `Int64` - 导致异常的无效密钥大小（以字节为单位）。
    *   **异常消息:** 异常实例将包含一个描述性消息，格式为 `"Invalid key size: ${keySize}"`，其中 `{keySize}` 是传入的无效密钥大小。