# Maven Central 发布指南

本文档说明如何将 `agentskills-runtime` Java SDK 发布到 Maven Central。

## 前置条件

### 1. GPG 密钥配置

Maven Central 要求所有发布的构件必须使用 GPG 签名。

#### 生成 GPG 密钥

```bash
# 生成新的 GPG 密钥
gpg --gen-key

# 按照提示输入：
# - 密钥类型：RSA and RSA
# - 密钥大小：4096
# - 有效期：0（永不过期）
# - 真实姓名：OpenCangJie Team
# - 电子邮件：support@opencangjie.com
# - 注释：AgentSkills Runtime
# - 密码：设置一个强密码
```

#### 上传公钥到密钥服务器

```bash
# 列出密钥
gpg --list-keys

# 上传公钥到密钥服务器
gpg --keyserver hkp://keyserver.ubuntu.com --send-keys YOUR_KEY_ID

# 验证上传
gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys YOUR_KEY_ID
```

#### 导出密钥用于 Maven

```bash
# 导出私钥（备份用）
gpg --export-secret-keys YOUR_KEY_ID > private-key.asc

# 导出公钥（备份用）
gpg --export YOUR_KEY_ID > public-key.asc
```

### 2. Maven 配置

在 `~/.m2/settings.xml` 中配置 Sonatype 凭证：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd">

    <servers>
        <!-- Sonatype OSSRH Server -->
        <server>
            <id>mavenCentral</id>
            <username>your-sonatype-username</username>
            <password>your-sonatype-token</password>
        </server>

        <!-- Sonatype Snapshots Server -->
        <server>
            <id>mavenCentralSnapshots</id>
            <username>your-sonatype-username</username>
            <password>your-sonatype-token</password>
        </server>
    </servers>

    <profiles>
        <profile>
            <id>release</id>
            <properties>
                <gpg.executable>gpg</gpg.executable>
                <gpg.passphrase>your-gpg-passphrase</gpg.passphrase>
            </properties>
        </profile>
    </profiles>

    <activeProfiles>
        <activeProfile>release</activeProfile>
    </activeProfiles>

</settings>
```

**注意**：
- 使用 Sonatype Token 而不是密码
- Token 在 https://central.sonatype.com/ 创建
- GPG 密码需要与生成密钥时设置的密码一致

### 3. Sonatype JIRA 账号

1. 访问 https://central.sonatype.com/
2. 创建账号或使用现有账号
3. 在 "Namespaces" 中添加 `com.opencangjie` 命名空间
4. 创建 User Token 用于 Maven 认证

## 发布步骤

### 方法 1：使用发布脚本（推荐）

#### Linux/macOS

```bash
# 进入 SDK 目录
cd sdk/java

# 运行发布脚本
./publish.sh

# 跳过测试发布
./publish.sh --skip-tests
```

#### Windows

```cmd
REM 进入 SDK 目录
cd sdk\java

REM 运行发布脚本
publish.bat

REM 跳过测试发布
publish.bat --skip-tests
```

### 方法 2：手动发布

```bash
# 1. 清理之前的构建
mvn clean

# 2. 运行测试
mvn test

# 3. 部署到 Maven Central
mvn deploy -P release
```

## 验证发布

### 1. 检查 Staging 仓库

1. 访问 https://s01.oss.sonatype.org/
2. 登录 Sonatype 账号
3. 进入 "Staging Repositories"
4. 找到 `comopencangjie-xxxxx` 仓库
5. 点击 "Close" 进行验证
6. 验证通过后点击 "Release"

### 2. 检查构件

发布成功后，构件将在以下位置可用：

```
https://repo1.maven.org/maven2/com/opencangjie/agentskills-runtime/
```

### 3. 搜索构件

在 Maven Central 搜索：

```
https://central.sonatype.com/search?q=agentskills-runtime
```

## 使用发布的 SDK

### Maven

```xml
<dependency>
    <groupId>com.opencangjie</groupId>
    <artifactId>agentskills-runtime</artifactId>
    <version>0.0.1</version>
</dependency>
```

### Gradle

```gradle
dependencies {
    implementation 'com.opencangjie:agentskills-runtime:0.0.1'
}
```

## 常见问题

### 1. GPG 签名失败

**错误信息**：
```
gpg: signing failed: Inappropriate ioctl for device
```

**解决方案**：
```bash
# 使用 GPG agent
echo "use-agent" >> ~/.gnupg/gpg.conf

# 或者在 settings.xml 中配置
<properties>
    <gpg.executable>gpg2</gpg.executable>
    <gpg.passphraseServerId>gpg.passphrase</gpg.passphraseServerId>
</properties>
```

### 2. 认证失败

**错误信息**：
```
401 Unauthorized
```

**解决方案**：
- 检查 `settings.xml` 中的用户名和密码
- 确认使用的是 User Token 而不是密码
- 验证 Token 是否过期

### 3. 命名空间验证失败

**错误信息**：
```
Unable to validate namespace: com.opencangjie
```

**解决方案**：
- 在 https://central.sonatype.com/ 中添加命名空间
- 确认命名空间所有权验证通过

### 4. 构件验证失败

**错误信息**：
```
Missing signature file
```

**解决方案**：
- 确认 `maven-gpg-plugin` 已正确配置
- 检查 GPG 密钥是否已上传到密钥服务器
- 验证 GPG 密钥是否已导入到本地

## 发布新版本

1. 更新 `pom.xml` 中的版本号
2. 更新 `README.md` 中的版本号
3. 运行发布脚本
4. 在 Sonatype 中验证和发布

## 回滚发布

如果需要回滚已发布的版本：

1. 在 Sonatype 中找到对应的 Staging 仓库
2. 点击 "Drop" 删除
3. 如果已经发布到 Central，需要联系 Sonatype 支持

## 参考资料

- [Maven Central 发布指南](https://central.sonatype.org/publish/publish-guide/)
- [GPG 密钥生成](https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key)
- [Sonatype OSSRH](https://oss.sonatype.org/)
