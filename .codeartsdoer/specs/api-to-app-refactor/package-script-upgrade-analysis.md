# 打包脚本升级分析报告

## 当前状态分析

### 当前打包脚本处理的依赖

根据 `src/scripts/package_release/main.cj` 分析，当前脚本只处理以下依赖：

1. **magic** - 主模块 DLL
2. **commonmark4cj** - Markdown 解析器
3. **yaml4cj** - YAML 解析器
4. **cangjie-stdx** - 仓颉扩展库
5. **cangjie runtime** - 仓颉运行时库

### cjpm.toml 中的实际依赖

```toml
[dependencies]
  yaml4cj = { path = "./libs/yaml4cj" }
  commonmark4cj = { path = "./libs/commonmark4cj" }
  f_orm = { path = "../fountain/f_orm" }                    # ❌ 缺失
  charset4cj = { git = "https://gitcode.com/Cangjie-TPC/charset4cj.git", branch = "develop", compile-option = "-Woff unused" }  # ❌ 缺失
  jwt4cj = { path = "../CangjieMagic/resource/TPC/jwt4cj" }  # ❌ 缺失
  logcj = { path = "../CangjieMagic/resource/TPC/log-cj" }   # ❌ 缺失
```

### 缺失的依赖

| 依赖名称 | 路径 | 用途 | 影响 |
|---------|------|------|------|
| **f_orm** | `../fountain/f_orm` | ORM 数据库框架 | 数据库操作功能无法使用 |
| **charset4cj** | Git 依赖 | 字符编码转换 | 字符编码处理功能无法使用 |
| **jwt4cj** | `../CangjieMagic/resource/TPC/jwt4cj` | JWT 认证 | 认证功能无法使用 |
| **logcj** | `../CangjieMagic/resource/TPC/log-cj` | 日志库 | 日志功能无法使用 |

## 问题影响

### 运行时错误

如果打包脚本不更新，发布后的 runtime 将缺少以下 DLL：

1. **libf_orm.dll / f_orm.so** - ORM 库
2. **libcharset4cj.dll / charset4cj.so** - 字符编码库
3. **libjwt4cj.dll / jwt4cj.so** - JWT 库
4. **liblogcj.dll / logcj.so** - 日志库

### 功能缺失

- ❌ 数据库连接和操作（EntityService, DatabaseConnectionPool）
- ❌ 字符编码转换（多语言支持）
- ❌ JWT 认证（API 认证）
- ❌ 结构化日志（LogUtils）

## 升级方案

### 方案一：硬编码路径（推荐）

在打包脚本中添加新的依赖复制步骤。

#### 优点
- 简单直接
- 易于理解和维护
- 与现有代码风格一致

#### 缺点
- 需要手动维护路径
- 路径变更时需要更新脚本

#### 实现代码

在 `main.cj` 中添加以下步骤（插入在 line 280 之后）：

```cangjie
    println("")
    println("[STEP] Copying f_orm DLLs to bin...")
    
    let fOrmDir = Path("${targetDir}/f_orm")
    if (exists(fOrmDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(fOrmDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    if (!exists(destPath)) {
                        copy(fileInfo.path.toString(), to: destPath.toString(), overwrite: false)
                        dllCount.add(name)
                        totalDlls.add(name)
                    }
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} f_orm DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${fOrmDir}")
    }
    
    println("")
    println("[STEP] Copying charset4cj DLLs to bin...")
    
    let charsetDir = Path("${targetDir}/charset4cj")
    if (exists(charsetDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(charsetDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    if (!exists(destPath)) {
                        copy(fileInfo.path.toString(), to: destPath.toString(), overwrite: false)
                        dllCount.add(name)
                        totalDlls.add(name)
                    }
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} charset4cj DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${charsetDir}")
    }
    
    println("")
    println("[STEP] Copying jwt4cj DLLs to bin...")
    
    let jwtDir = Path("${targetDir}/jwt4cj")
    if (exists(jwtDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(jwtDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    if (!exists(destPath)) {
                        copy(fileInfo.path.toString(), to: destPath.toString(), overwrite: false)
                        dllCount.add(name)
                        totalDlls.add(name)
                    }
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} jwt4cj DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${jwtDir}")
    }
    
    println("")
    println("[STEP] Copying logcj DLLs to bin...")
    
    let logDir = Path("${targetDir}/logcj")
    if (exists(logDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(logDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    if (!exists(destPath)) {
                        copy(fileInfo.path.toString(), to: destPath.toString(), overwrite: false)
                        dllCount.add(name)
                        totalDlls.add(name)
                    }
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} logcj DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${logDir}")
    }
```

