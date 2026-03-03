# AgentSkills PHP SDK

[![Latest Stable Version](https://poser.pugx.org/opencangjie/agent-skills/v/stable)](https://packagist.org/packages/opencangjie/agent-skills)
[![Total Downloads](https://poser.pugx.org/opencangjie/agent-skills/downloads)](https://packagist.org/packages/opencangjie/agent-skills)
[![License](https://poser.pugx.org/opencangjie/agent-skills/license)](https://packagist.org/packages/opencangjie/agent-skills)
[![PHP Version Require](https://poser.pugx.org/opencangjie/agent-skills/require/php)](https://packagist.org/packages/opencangjie/agent-skills)

PHP SDK for AgentSkills Runtime - Install, manage, and execute AI agent skills with built-in runtime support.

## Features

- 🚀 **Easy Installation**: One-command runtime installation
- 🛠️ **CLI & Programmatic API**: Use via command line or PHP code
- 🔍 **Skill Discovery**: Search and install skills from multiple sources
- ⚡ **Built-in Runtime**: Automatic runtime download and management
- 🔧 **Multi-Platform**: Support for Windows, macOS, and Linux
- 📦 **PSR Compliant**: Follows PHP-FIG standards

## Installation

### Via Composer (Recommended)

```bash
composer require opencangjie/agent-skills
```

### Global Installation (for CLI usage)

```bash
composer global require opencangjie/agent-skills
```

Make sure your global Composer bin directory is in your PATH:
- **Windows**: `%USERPROFILE%\AppData\Roaming\Composer\vendor\bin`
- **macOS/Linux**: `~/.composer/vendor/bin` or `~/.config/composer/vendor/bin`

### Install from Source

```bash
git clone https://github.com/UCTooCom/agentskills-runtime.git
cd agentskills-runtime/sdk/php
composer install
```

## Quick Start

### 1. Install Runtime

```bash
# Using global installation
skills install-runtime

# Using local installation
./vendor/bin/skills install-runtime
```

### 2. Configure AI Model

Edit the `.env` file in the runtime directory:
- **Windows**: `%USERPROFILE%\.agentskills\runtime\win-x64\release\.env`
- **macOS/Linux**: `~/.agentskills/runtime/<platform>-<arch>/release/.env`

Add your AI model API key:

```ini
# Example: DeepSeek
MODEL_PROVIDER=deepseek
MODEL_NAME=deepseek-chat
DEEPSEEK_API_KEY=your_api_key_here
```

### 3. Start Runtime

```bash
skills start
```

### 4. Install and Run Skills

```bash
# Search for skills
skills find "python"

# Install a skill
skills add https://github.com/user/skill-repo

# Execute a skill
skills run <skill-id>
```

## CLI Usage

The SDK provides a command-line interface for managing skills and runtime.

### Runtime Commands

```bash
# Install runtime
skills install-runtime [--runtime-version 0.0.16]

# Start runtime
skills start [--port 8080] [--host 127.0.0.1] [--foreground]

# Stop runtime
skills stop

# Check status
skills status
```

### Skill Commands

```bash
# Search for skills
skills find <query> [--source github] [--limit 10]

# Install skills
skills add <source> [--branch main] [--tag v1.0.0]

# List installed skills
skills list [--page 1] [--limit 20]

# Get skill info
skills info <skill-id>

# Execute skills
skills run <skill-id> [--tool <tool-name>] [--params '{"key": "value"}']

# Remove skills
skills remove <skill-id>

# Initialize new skill project
skills init <name> [--directory ./skills]

# Check for updates
skills check
```

## Programmatic Usage

### Create Client

```php
use AgentSkills\SkillsClient;
use AgentSkills\ClientConfig;

// Create client with default settings
$client = new SkillsClient();

// Create client with custom configuration
$config = new ClientConfig(
    baseUrl: 'http://127.0.0.1:8080',
    authToken: 'your-token',
    timeout: 30000,
);
$client = new SkillsClient($config);
```

### Runtime Management

```php
use AgentSkills\RuntimeManager;
use AgentSkills\RuntimeOptions;

$runtime = new RuntimeManager();

// Check if runtime is installed
if (!$runtime->isInstalled()) {
    $runtime->downloadRuntime();
}

// Start runtime
$options = new RuntimeOptions(
    port: 8080,
    detached: true,
);
$runtime->start($options);

// Check status
$status = $runtime->status();
if ($status->running) {
    echo "Runtime version: " . $status->version . "\n";
}

// Stop runtime
$runtime->stop();
```

### List Skills

```php
$result = $client->listSkills([
    'limit' => 10,
    'page' => 0,
]);

foreach ($result->skills as $skill) {
    echo $skill->name . " v" . $skill->version . "\n";
}
```

### Search Skills

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

### Install Skills

```php
use AgentSkills\SkillInstallOptions;

$options = new SkillInstallOptions(
    source: 'https://github.com/user/skill-repo',
    branch: 'main',
);

$result = $client->installSkill($options);

if ($result->isMultiSkillRepo()) {
    // Handle multi-skill repository
    foreach ($result->available_skills as $skill) {
        echo $skill->name . "\n";
    }
} else {
    echo "Installed: " . $result->name . "\n";
}
```

### Execute Skills

```php
// Execute skill
$result = $client->executeSkill('skill-id', [
    'param1' => 'value1',
]);

if ($result->success) {
    echo $result->output . "\n";
} else {
    echo "Error: " . $result->errorMessage . "\n";
}

// Execute specific tool
$result = $client->executeSkillTool('skill-id', 'tool-name', [
    'param1' => 'value1',
]);
```

### Get Skill Information

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

### Remove Skills

```php
$result = $client->uninstallSkill('skill-id');

if ($result['success']) {
    echo "Skill removed successfully\n";
}
```

### Skill Configuration

```php
// Get skill config
$config = $client->getSkillConfig('skill-id');

// Set skill config
$client->setSkillConfig('skill-id', [
    'option1' => 'value1',
]);
```

### Define Skills

```php
use AgentSkills\defineSkill;
use AgentSkills\ToolDefinition;
use AgentSkills\ToolParameter;
use AgentSkills\ToolParameterType;

$skill = defineSkill([
    'metadata' => [
        'name' => 'my-skill',
        'version' => '1.0.0',
        'description' => 'My custom skill',
        'author' => 'Your Name',
    ],
    'tools' => [
        new ToolDefinition(
            name: 'my-tool',
            description: 'A tool that does something',
            parameters: [
                new ToolParameter(
                    name: 'input',
                    paramType: ToolParameterType::String,
                    description: 'Input parameter',
                    required: true,
                ),
            ],
        ),
    ],
]);
```

### Configuration

The SDK reads configuration from environment variables prefixed with `SKILL_`:

```php
use AgentSkills\getConfig;

$config = getConfig();
// Returns array with keys like 'API_URL', 'AUTH_TOKEN', etc.
```

### Error Handling

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

## AI Model Configuration

Before starting the runtime, you need to configure the AI model API key. The runtime requires an AI model to process skill execution and natural language understanding.

Edit the `.env` file in the runtime directory:
- **Windows**: `%USERPROFILE%\.agentskills\runtime\win-x64\release\.env`
- **macOS/Linux**: `~/.agentskills/runtime/<platform>-<arch>/release/.env`

Add your AI model configuration (choose one provider):

```ini
# Option 1: StepFun (阶跃星辰)
MODEL_PROVIDER=stepfun
MODEL_NAME=step-1-8k
STEPFUN_API_KEY=your_stepfun_api_key_here
STEPFUN_BASE_URL=https://api.stepfun.com/v1

# Option 2: DeepSeek
MODEL_PROVIDER=deepseek
MODEL_NAME=deepseek-chat
DEEPSEEK_API_KEY=your_deepseek_api_key_here

# Option 3: 华为云 MaaS
MODEL_PROVIDER=maas
MAAS_API_KEY=your_maas_api_key_here
MAAS_BASE_URL=https://api.modelarts-maas.com/v2
MAAS_MODEL_NAME=qwen3-coder-480b-a35b-instruct

# Option 4: Sophnet
MODEL_PROVIDER=sophnet
SOPHNET_API_KEY=your_sophnet_api_key_here
SOPHNET_BASE_URL=https://www.sophnet.com/api/open-apis/v1
```

> **Note**: Without proper AI model configuration, the runtime will fail to start with an error like "Get env variable XXX_API_KEY error."

## Requirements

- PHP 8.1 or higher
- Composer 2.0 or higher
- Extensions: json, phar, zip

## Development

### Run Tests

```bash
composer test
```

### Code Analysis

```bash
composer analyze
```

### Code Style

```bash
composer cs-check
composer cs-fix
```

### Run All Checks

```bash
composer check
```

## Documentation

- [中文文档](README_cn.md)
- [API Documentation](https://github.com/UCTooCom/agentskills-runtime/wiki)
- [Packagist](https://packagist.org/packages/opencangjie/agent-skills)

## Contributing

Please see [CONTRIBUTING.md](../../CONTRIBUTING.md) for details.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

- **GitHub**: https://github.com/UCTooCom/agentskills-runtime
- **AtomGit**: https://atomgit.com/uctoo/agentskills-runtime
- **Issues**: https://github.com/UCTooCom/agentskills-runtime/issues
- **Packagist**: https://packagist.org/packages/opencangjie/agent-skills

## Related Projects

- [JavaScript SDK](../javascript/)
- [Python SDK](../python/)
- [Java SDK](../java/)
