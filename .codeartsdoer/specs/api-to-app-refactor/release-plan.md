# AgentSkills Runtime 版本更新方案

## 当前状态分析

### Runtime 版本
- **当前版本**: v0.0.18 (cjpm.toml)
- **无需重新编译**: 本次迁移只修改了 SDK 和文档，未修改仓颉代码
- **API 路径变更**: 所有 API 路径已迁移到 uctoo v4 标准

### SDK 版本状态
| SDK | 当前版本 | 目标版本 | 状态 |
|-----|---------|---------|------|
| JavaScript | v0.0.40 | v2.0.0 | ✅ 已更新 |
| Python | v0.0.6 | v2.0.0 | ✅ 已更新 |
| Java | v0.0.1 | v2.0.0 | ✅ 已更新 |
| Go | v0.0.1 | v2.0.0 | ✅ 已更新 |
| Rust | v0.0.1 | v2.0.0 | ✅ 已更新 |
| PHP | v0.0.1 | v2.0.0 | ✅ 已更新 |
| ArkTS | v0.0.1 | v2.0.0 | ✅ 已更新 |
| UniApp | v0.0.1 | v2.0.0 | ✅ 已更新 |

## 更新方案

### 方案一：仅更新 SDK（推荐）

由于 Runtime 代码未修改，可以仅发布 SDK 更新，无需重新打包 Runtime。

#### 优点
- 无需重新编译 Runtime
- 发布速度快
- 用户无需重新下载 Runtime

#### 步骤

1. **更新 Runtime 版本号**（可选）
   ```bash
   # 如果需要标记 API 变更，可以更新版本号
   # 编辑 cjpm.toml，将 version 从 0.0.18 改为 0.0.19
   ```

2. **发布 JavaScript SDK**
   ```bash
   cd sdk/javascript
   npm run build
   npm publish
   ```

3. **发布 Python SDK**
   ```bash
   cd sdk/python
   python -m build
   twine upload dist/*
   ```

4. **发布 Java SDK**
   ```bash
   cd sdk/java
   mvn clean deploy
   ```

5. **发布 PHP SDK**
   ```bash
   cd sdk/php
   # 更新 composer.json 版本号
   # 提交到 Packagist
   ```

6. **发布其他 SDK**
   - Go: 推送 tag 到 GitHub
   - Rust: 发布到 crates.io
   - ArkTS: 发布到 ohpm
   - UniApp: 发布到 npm

7. **创建 GitHub Release**
   ```bash
   # 创建 v2.0.0 tag
   git tag -a v2.0.0 -m "Release v2.0.0 - API path migration to uctoo v4 standard"
   git push origin v2.0.0
   
   # 创建 GitHub Release，包含：
   # - 迁移指南
   # - CHANGELOG
   # - 各 SDK 的更新说明
   ```

### 方案二：完整版本发布

如果需要发布包含 API 变更的完整版本。

#### 步骤

1. **更新 Runtime 版本号**
   ```bash
   # 编辑 cjpm.toml
   version = "0.0.19"
   
   # 创建 CHANGELOG
   ```

2. **重新打包 Runtime**（可选）
   ```bash
   # 如果需要重新打包
   cjpm build
   cjpm run --name magic.scripts.package_release
   ```

3. **发布所有 SDK**（同方案一）

4. **上传 Runtime 包**
   ```bash
   # 上传到 GitHub Releases
   # 上传到 AtomGit Releases
   ```

## 推荐方案：方案一

### 理由
1. **Runtime 代码未修改** - 无需重新编译和打包
2. **仅 SDK 需要更新** - API 路径变更只影响 SDK
3. **快速发布** - 可以立即发布 SDK 更新
4. **用户体验好** - 用户无需重新下载 Runtime

### 执行步骤

#### 1. 准备发布（立即执行）

```bash
# 确保所有更改已提交
git add .
git commit -m "feat: migrate all SDKs to uctoo v4 API standard

- Update all SDK versions to 2.0.0
- Migrate API paths to /api/v1/uctoo prefix
- Add comprehensive migration guides
- Update all documentation

BREAKING CHANGE: All API paths have been migrated to uctoo v4 standard"

git push origin main
```

#### 2. 发布 JavaScript SDK

```bash
cd sdk/javascript

# 构建
npm run build

# 测试
npm test

# 发布到 npm
npm publish --access public

# 验证发布
npm info @opencangjie/skills version
```

#### 3. 发布 Python SDK

```bash
cd sdk/python

# 构建
python -m build

# 发布到 PyPI
twine upload dist/*

# 验证发布
pip show agentskills-runtime
```

#### 4. 发布 Java SDK

```bash
cd sdk/java

# 构建
mvn clean package

# 发布到 Maven Central（需要配置 GPG 和 Sonatype）
mvn clean deploy

# 或发布到 GitHub Packages
mvn deploy -DaltDeploymentRepository=github::default::https://maven.pkg.github.com/UCToo/agentskills-runtime
```

#### 5. 发布 PHP SDK

```bash
cd sdk/php

# 更新版本号（已在代码中完成）
# 提交到 Git
git add .
git commit -m "Release v2.0.0"
git tag v2.0.0
git push origin main --tags

# Packagist 会自动检测到新版本
```

#### 6. 发布 Go SDK

```bash
cd sdk/go

# 创建 tag
git tag v2.0.0
git push origin v2.0.0

# Go 用户可以通过以下方式安装
# go get github.com/UCToo/agentskills-runtime/sdk/go@v2.0.0
```

#### 7. 发布 Rust SDK

