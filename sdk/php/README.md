# AgentSkills PHP SDK

PHP SDK for AgentSkills Runtime - Install, manage, and execute AI agent skills with built-in runtime support.

## Installation

Install via Composer:

```bash
composer require uctoo/agent-skills
```

Or install from source:

```bash
git clone https://atomgit.com/uctoo/agentskills-runtime.git
cd agentskills-runtime/sdk/php
composer install
```

## CLI Usage

The SDK provides a command-line interface for managing skills and runtime.

### Install Runtime

```bash
# Download and install the AgentSkills runtime
php bin/skills install-runtime
```

### Start Runtime

```bash
# Start runtime in background
php bin/skills start

# Start runtime in foreground
php bin/skills start --foreground

# Start on custom port
php bin/skills start --port 9000
```

### Stop Runtime

```bash
php bin/skills stop
```

### Check Status

```bash
php bin/skills status
```

### Search for Skills

```bash
# Search all sources
php bin/skills find "python"

# Search specific source
php bin/skills find "python" --source github

# Limit results
php bin/skills find "python" --limit 5
```

### Install Skills

```bash
# Install from GitHub
php bin/skills add https://github.com/user/skill-repo

# Install from local path
php bin/skills add ./path/to/skill

# Install specific branch/tag
php bin/skills add https://github.com/user/skill-repo --branch main
php bin/skills add https://github.com/user/skill-repo --tag v1.0.0
```

### List Installed Skills

```bash
# List all skills
php bin/skills list

# Paginate results
php bin/skills list --page 1 --limit 20
```

### Get Skill Information

```bash
php bin/skills info <skill-id>
```

### Execute Skills

```bash
# Execute a skill
php bin/skills run <skill-id>

# Execute a specific tool
php bin/skills run <skill-id> --tool <tool-name>

# Pass parameters
php bin/skills run <skill-id> --params '{"key": "value"}'
```

### Remove Skills

```bash
php bin/skills remove <skill-id>
```

### Initialize New Skill Project

```bash
# Create a new skill project
php bin/skills init my-skill

# Create in specific directory
php bin/skills init my-skill --directory ./skills
```

### Check for Updates

```bash
php bin/skills check
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

## License

MIT License - see LICENSE file for details.

## Support

- GitHub: https://github.com/UCTooCom/agentskills-runtime
- AtomGit: https://atomgit.com/uctoo/agentskills-runtime
- Issues: https://github.com/UCTooCom/agentskills-runtime/issues