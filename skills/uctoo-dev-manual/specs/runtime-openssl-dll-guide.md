# Runtime 构建环境：OpenSSL DLL 版本不匹配（表现为登录 401）

> 适用范围：在**自己机器上搭建 runtime 开发环境**（Windows）时登录接口返回 401。
> 本文结论全部来自源码/二进制实测，未使用推测。改动落到 `apps/agentskills-runtime`。

## 1. 症状

- 前端点登录 → **401 Unauthorized**，提示「帐号密码错误」之类的鉴权失败文案。
- 但后端日志里登录Success：查 `login_log.status`（0 失败 / 1 成功）能看到该次登录**记为成功**。
- 少数环境表现为「有时能登进去，有时 401」（取决于系统 PATH 里先找到哪个 OpenSSL）。
- 换新机器/新系统（自带 OpenSSL 4.x）复现率高；老机器上装过 OpenSSL 3.x 的环境反而正常。

## 2. 根因链（5 步，缺一不可）

| # | 环节 | 实际行为 |
|---|---|---|
| 1 | `src/app/utils/auth/JWTUtil.cj:34` `generateAccessToken` | 调 `JWT.create()...sign(Algorithm.HMAC256(secretKey))` 生成 token |
| 2 | `libs/jwt4cj/src/hmac_algorithm.cj:87/99` | HMAC 走 **stdx crypto**：`HMAC(privateKey, HashType.SHA256)`，jwt4cj 自己不带 openssl |
| 3 | stdx `libcangjie-dynamicLoader-opensslFFI.dll` | 内部 dlopen **`libcrypto-3-x64.dll` / `libssl-3-x64.dll`**，**版本号 3 和 `-x64` 都写死在二进制里** |
| 4 | 系统里只有 OpenSSL 4.x | 只有 `libcrypto-4-x64.dll`，加载器找 `libcrypto-3-x64.dll` → 找不到 → `SHA256_Init` 符号解析失败抛异常 |
| 5 | `JWTUtil.cj:50-53` `catch (e: Exception)` | 异常被吞，**返回空字符串 `""`** → 前端拿到空 token → `DeserializeUserMiddleware` 验不出来 → `RequirePermissionMiddleware` 401 |

**关键设计缺陷不在 openssl，在第 5 步**：加密库加载失败被压成了「认证失败」，
排查方向被彻底带偏（先怀疑密码、session、前端，最后才想到 DLL）。

## 3. 实证：`-x64` 这个文件名后缀才是要害

- `libs/cangjie-stdx-windows-x64-*` **每个版本**的 `dynamicLoader-opensslFFI.dll` 都硬编码 `libcrypto-3-x64.dll`
  （下表是字符串在二进制里的**字节偏移**——PE 文件没有"行"的概念，`grep -a -n` 报的其实也是偏移，不是行号）：

  | stdx 版本 | 文件 | 字节偏移 |
  |---|---|---|
  | 1.0.0.1 | `windows_x86_64_llvm/dynamic/stdx/libcangjie-dynamicLoader-opensslFFI.dll` | 59024 |
  | 1.0.5.1 | `windows_x86_64_cjnative/dynamic/stdx/libcangjie-dynamicLoader-opensslFFI.dll` | 79944 |
  | 1.1.3.1 | `windows_x86_64_cjnative/dynamic/stdx/libcangjie-dynamicLoader-opensslFFI.dll` | 126720 |
  | 1.0.0.1 | `windows_x86_64_llvm/static/stdx/libcangjie-dynamicLoader-opensslFFI.a` | 69850 |
  | 1.0.5.1 | `windows_x86_64_cjnative/static/stdx/libcangjie-dynamicLoader-opensslFFI.a` | 127520 |
  | 1.1.3.1 | `windows_x86_64_cjnative/static/stdx/libcangjie-dynamicLoader-opensslFFI.a` | 271674 |

- 上下文证据：1.1.3.1 的该字符串紧跟在 OpenSSL 符号名之后
  （`... BN_mod_exp\x00 BN_bn2binpad\x00 BN_CTX_free\x00 libcrypto-3-x64.dll\x00`），
  说明它位于 **PE 导入表里、是 `LoadLibrary` 的目标名**，不是可配置的字符串常量。
- 复现命令：`grep -a -o "libcrypto-[0-9]-x64\.dll" libs/cangjie-stdx-windows-x64-1.1.3.1/windows_x86_64_cjnative/dynamic/stdx/libcangjie-dynamicLoader-opensslFFI.dll`
- stdx 包内**不含**任何 `libcrypto*.dll`（只有 FFI 加载器），所以只能从 exe 目录或 PATH 找。
- runtime `target/release/bin/` 里**有** `libcrypto-3.dll`（无 `-x64`），实测：
  - 版本 **OpenSSL 3.0.13**，导出 `SHA256_Init`
  - md5 `e547cf6d296a88f5b1c352c116df7c0c`
  - 与 cjc SDK 自带那份 `Cangjie/tools/bin/libcrypto-3.dll` **完全相同**（cjc 自动拷进来的）
- ⇒ **文件就在那儿、版本也对，但名字少一个 `-x64`，加载器根本不看它**，转头去系统 PATH 找 3.x，
  找到 4.x 或找不到都失败。

社区用户上报的修复方式（把系统 DLL 复制并重命名为 3.x 放进 runtime bin）验证了这一判断。

## 4. 修复方案（按推荐度排序）

### 方案 A：自带 OpenSSL 3.x（推荐，系统装什么都行）

