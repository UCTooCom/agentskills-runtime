# AgentSkills Runtime 发布指南

本文档描述 AgentSkills Runtime 的完整发布流程。

## 目录

- [环境准备](#环境准备)
- [版本更新](#版本更新)
- [构建与打包](#构建与打包)
- [发布到 AtomGit](#发布到-atomgit)
- [发布 JavaScript SDK](#发布-javascript-sdk)
- [常见问题](#常见问题)

## 环境准备

### 必需工具

1. **仓颉编程语言环境**
   ```bash
   cjpm --version
   ```

2. **Node.js 环境** (用于 SDK 发布)
   ```bash
   node --version  # >= 18.0.0
   pnpm --version
   ```

3. **AtomGit 访问令牌**
   
   在 `apps/backend/.env` 文件中配置：
   ```
   ATOMGIT_ACCESS_TOKEN=your_access_token_here
   ```

### 获取 AtomGit 访问令牌

1. 登录 [AtomGit](https://atomgit.com)
2. 进入个人设置 -> 访问令牌
3. 创建新令牌，选择 `repo` 权限
4. 将令牌配置到 `.env` 文件中

## 版本更新

### 1. 更新 cjpm.toml 版本号

编辑 `apps/agentskills-runtime/cjpm.toml`：

```toml
[package]
  version = "0.0.9"  # 更新为新版本号
```

### 2. 更新 CHANGELOG

在 `apps/agentskills-runtime/temp/release_body.md` 中准备发布说明：

```markdown
## AgentSkills Runtime vX.X.X

### 新功能
- 功能描述...

### 改进
- 改进描述...

### 修复
- 修复描述...

### 下载
- Windows x64: agentskills-runtime-win-x64.tar.gz

### 安装使用
\`\`\`bash
npm install @opencangjie/skills
npx skills install-runtime
npx skills start
\`\`\`
```

## 构建与打包

### 1. 构建项目

```bash
cd apps/agentskills-runtime
cjpm build
```

### 2. 运行打包脚本

打包脚本会自动：
- 从 `cjpm.toml` 读取版本号
- 检测当前操作系统和架构
- 复制所有必要的 DLL 文件
- 创建发布包

```bash
cjpm run --name magic.scripts.package_release
```

### 3. 验证打包结果

打包完成后，检查 `release/` 目录：

```
release/
├── agentskills-runtime-win-x64.tar.gz    # Windows 发布包
└── .env.example                           # 环境变量配置模板
```

### 4. 发布附件命名规范

**重要**：附件文件名必须遵循以下格式，以便 SDK 能够正确下载：

```
agentskills-runtime-{platform}-{arch}.tar.gz
```

例如：
- Windows x64: `agentskills-runtime-win-x64.tar.gz`
- macOS x64: `agentskills-runtime-darwin-x64.tar.gz`
- macOS arm64: `agentskills-runtime-darwin-arm64.tar.gz`
- Linux x64: `agentskills-runtime-linux-x64.tar.gz`

下载 URL 格式：
```
https://atomgit.com/{owner}/{repo}/releases/download/v{version}/agentskills-runtime-{platform}-{arch}.tar.gz
```

例如：
```
https://atomgit.com/UCToo/agentskills-runtime/releases/download/v0.0.9/agentskills-runtime-win-x64.tar.gz
```

## 发布到 AtomGit

### 使用 atomgit.ts 命令行工具

AtomGit CLI 工具位于 `apps/backend/src/app/helpers/atomgit.ts`。

#### 查看帮助

```bash
cd apps/backend
npx tsx src/app/helpers/atomgit.ts help
```

#### 创建发布

**重要**：对于多行发布说明，请使用 `--body-file` 参数从文件读取内容，避免命令行解析问题。

```bash
npx tsx src/app/helpers/atomgit.ts release create \
  --owner uctoo \
  --repo agentskills-runtime \
  --tag v0.0.9 \
  --name "AgentSkills Runtime v0.0.9" \
  --body-file "D:\path\to\release_body.md"
```

或使用简短的 body 参数：

```bash
npx tsx src/app/helpers/atomgit.ts release create \
  --owner uctoo \
  --repo agentskills-runtime \
  --tag v0.0.9 \
  --name "AgentSkills Runtime v0.0.9" \
  --body "发布说明内容..."
```

#### 上传附件

```bash
npx tsx src/app/helpers/atomgit.ts release upload \
  --owner uctoo \
  --repo agentskills-runtime \
  --tag v0.0.9 \
  --file "D:\path\to\agentskills-runtime-win-x64.tar.gz"
```

#### 一键发布（创建发布并上传附件）

```bash
npx tsx src/app/helpers/atomgit.ts publish \
  --owner uctoo \
  --repo agentskills-runtime \
  --tag v0.0.9 \
  --name "AgentSkills Runtime v0.0.9" \
  --body "发布说明内容..." \
  --assets "D:\path\to\agentskills-runtime-win-x64.tar.gz"
```

#### 查看发布列表

```bash
npx tsx src/app/helpers/atomgit.ts release list \
  --owner uctoo \
  --repo agentskills-runtime
```

#### 查看最新发布

```bash
npx tsx src/app/helpers/atomgit.ts release latest \
  --owner uctoo \
  --repo agentskills-runtime
```

### AtomGit CLI 命令参考

| 命令 | 说明 |
|------|------|
| `config` | 配置 CLI（token、owner、repo） |
| `auth token` | OAuth 认证获取令牌 |
| `release create` | 创建新发布 |
| `release update` | 更新已有发布 |
| `release list` | 列出所有发布 |
| `release get` | 获取发布详情 |
| `release latest` | 获取最新发布 |
| `release upload` | 上传附件到发布 |
| `release download` | 从发布下载附件 |
| `publish` | 一键发布（创建+上传） |

## 发布 JavaScript SDK

### 1. 更新 SDK 版本号

编辑 `apps/agentskills-runtime/sdk/javascript/package.json`：

```json
{
  "name": "@opencangjie/skills",
  "version": "0.0.27"
}
```

### 2. 构建 SDK

```bash
cd apps/agentskills-runtime/sdk/javascript
pnpm install
pnpm build
```

### 3. 发布到 npm

```bash
npm login
npm publish --access public
```

### 4. 验证发布

```bash
npm view @opencangjie/skills version
```

## 完整发布流程示例

以下是一个完整的发布流程示例：

```bash
# 1. 更新版本号
# 编辑 cjpm.toml 和 package.json

# 2. 构建项目
cd apps/agentskills-runtime
cjpm build

# 3. 打包发布
cjpm run --name magic.scripts.package_release

# 4. 发布到 AtomGit
cd ../backend
npx tsx src/app/helpers/atomgit.ts release create \
  --owner uctoo \
  --repo agentskills-runtime \
  --tag v0.0.9 \
  --name "AgentSkills Runtime v0.0.9" \
  --body "$(cat ../agentskills-runtime/temp/release_body.md)"

npx tsx src/app/helpers/atomgit.ts release upload \
  --owner uctoo \
  --repo agentskills-runtime \
  --tag v0.0.9 \
  --file "../agentskills-runtime/release/agentskills-runtime-win-x64.tar.gz"

# 5. 发布 JavaScript SDK
cd ../agentskills-runtime/sdk/javascript
pnpm build
npm publish --access public

# 6. 更新依赖项目
cd ../../../backend
pnpm update @opencangjie/skills

cd ../uctoo-app-client-pc
pnpm update @opencangjie/skills
```

## 常见问题

### Q: 发布时提示 "No access token configured"

确保在 `apps/backend/.env` 中配置了 `ATOMGIT_ACCESS_TOKEN`：

```
ATOMGIT_ACCESS_TOKEN=your_token_here
```

### Q: 打包时缺少 DLL 文件

确保仓颉环境正确配置，并且已经成功构建项目：

```bash
cjpm build
```

### Q: npm 发布失败

1. 确保已登录 npm：
   ```bash
   npm login
   ```

2. 确保包名未被占用或有权发布

3. 对于 scoped package，使用 `--access public`：
   ```bash
   npm publish --access public
   ```

### Q: 如何回滚发布

AtomGit 不支持直接删除发布，但可以：
1. 更新发布标记为预发布版本
2. 发布新版本修复问题

---

**版本**: 1.0.0  
**更新日期**: 2026-02-19
