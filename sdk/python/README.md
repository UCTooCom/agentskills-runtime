# agentskills-runtime

Python SDK for AgentSkills Runtime - Install, manage, and execute AI agent skills with built-in runtime support.

## Features

- **Complete Runtime Management**: Download, install, start, and stop the AgentSkills runtime
- **Skill Management**: Install, list, execute, and remove skills
- **CLI & Programmatic API**: Use via command line or integrate into your applications
- **Cross-Platform**: Supports Windows, macOS, and Linux
- **Type Hints**: Full type annotations for better IDE support

## Installation

```bash
pip install agentskills-runtime
```

## CLI Usage

After installation, the `skills` CLI command is available. 

> **Note**: If the `skills` command is not found due to PATH not being set, you can use `python -m agent_skills.cli` as an alternative. For example:
> - `skills start` → `python -m agent_skills.cli start`
> - `skills list` → `python -m agent_skills.cli list`
> - `skills install-runtime` → `python -m agent_skills.cli install-runtime`

### Method 1: Python Module (Recommended)

```bash
python -m agent_skills.cli <command>

# Examples:
python -m agent_skills.cli --help
python -m agent_skills.cli start
python -m agent_skills.cli list
```

### Method 2: Add Scripts to PATH

On Windows, the CLI is installed to your Python Scripts directory. Add it to PATH:

```powershell
# PowerShell (temporary, current session only)
$env:PATH += ";$env:APPDATA\Python\Python38\Scripts"

# Or permanently via System Properties > Environment Variables
```

On macOS/Linux:
```bash
# Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
export PATH="$HOME/.local/bin:$PATH"
```

## Quick Start

### 1. Install the Runtime

```bash
# Download and install the AgentSkills runtime
skills install-runtime

# Or using Python module
python -m agent_skills.cli install-runtime

# Or specify a version
skills install-runtime --runtime-version 0.0.16
```

### 2. Configure the Runtime

Before starting the runtime, you need to configure the AI model API key. The runtime requires an AI model to process skill execution and natural language understanding.

Edit the `.env` file in the runtime directory:
- **Windows**: `%APPDATA%\Python\Python38\runtime\win-x64\release\.env`
- **macOS/Linux**: `~/.local/share/agentskills-runtime/release/.env`

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

### 3. Start the Runtime

```bash
# Start in background (default)
skills start

# Start in foreground
skills start --foreground

# Custom port and host
skills start --port 3000 --host 0.0.0.0
```

### 4. Manage Skills

```bash
# Find and install skills
skills find react
skills add ./my-skill

# List installed skills
skills list

# Execute a skill
skills run my-skill -p '{"input": "data"}'
```

## CLI Commands

### Runtime Management

#### `skills install-runtime`

Download and install the AgentSkills runtime binary.

```bash
skills install-runtime
skills install-runtime --runtime-version 0.0.16
```

#### `skills start`

Start the AgentSkills runtime server.

```bash
# Start in background (default)
skills start

# Start in foreground
skills start --foreground

# Custom configuration
skills start --port 3000 --host 0.0.0.0
```

**Options:**
- `-p, --port <port>` - Port to listen on (default: 8080)
- `-h, --host <host>` - Host to bind to (default: 127.0.0.1)
- `-f, --foreground` - Run in foreground (default: background)

#### `skills stop`

Stop the AgentSkills runtime server.

```bash
skills stop
```

#### `skills status`

Check the status of the skills runtime server.

```bash
skills status
```

### Skill Management

#### `skills find [query]`

Search for skills interactively or by keyword.

```bash
skills find
skills find react testing
skills find "pdf generation"
skills find skill --source github --limit 10
skills find skill --source atomgit --limit 5
```

**Options:**
- `-l, --limit <number>`: Maximum number of results, default 10
- `-s, --source <source>`: Search source, options: `all` (default), `github`, `gitee`, `atomgit`

**Note:** AtomGit search requires setting the `ATOMGIT_TOKEN` environment variable in the runtime's `.env` configuration file.

#### `skills add <source>`

Install a skill from GitHub or local path.

```bash
# Install from local directory
skills add ./my-skill

# Install from GitHub repository
skills add github.com/user/skill-repo
skills add github.com/user/skill-repo --branch develop

# Install from multi-skill repository (specify subdirectory)
skills add https://github.com/user/skills-repo/tree/main/skills/my-skill
skills add https://atomgit.com/user/skills-repo/tree/main/skills/skill-creator

# Install with options
skills add github.com/user/skill-repo -y  # Skip confirmation
skills add github.com/user/skill-repo --branch develop --commit abc123
```

**Options:**
- `-g, --global`: Install globally (user-level)
- `-p, --path <path>`: Local path to skill
- `-b, --branch <branch>`: Git branch name
- `-t, --tag <tag>`: Git tag name
- `-c, --commit <commit>`: Git commit ID
- `-n, --name <name>`: Skill name override
- `--validate/--no-validate`: Validate skill before installation (default: True)
- `-y, --yes`: Skip confirmation prompts

> **Tip**: For repositories containing multiple skills, use the `/tree/<branch>/<skill-path>` format to specify the exact subdirectory. This avoids the interactive selection prompt.

