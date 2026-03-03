# AgentSkills PHP SDK

AgentSkills Runtime 的 PHP SDK - 安装、管理和执行 AI 代理技能，内置运行时支持。

## 安装

通过 Composer 安装：

```bash
composer require opencangjie/skills
```

或从源码安装：

```bash
git clone https://atomgit.com/uctoo/agentskills-runtime.git
cd agentskills-runtime/sdk/php
composer install
```

## CLI 使用

SDK 提供命令行界面用于管理技能和运行时。

### 安装运行时

```bash
# 下载并安装 AgentSkills 运行时
php bin/skills install-runtime
```

### 配置运行时

在启动运行时之前，您需要配置 AI 模型 API 密钥。运行时需要 AI 模型来处理技能执行和自然语言理解。

编辑运行时目录中的 `.env` 文件：
- **Windows**: `%USERPROFILE%\.agentskills-runtime\release\.env`
- **macOS/Linux**: `~/.agentskills-runtime/release/.env`

添加您的 AI 模型配置（选择一个提供商）：

```ini
# 选项 1: StepFun (阶跃星辰)
MODEL_PROVIDER=stepfun
MODEL_NAME=step-1-8k
STEPFUN_API_KEY=your_stepfun_api_key_here
STEPFUN_BASE_URL=https://api.stepfun.com/v1

# 选项 2: DeepSeek
MODEL_PROVIDER=deepseek
MODEL_NAME=deepseek-chat
DEEPSEEK_API_KEY=your_deepseek_api_key_here

# 选项 3: 华为云 MaaS
MODEL_PROVIDER=maas
MAAS_API_KEY=your_maas_api_key_here
MAAS_BASE_URL=https://api.modelarts-maas.com/v2
MAAS_MODEL_NAME=qwen3-coder-480b-a35b-instruct

# 选项 4: Sophnet
MODEL_PROVIDER=sophnet
SOPHNET_API_KEY=your_sophnet_api_key_here
SOPHNET_BASE_URL=https://www.sophnet.com/api/open-apis/v1
```

> **注意**：如果没有正确配置 AI 模型，运行时将无法启动，并显示类似 "Get env variable XXX_API_KEY error" 的错误。

### 启动运行时

```bash
# 后台启动运行时
php bin/skills start

# 前台启动运行时
php bin/skills start --foreground

# 在自定义端口启动
php bin/skills start --port 9000
```

### 停止运行时

```bash
php bin/skills stop
```

### 检查状态

```bash
php bin/skills status
```

### 搜索技能

```bash
# 搜索所有来源
php bin/skills find "python"

# 搜索特定来源
php bin/skills find "python" --source github

# 限制结果数量
php bin/skills find "python" --limit 5
```

### 安装技能

```bash
# 从本地目录安装
php bin/skills add ./path/to/skill

# 从 GitHub 安装
php bin/skills add https://github.com/user/skill-repo

# 安装特定分支/标签
php bin/skills add https://github.com/user/skill-repo --branch main
php bin/skills add https://github.com/user/skill-repo --tag v1.0.0

# 从多技能仓库安装（指定子目录）
php bin/skills add https://github.com/user/skills-repo/tree/main/skills/my-skill
php bin/skills add https://atomgit.com/user/skills-repo/tree/main/skills/skill-creator

# 带选项安装
php bin/skills add https://github.com/user/skill-repo -y  # 跳过确认
```

> **提示**：对于包含多个技能的仓库，使用 `/tree/<分支>/<技能路径>` 格式指定具体的子目录。这样可以避免交互式选择提示。

### 列出已安装的技能

```bash
# 列出所有技能
php bin/skills list

# 分页结果
php bin/skills list --page 1 --limit 20
```

### 获取技能信息

```bash
php bin/skills info <skill-id>
```

### 执行技能

```bash
# 执行技能
php bin/skills run <skill-id>

# 执行特定工具
php bin/skills run <skill-id> --tool <tool-name>

# 传递参数
php bin/skills run <skill-id> --params '{"key": "value"}'
```

### 移除技能

```bash
php bin/skills remove <skill-id>
```

### 初始化新技能项目

```bash
# 创建新的技能项目
php bin/skills init my-skill

# 在特定目录创建
php bin/skills init my-skill --directory ./skills
```

### 检查更新

```bash
php bin/skills check
```

## 编程使用

### 创建客户端

```php
use AgentSkills\SkillsClient;
use AgentSkills\ClientConfig;

// 使用默认设置创建客户端
$client = new SkillsClient();

// 使用自定义配置创建客户端
$config = new ClientConfig(
    baseUrl: 'http://127.0.0.1:8080',
    authToken: 'your-token',
    timeout: 30000,
);
$client = new SkillsClient($config);
```

