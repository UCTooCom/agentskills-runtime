# SDK 版本更新总结

## 更新日期
2026-03-14

## 版本变更

所有 SDK 版本已统一更新为 **v1.0.0**

### 已更新 SDK

| SDK | 旧版本 | 新版本 | 配置文件 | 状态 |
|-----|--------|--------|----------|------|
| JavaScript | v0.0.40 | v1.0.0 | package.json | ✅ |
| Python | v0.0.6 | v1.0.0 | pyproject.toml | ✅ |
| Java | v0.0.1 | v1.0.0 | pom.xml | ✅ |
| PHP | v0.0.3 | v1.0.0 | composer.json | ✅ |
| UniApp | v0.0.2 | v1.0.0 | package.json | ✅ |
| Go | - | v1.0.0 | - | ⏳ 待实现 |
| Rust | - | v1.0.0 | - | ⏳ 待实现 |
| ArkTS | - | v1.0.0 | - | ⏳ 待实现 |

### 已更新文档

- ✅ JavaScript CHANGELOG.md - 更新版本号为 v1.0.0
- ✅ JavaScript MIGRATION.md - 更新所有版本引用
- ✅ 迁移指南中的版本号引用

## 版本号选择说明

选择 **v1.0.0** 而非 v2.0.0 的原因：

1. **首次正式发布** - 这是所有 SDK 的第一个正式稳定版本
2. **API 标准化** - 统一到 uctoo v4 标准，标志着 API 的稳定
3. **语义化版本** - 1.0.0 表示 API 已稳定，可用于生产环境
4. **统一版本号** - 所有 SDK 使用相同版本号，便于管理

## 语义化版本说明

- **主版本号 (1)**: 不兼容的 API 变更
- **次版本号 (0)**: 向后兼容的功能新增
- **修订号 (0)**: 向后兼容的问题修正

## 下一步

1. 发布所有 SDK 到对应的包管理器
2. 创建 GitHub Release v1.0.0
3. 更新文档网站
4. 通知用户升级

## 发布命令

### JavaScript SDK
```bash
cd sdk/javascript
npm publish
```

### Python SDK
```bash
cd sdk/python
python -m build
twine upload dist/*
```

### Java SDK
```bash
cd sdk/java
mvn clean deploy
```

### PHP SDK
```bash
cd sdk/php
# 提交到 Git，Packagist 会自动更新
git add .
git commit -m "Release v1.0.0"
git tag v1.0.0
git push origin main --tags
```

### UniApp SDK
```bash
cd sdk/uniapp
npm publish
```

## 验证发布

发布后验证各 SDK 版本：

```bash
# JavaScript
npm info @opencangjie/skills version

# Python
pip show agentskills-runtime

# Java
# 检查 Maven Central

# PHP
composer show opencangjie/skills

# UniApp
npm info agentskills-runtime-uniapp-sdk version
```
