# Bcrypt 集成说明

## 概述

本项目实现了基于 Blowfish 加密算法的 Bcrypt 密码哈希功能，与 backend 项目中使用的 bcryptjs 库保持兼容。

## 项目结构

```
blowfish-cj/
├── src/
│   ├── bcrypt.cj           # Bcrypt 核心实现
│   ├── bcrypt_test.cj      # Bcrypt 测试
│   ├── blowfish.cj         # Blowfish 加密算法
│   ├── const.cj            # 常量定义
│   └── util.cj             # 工具函数
├── test_bcryptjs_compatibility.js  # bcryptjs 兼容性测试数据生成器
└── cjpm.toml               # 项目配置

agentskills-runtime/
├── src/
│   ├── utils/
│   │   └── bcrypt_utils.cj  # 密码工具类
│   └── integration/
│       └── bcrypt_integration_test.cj  # 集成测试
└── cjpm.toml               # 已添加 blowfish 依赖
```

## 与 backend 项目的兼容性

### Backend 项目使用的算法

Backend 项目使用 `bcryptjs` 库（版本 3.0.3）：

```typescript
import * as bcrypt from 'bcryptjs';

// 生成哈希
const hash = await bcrypt.hash(password, 10);

// 验证密码
const isMatch = await bcrypt.compare(password, hash);
```

### 仓颉实现的使用方式

```cangjie
import blowfish.Bcrypt;

// 生成哈希
let hash = Bcrypt.hash(password, cost: 10);

// 验证密码
let isMatch = Bcrypt.verify(password, hash);
```

或使用工具类：

```cangjie
import magic.utils.PasswordUtils;

// 生成哈希
let hash = PasswordUtils.hashPassword(password);

// 验证密码
let isMatch = PasswordUtils.verifyPassword(password, hash);
```

## 验证兼容性

### 步骤 1: 生成 bcryptjs 测试数据

在 blowfish-cj 目录下运行：

```bash
cd apps/blowfish-cj
node test_bcryptjs_compatibility.js
```

这将生成一组测试数据，包括密码和对应的 bcryptjs 生成的哈希。

### 步骤 2: 运行仓颉测试

编译并运行 bcrypt_test.cj：

```bash
cjpm build
cjpm run
```

### 步骤 3: 比较结果

确保仓颉实现能够：
1. 正确验证 bcryptjs 生成的哈希
2. 生成的哈希能被 bcryptjs 正确验证
3. 使用相同的 cost 因子生成相同格式的哈希

## Bcrypt 格式说明

Bcrypt 哈希格式：`$2a$cost$salt$hash`

示例：`$2a$10$N9qo8uLOickgx2ZMRNOo.YeIjZPsN.XuKQXqKSLqKqKqKqKqKqKqKqKqKqKqKqKqK`

- `$2a$`: 版本标识（支持 2a, 2b, 2y）
- `10`: cost 因子（迭代次数为 2^10 = 1024）
- `N9qo8uLOickgx2ZMRNOo.`: 16 字节盐的 base64 编码（22 字符）
- `YeIjZPsN.XuKQXqKSLqKqKqKqKqKqKqKqKqKqKqKqK`: 23 字节哈希的 base64 编码（31 字符）

## Cost 因子说明

- **默认值**: 10（与 backend 项目保持一致）
- **范围**: 4-31
- **建议**:
  - 开发环境: 4-6（快速）
  - 生产环境: 10-12（安全）
  - 高安全: 14-16（非常慢）

## 性能考虑

Bcrypt 的设计目标是"慢"，以抵抗暴力破解：

| Cost | 迭代次数 | 大约时间 |
|------|---------|---------|
| 4    | 16      | < 1ms   |
| 10   | 1024    | ~100ms  |
| 12   | 4096    | ~400ms  |
| 14   | 16384   | ~1.5s   |

## 安全注意事项

1. **常量时间比较**: 实现使用常量时间比较，防止时序攻击
2. **盐值**: 每次生成哈希都使用随机盐值
3. **密码长度**: bcrypt 最多处理 72 字节的密码
4. **Unicode**: 密码使用 UTF-8 编码

## 集成到 agentskills-runtime

已在 `agentskills-runtime/cjpm.toml` 中添加依赖：

```toml
[dependencies]
  blowfish = { path = "../blowfish-cj" }
```

使用方式：

```cangjie
import magic.utils.PasswordUtils;

// 用户注册时
let hashedPassword = PasswordUtils.hashPassword(plainPassword);

// 用户登录时
let isValid = PasswordUtils.verifyPassword(plainPassword, storedHash);
```

## 测试清单

- [x] 基本功能测试（生成哈希、验证密码）
- [x] 错误密码验证测试
- [x] 不同 cost 因子测试
- [x] 空密码测试
- [x] 长密码测试
- [x] 特殊字符密码测试
- [x] Unicode 密码测试
- [ ] bcryptjs 兼容性测试（需要运行 Node.js 脚本生成测试数据）
- [ ] 性能测试

## 下一步

1. 运行 `test_bcryptjs_compatibility.js` 生成测试数据
2. 使用生成的测试数据更新 `bcrypt_test.cj`
3. 编译并运行测试，验证与 bcryptjs 的兼容性
4. 在 agentskills-runtime 中集成测试
5. 在实际应用中测试用户注册和登录流程

## 参考文档

- [Bcryptjs GitHub](https://github.com/dcodeIO/bcrypt.js)
- [Bcrypt Wikipedia](https://en.wikipedia.org/wiki/Bcrypt)
- [Blowfish Cipher](https://en.wikipedia.org/wiki/Blowfish_(cipher))