把 runtime **自己那份** `libcrypto-3.dll` 复制一份、改名为加载器要的名字，放进 exe 目录。

```bash
# 开发态（target/release/bin/ 为 cjpm run 的 exe 目录）
cp target/release/libcrypto-3.dll target/release/bin/libcrypto-3-x64.dll
cp target/release/libssl-3.dll     target/release/bin/libssl-3-x64.dll
```

- 用的是 **cjc SDK 自带的 3.0.13**，ABI 一定匹配 `SHA256_Init`，不需要额外下载任何东西。
- Windows DLL 搜索顺序里 **exe 所在目录优先于 PATH**，所以自带这份永远命中，用户系统装 3.x / 4.x / 没装都不影响。
- 这是「runtime 自带依赖」而非「支持多版本」：加载器只认一个名字，我们能做的是**保证那个名字的文件一定在**。

### 方案 B：发布包固化（防复发，OSS 用户零操作）

`src/scripts/package_release/main.cj` 第 816 步「Copying LLVM/MinGW runtime DLLs to bin and release root」
会拷 `tools/bin` 下的 DLL 到 bin，但**保持原名**（仍是 `libcrypto-3.dll`）。需在该步之后追加一步：
把 `bin/libcrypto-3.dll` / `bin/libssl-3.dll` 各复制一份为 `*-3-x64.dll`。

改完必须人工编译验证（AI 不执行 `cjpm build`）。

### 方案 C：临时绕过（不推荐长期用）

把系统里现有的 `libcrypto-4-x64.dll` 复制重命名为 `libcrypto-3-x64.dll` 放进 bin。能跑，但
拿 4.x 冒充 3.x 属于掩盖问题，且换机器要重做一遍；除非只是想先确认是不是这个原因。

## 5. 排查顺序（以后 401 先看这条）

1. **先查库**：`login_log.status` —— 是 1（成功）就说明认证逻辑本身没问题，问题在 token 签发/校验环节。
2. **看日志有没有 `generateAccessToken failed`**：有就是方案第 5 步的静默异常，下一步必查 openssl。
3. **看 bin 目录文件名**：
   ```bash
   ls target/release/bin/ | grep -i "crypto\|ssl"
   # 必须同时存在 libcrypto-3-x64.dll 与 libssl-3-x64.dll（注意 -x64）
   ```
   只有 `libcrypto-3.dll`（无后缀）→ 命中本文问题。
4. 系统里装的是哪个版本：
   ```bash
   where libcrypto-3-x64.dll libcrypto    # PATH 里有没有
   openssl version                        # Windows 上多半没有，看环境变量/软件列表
   ```
5. 确认 DLL 真身版本（避免拿错文件）：
   ```bash
   grep -a -o "OpenSSL 3\.[0-9.]*" target/release/bin/libcrypto-3.dll
   ```

## 6. 防回退

| 做了什么 | 必须连带检查 |
|---|---|
| 改 `JWTUtil` 让加密库异常可见 | 仍走 `cjpm build`，人工确认日志里能看到完整 `e.message` |
| 在 `package_release` 加重命名步骤 | 出包后开箱验证：新机器（无 OpenSSL 3.x）能登录 |
| 写进本文 | 换 stdx 版本时重查 `opensslFFI.dll` 里硬编码的文件名是否变了（grep `libcrypto-[0-9]-x64`） |

## 7. 一句话总结

> **不是密码错、不是 session 错，是 CRC/加密库 DLL 文件名对不上。**
> `libcrypto-3.dll` 和 `libcrypto-3-x64.dll` 在加载器眼里是两个文件；
> runtime 已经带了正确的 OpenSSL 3.0.13，缺的只是那个 `-x64` 名字。

## 8. 已向仓颉官方反馈（stdx 侧）

根治点在 stdx，不在 runtime。已提交反馈，草稿与提交链接见
[`docs/cangjie-stdx-openssl-dll-issue.md`](../../../../docs/cangjie-stdx-openssl-dll-issue.md)。

**提交位置**：仓颂扩展标准库 `cangjie_stdx`（Windows 预编译包 source of truth 就在这里）。

**为什么值得报（不是我们项目自己的问题）**：

- 影响面是**全局**的：`libstdx.crypto.crypto` / `.digest` / `.keys` / `.keysFFI`
  全部经由 `libcangjie-dynamicLoader-opensslFFI` 加载，任何 Windows 上用 stdx crypto 的仓颉程序都会中招。
- 三个 stdx 版本（1.0.0.1 / 1.0.5.1 / 1.1.3.1）**无一例外**都硬编码 3.x 文件名，
  且包内不携带 libcrypto/libssl ⇒ 用户环境只要装了 OpenSSL 4.x（2026-04 已发布，沿用
  `libcrypto-4-x64.dll` 命名）就 100% 复现。
- cjc SDK 自己自带 `libcrypto-3.dll`（无 `-x64`），与加载器期望的名字对不上——
  说明打包侧本身就存在不一致，不只是"用户环境没装"。

**官方侧可取的修复（按性价比排序）**：详见 issue 草稿第 5 节，核心两条是
① Windows 的 stdx 包随包携带 `libcrypto-3-x64.dll` + `libssl-3-x64.dll`（自 vendor，彻底解耦系统）；
② 加载失败时抛带上下文的异常，而不是让调用方 catch 成空 token。

**跟进提醒**：换 stdx 版本时重查一遍 `opensslFFI.dll` 里硬编码的文件名，
万一官方改了（例如改回无 `-x64`、或改成带版本探测），本文与 runtime 的
`package_release` 重命名步骤都要跟着调。