```bash
cd sdk/rust

# 发布到 crates.io
cargo publish

# 验证发布
cargo search agentskills-runtime
```

#### 8. 发布 ArkTS SDK

```bash
cd sdk/arkts

# 发布到 ohpm
ohpm publish

# 或提交到 Git 并创建 tag
git tag v2.0.0
git push origin v2.0.0
```

#### 9. 发布 UniApp SDK

```bash
cd sdk/uniapp

# 构建
npm run build

# 发布到 npm
npm publish --access public

# 验证发布
npm info @opencangjie/agentskills-uniapp version
```

#### 10. 创建 GitHub Release

```bash
# 创建 tag
git tag -a v2.0.0 -m "Release v2.0.0 - API Migration to uctoo v4 Standard

## Breaking Changes

All API paths have been migrated to uctoo v4 standard with /api/v1/uctoo prefix.

### API Path Changes

- /skills → /api/v1/uctoo/agent_skills
- /skills/add → /api/v1/uctoo/skills/install
- /skills/edit → /api/v1/uctoo/agent_skills/edit
- /skills/del → /api/v1/uctoo/agent_skills/del
- /hello → /api/v1/uctoo/health

### SDK Updates

All SDKs have been updated to v2.0.0:
- JavaScript SDK
- Python SDK
- Java SDK
- Go SDK
- Rust SDK
- PHP SDK
- ArkTS SDK
- UniApp SDK

### Migration Guide

See [MIGRATION_GUIDE.md](sdk/MIGRATION_GUIDE.md) for detailed migration instructions.

### Documentation

- [API Migration Notes](sdk/MIGRATION_NOTES.md)
- [JavaScript SDK Migration](sdk/javascript/MIGRATION.md)
- [Migration Completion Summary](.codeartsdoer/specs/api-to-app-refactor/migration-completion-summary.md)
"

git push origin v2.0.0

# 在 GitHub 上创建 Release，附加：
# - 迁移指南文档
# - CHANGELOG
# - 各 SDK 的更新说明
```

#### 11. 更新文档网站（如有）

```bash
# 更新在线文档
# - API 文档
# - 迁移指南
# - 示例代码
```

#### 12. 通知用户

```bash
# 发布公告
# - GitHub Discussions
# - 邮件列表
# - 社交媒体
# - 博客文章
```

## 发布检查清单

### 发布前检查
- [x] 所有 SDK 代码已更新
- [x] 所有文档已更新
- [x] 迁移指南已创建
- [x] CHANGELOG 已更新
- [x] 版本号已更新
- [ ] Git 提交已完成
- [ ] Git tag 已创建

### JavaScript SDK 发布
- [ ] npm run build 成功
- [ ] npm test 通过
- [ ] npm publish 成功
- [ ] npm info 验证版本

### Python SDK 发布
- [ ] python -m build 成功
- [ ] twine upload 成功
- [ ] pip show 验证版本

### Java SDK 发布
- [ ] mvn clean package 成功
- [ ] mvn deploy 成功

### PHP SDK 发布
- [ ] composer.json 已更新
- [ ] Git tag 已推送
- [ ] Packagist 已更新

### Go SDK 发布
- [ ] Git tag 已推送
- [ ] go get 测试成功

### Rust SDK 发布
- [ ] cargo publish 成功
- [ ] cargo search 验证版本

### ArkTS SDK 发布
- [ ] ohpm publish 成功（或 Git tag 已推送）

### UniApp SDK 发布
- [ ] npm run build 成功
- [ ] npm publish 成功

### GitHub Release
- [ ] Git tag v2.0.0 已创建
- [ ] GitHub Release 已创建
- [ ] Release Notes 已编写
- [ ] 迁移指南已附加

### 发布后验证
- [ ] JavaScript SDK 可安装
- [ ] Python SDK 可安装
- [ ] Java SDK 可安装
- [ ] PHP SDK 可安装
- [ ] Go SDK 可安装
- [ ] Rust SDK 可安装
- [ ] ArkTS SDK 可安装
- [ ] UniApp SDK 可安装

## 回滚计划

如果发布出现问题：

1. **npm 包回滚**
   ```bash
   npm deprecate @opencangjie/skills@2.0.0 "Critical bug found, please use 0.0.40"
   ```

2. **PyPI 包回滚**
   ```bash
   # PyPI 不支持删除，只能发布新版本
   # 发布 2.0.1 修复版本
   ```

3. **GitHub Release 删除**
   ```bash
   git push --delete origin v2.0.0
   # 在 GitHub 上删除 Release
   ```

## 时间估算

- Git 提交和推送: 5 分钟
- JavaScript SDK 发布: 10 分钟
- Python SDK 发布: 10 分钟
- Java SDK 发布: 15 分钟
- PHP SDK 发布: 5 分钟
- Go SDK 发布: 5 分钟
- Rust SDK 发布: 10 分钟
- ArkTS SDK 发布: 5 分钟
- UniApp SDK 发布: 10 分钟
- GitHub Release 创建: 10 分钟
- 文档更新: 15 分钟
- 用户通知: 10 分钟

**总计**: 约 1.5 - 2 小时

## 注意事项

1. **版本号一致性**: 确保所有 SDK 版本号一致（v2.0.0）
2. **文档同步**: 确保所有文档与代码同步
3. **测试验证**: 发布前务必测试所有 SDK
4. **用户通知**: 及时通知用户升级
5. **向后兼容**: 明确告知用户无向后兼容
6. **支持渠道**: 准备好回答用户问题

## 下一步行动

立即执行方案一的步骤 1-12，完成所有 SDK 的发布。