### 方案二：动态解析 cjpm.toml（更优雅）

从 cjpm.toml 动态解析依赖列表，自动复制所有依赖的 DLL。

#### 优点
- 自动化程度高
- 新增依赖时无需修改脚本
- 更健壮和可维护

#### 缺点
- 实现复杂度较高
- 需要解析 TOML 格式

#### 实现思路

```cangjie
func parseDependencies(cjpmPath: Path): ArrayList<String> {
    // 解析 cjpm.toml 中的 [dependencies] 部分
    // 返回依赖名称列表
}

func copyDependencyDLLs(depName: String, targetDir: Path, binDir: Path, totalDlls: ArrayList<String>) {
    // 通用的依赖 DLL 复制函数
}

// 在 main 函数中
let dependencies = parseDependencies(cjpmPath)
for (dep in dependencies) {
    copyDependencyDLLs(dep, targetDir, binDir, totalDlls)
}
```

### 方案三：使用 cjpm 命令（最简单）

利用 cjpm 提供的命令来获取依赖信息。

#### 优点
- 最简单
- 官方支持
- 自动处理所有依赖

#### 缺点
- 依赖 cjpm 命令
- 可能不支持所有平台

#### 实现思路

```bash
# 使用 cjpm 命令获取依赖列表
cjpm deps --list

# 或者直接复制 target 目录下的所有 DLL
find target/release -name "*.dll" -exec cp {} target/release/bin/ \;
```

## 推荐方案

**推荐使用方案一（硬编码路径）**，原因：

1. **简单可靠** - 与现有代码风格一致
2. **易于调试** - 每个依赖单独处理，日志清晰
3. **快速实现** - 可以立即解决问题
4. **向后兼容** - 不影响现有功能

后续可以考虑升级到方案二（动态解析），但方案一足以解决当前问题。

## 实施步骤

### 1. 更新打包脚本

在 `src/scripts/package_release/main.cj` 中添加新的依赖复制步骤。

### 2. 更新输出信息

在最后的目录结构说明中添加新的依赖：

```cangjie
    println("Directory structure in archive:")
    println("  release/")
    println("    bin/              - Executables and ALL DLLs")
    println("    magic/            - Runtime modules")
    println("    commonmark4cj/    - Markdown parser")
    println("    yaml4cj/          - YAML parser")
    println("    f_orm/            - ORM database framework")        // 新增
    println("    charset4cj/       - Character encoding library")   // 新增
    println("    jwt4cj/           - JWT authentication library")   // 新增
    println("    logcj/            - Logging library")              // 新增
    println("    VERSION           - Version info")
    println("    .env.example      - Configuration template")
```

### 3. 测试验证

```bash
# 1. 编译项目
cjpm build

# 2. 运行打包脚本
cjpm run --name magic.scripts.package_release

# 3. 验证打包结果
tar -tzf release/agentskills-runtime-win-x64.tar.gz | grep -E "(f_orm|charset4cj|jwt4cj|logcj)"

# 4. 测试运行
cd release
tar -xzf ../agentskills-runtime-win-x64.tar.gz
./bin/agentskills-runtime.exe 8080
```

### 4. 检查 DLL 完整性

打包完成后，检查 bin 目录下是否包含所有必需的 DLL：

```bash
# Windows
dir release\bin\*.dll | findstr /I "f_orm charset4cj jwt4cj logcj"

# Linux
ls -la release/bin/*.so | grep -E "(f_orm|charset4cj|jwt4cj|logcj)"
```

## 风险评估

### 低风险
- ✅ 新增依赖复制步骤不影响现有功能
- ✅ 如果依赖不存在，只会打印警告，不会中断打包

### 中等风险
- ⚠️ Git 依赖（charset4cj）可能需要特殊处理
- ⚠️ 跨平台路径可能需要调整

### 缓解措施
1. 添加详细的日志输出
2. 对每个依赖进行存在性检查
3. 提供回退机制（如果依赖不存在，打印警告但继续）

## 后续优化

1. **动态依赖解析** - 实现方案二，自动解析 cjpm.toml
2. **依赖版本检查** - 验证依赖版本是否匹配
3. **依赖完整性检查** - 打包后验证所有依赖是否完整
4. **跨平台支持** - 测试 Linux、macOS 打包

## 总结

**必须更新打包脚本**，否则发布的 runtime 将缺少关键依赖，导致以下功能无法使用：

- ❌ 数据库操作（f_orm）
- ❌ 字符编码转换（charset4cj）
- ❌ JWT 认证（jwt4cj）
- ❌ 日志功能（logcj）

建议立即实施方案一，确保 runtime 功能完整。