### 运行时管理

```php
use AgentSkills\RuntimeManager;
use AgentSkills\RuntimeOptions;

$runtime = new RuntimeManager();

// 检查运行时是否已安装
if (!$runtime->isInstalled()) {
    $runtime->downloadRuntime();
}

// 启动运行时
$options = new RuntimeOptions(
    port: 8080,
    detached: true,
);
$runtime->start($options);

// 检查状态
$status = $runtime->status();
if ($status->running) {
    echo "Runtime version: " . $status->version . "\n";
}

// 停止运行时
$runtime->stop();
```

### 列出技能

```php
$result = $client->listSkills([
    'limit' => 10,
    'page' => 0,
]);

foreach ($result->skills as $skill) {
    echo $skill->name . " v" . $skill->version . "\n";
}
```

### 搜索技能

```php
$result = $client->searchSkills([
    'query' => 'python',
    'source' => 'github',
    'limit' => 10,
]);

foreach ($result->results as $skill) {
    echo $skill->full_name . "\n";
    echo $skill->description . "\n";
}
```

### 安装技能

```php
use AgentSkills\SkillInstallOptions;

$options = new SkillInstallOptions(
    source: 'https://github.com/user/skill-repo',
    branch: 'main',
);

$result = $client->installSkill($options);

if ($result->isMultiSkillRepo()) {
    // 处理多技能仓库
    foreach ($result->available_skills as $skill) {
        echo $skill->name . "\n";
    }
} else {
    echo "Installed: " . $result->name . "\n";
}
```

### 执行技能

```php
// 执行技能
$result = $client->executeSkill('skill-id', [
    'param1' => 'value1',
]);

if ($result->success) {
    echo $result->output . "\n";
} else {
    echo "Error: " . $result->errorMessage . "\n";
}

// 执行特定工具
$result = $client->executeSkillTool('skill-id', 'tool-name', [
    'param1' => 'value1',
]);
```

### 获取技能信息

```php
$skill = $client->getSkill('skill-id');

echo $skill->name . "\n";
echo $skill->description . "\n";
echo $skill->version . "\n";

foreach ($skill->tools as $tool) {
    echo "Tool: " . $tool->name . "\n";
    echo "  " . $tool->description . "\n";
}
```

### 移除技能

```php
$result = $client->uninstallSkill('skill-id');

if ($result['success']) {
    echo "Skill removed successfully\n";
}
```

### 技能配置

```php
// 获取技能配置
$config = $client->getSkillConfig('skill-id');

// 设置技能配置
$client->setSkillConfig('skill-id', [
    'option1' => 'value1',
]);
```

### 定义技能

```php
use AgentSkills\defineSkill;
use AgentSkills\ToolDefinition;
use AgentSkills\ToolParameter;
use AgentSkills\ToolParameterType;

$skill = defineSkill([
    'metadata' => [
        'name' => 'my-skill',
        'version' => '1.0.0',
        'description' => '我的自定义技能',
        'author' => '您的名字',
    ],
    'tools' => [
        new ToolDefinition(
            name: 'my-tool',
            description: '一个执行某些操作的工具',
            parameters: [
                new ToolParameter(
                    name: 'input',
                    paramType: ToolParameterType::String,
                    description: '输入参数',
                    required: true,
                ),
            ],
        ),
    ],
]);
```

### 配置

SDK 从带有 `SKILL_` 前缀的环境变量读取配置：

```php
use AgentSkills\getConfig;

$config = getConfig();
// 返回包含 'API_URL'、'AUTH_TOKEN' 等键的数组
```

### 错误处理

```php
use AgentSkills\handleApiError;
use AgentSkills\ApiError;

try {
    $client->installSkill($options);
} catch (\Exception $e) {
    $error = handleApiError($e);
    echo "Error {$error->errno}: {$error->errmsg}\n";
}
```

## 系统要求

- PHP 8.1 或更高版本
- Composer 2.0 或更高版本
- 扩展：json、phar、zip

## 开发

### 运行测试

```bash
composer test
```

### 代码分析

```bash
composer analyze
```

### 代码风格

```bash
composer cs-check
composer cs-fix
```

## 许可证

MIT 许可证 - 详见 LICENSE 文件。

## 支持

- GitHub: https://github.com/UCTooCom/agentskills-runtime
- AtomGit: https://atomgit.com/uctoo/agentskills-runtime
- Issues: https://github.com/UCTooCom/agentskills-runtime/issues