#### `skills list`

List installed skills.

```bash
skills list
skills list --limit 50 --page 1
skills list --json
```

**Options:**
- `-l, --limit <number>`: Maximum number of results, default 20
- `-p, --page <number>`: Page number, default 0
- `--json`: Output as JSON

#### `skills run <skillId>`

Execute a skill.

```bash
skills run my-skill -p '{"param1": "value"}'
skills run my-skill --tool tool-name -p '{"param1": "value"}'
skills run my-skill -i  # Interactive mode
```

**Options:**
- `-t, --tool <name>`: Tool name to execute
- `-p, --params <json>`: Parameters as JSON string
- `-f, --params-file <file>`: Parameters from JSON file
- `-i, --interactive`: Interactive parameter input

#### `skills remove <skillId>`

Remove an installed skill.

```bash
skills remove my-skill
skills rm my-skill -y
```

**Options:**
- `-y, --yes`: Skip confirmation prompt

#### `skills info <skillId>`

Show detailed information about a skill.

```bash
skills info my-skill
```

#### `skills init [name]`

Initialize a new skill project.

```bash
skills init my-new-skill
skills init my-new-skill --directory ./skills
```

**Options:**
- `-d, --directory <dir>`: Target directory, default: current directory
- `-t, --template <template>`: Skill template, default: basic

#### `skills check`

Check for skill updates.

```bash
skills check
```

## Programmatic API

### Basic Usage

```python
from agent_skills import SkillsClient, create_client

# Create a client
client = create_client()

# List skills
result = client.list_skills(limit=10)
for skill in result.skills:
    print(f"{skill.name}: {skill.description}")

# Execute a skill
result = client.execute_skill("my-skill", {"input": "data"})
if result.success:
    print(result.output)
else:
    print(f"Error: {result.error_message}")
```

### Runtime Management

```python
from agent_skills import RuntimeManager, RuntimeOptions

manager = RuntimeManager()

# Check if runtime is installed
if not manager.is_installed():
    # Download and install runtime
    manager.download_runtime("0.0.16")

# Start runtime
options = RuntimeOptions(port=8080, host="127.0.0.1")
process = manager.start(options)

# Check status
status = manager.status()
print(f"Running: {status.running}, Version: {status.version}")

# Stop runtime
manager.stop()
```

### Skill Definition

```python
from agent_skills import define_skill, SkillMetadata, ToolDefinition, ToolParameter, ParamType

# Define a skill
skill = define_skill(
    metadata=SkillMetadata(
        name="my-skill",
        version="1.0.0",
        description="My custom skill",
        author="Your Name",
    ),
    tools=[
        ToolDefinition(
            name="my-tool",
            description="A tool that does something",
            parameters=[
                ToolParameter(
                    name="input",
                    param_type=ParamType.STRING,
                    description="Input parameter",
                    required=True,
                ),
            ],
        ),
    ],
)
```

### Configuration

```python
from agent_skills import get_config

# Get configuration from environment variables prefixed with SKILL_
config = get_config()
api_key = config.get("API_KEY")  # From SKILL_API_KEY env var
```

## Configuration

### Environment Variables

- `SKILL_RUNTIME_API_URL`: API server URL (default: http://127.0.0.1:8080)
- `SKILL_INSTALL_PATH`: Default path for skill installation
- `SKILL_*`: Custom configuration accessible via `get_config()`

## Development

### Setup Development Environment

```bash
# Clone the repository
git clone https://atomgit.com/uctoo/agentskills-runtime.git
cd agentskills-runtime/sdk/python

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install development dependencies
pip install -e ".[dev]"
```

### Run Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=agent_skills

# Run specific test file
pytest tests/test_models.py
```

### Code Quality

```bash
# Format code
black src tests

# Sort imports
isort src tests

# Type check
mypy src

# Lint
ruff check src tests
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Publishing to PyPI

### Prerequisites

1. Create an account on [PyPI](https://pypi.org/account/register/)
2. Generate an API token from [PyPI Account Settings](https://pypi.org/manage/account/token/)
3. Update `.pypirc` with your token:

```ini
[pypi]
username = __token__
password = pypi-xxxx...  # Your PyPI API token
```

### Publish to PyPI

```bash
# Install publish dependencies
pip install -e ".[publish]"

# Method 1: Using the publish script
python publish.py

# Method 2: Manual publish
python -m build
python -m twine upload dist/*

# Publish to TestPyPI first (recommended for testing)
python publish.py --test
```

### Important Notes

- **Never commit `.pypirc` with real tokens to version control**
- The `.gitignore` file excludes `.pypirc` by default
- Use TestPyPI for testing before publishing to production PyPI
- Version numbers must be unique for each publish

## Links

- [PyPI Package](https://pypi.org/project/agentskills-runtime/)
- [Documentation](https://atomgit.com/uctoo/agentskills-runtime#readme)
- [Repository](https://atomgit.com/uctoo/agentskills-runtime)
- [Issue Tracker](https://atomgit.com/uctoo/agentskills-runtime/issues)
- [JavaScript SDK](../javascript)
