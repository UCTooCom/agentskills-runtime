# agentskills-runtime

AgentSkills Runtime 的 Python SDK - 安装、管理和执行 AI 代理技能，内置运行时支持。

## 特性

- **完整的运行时管理**：下载、安装、启动和停止 AgentSkills 运行时
- **技能管理**：安装、列表、执行和移除技能
- **CLI 与编程 API**：通过命令行使用或集成到您的应用程序中
- **跨平台**：支持 Windows、macOS 和 Linux
- **类型提示**：完整的类型注解，提供更好的 IDE 支持

## 安装

```bash
pip install agentskills-runtime
```

## CLI 使用

安装后，`skills` CLI 命令即可使用。

> **注意**：如果由于 PATH 未设置导致 `skills` 命令未找到，您可以使用 `python -m agent_skills.cli` 作为替代。例如：
> - `skills start` → `python -m agent_skills.cli start`
> - `skills list` → `python -m agent_skills.cli list`
> - `skills install-runtime` → `python -m agent_skills.cli install-runtime`

### 方法 1：Python 模块（推荐）

```bash
python -m agent_skills.cli <command>

# 示例：
python -m agent_skills.cli --help
python -m agent_skills.cli start
python -m agent_skills.cli list
```

### 方法 2：添加 Scripts 到 PATH

在 Windows 上，CLI 安装到您的 Python Scripts 目录。将其添加到 PATH：

```powershell
# PowerShell（临时，仅当前会话有效）
$env:PATH += ";$env:APPDATA\Python\Python38\Scripts"

# 或通过系统属性 > 环境变量永久添加
```

在 macOS/Linux 上：
```bash
# 添加到您的 shell 配置文件（~/.bashrc、~/.zshrc 等）
export PATH="$HOME/.local/bin:$PATH"
```

## 快速开始

### 1. 安装运行时

```bash
# 下载并安装 AgentSkills 运行时
skills install-runtime

# 或使用 Python 模块
python -m agent_skills.cli install-runtime

# 或指定版本
skills install-runtime --runtime-version 0.0.16
```

### 2. 配置运行时

在启动运行时之前，您需要配置 AI 模型 API 密钥。运行时需要 AI 模型来处理技能执行和自然语言理解。

编辑运行时目录中的 `.env` 文件：
- **Windows**: `%APPDATA%\Python\Python38\runtime\win-x64\release\.env`
- **macOS/Linux**: `~/.local/share/agentskills-runtime/release/.env`

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

### 3. 启动运行时

```bash
# 后台启动（默认）
skills start

# 前台启动
skills start --foreground

# 自定义端口和主机
skills start --port 3000 --host 0.0.0.0
```

### 4. 管理技能

```bash
# 查找并安装技能
skills find react
skills add ./my-skill

# 列出已安装的技能
skills list

# 执行技能
skills run my-skill -p '{"input": "data"}'
```

## CLI 命令

### 运行时管理

#### `skills install-runtime`

下载并安装 AgentSkills 运行时二进制文件。

```bash
skills install-runtime
skills install-runtime --runtime-version 0.0.16
```

#### `skills start`

启动 AgentSkills 运行时服务器。

```bash
# 后台启动（默认）
skills start

# 前台启动
skills start --foreground

# 自定义配置
skills start --port 3000 --host 0.0.0.0
```

**选项：**
- `-p, --port <port>` - 监听端口（默认：8080）
- `-h, --host <host>` - 绑定主机（默认：127.0.0.1）
- `-f, --foreground` - 前台运行（默认：后台）

#### `skills stop`

停止 AgentSkills 运行时服务器。

```bash
skills stop
```

#### `skills status`

检查技能运行时服务器的状态。

```bash
skills status
```

### 技能管理

#### `skills find [query]`

交互式搜索或按关键字搜索技能。

```bash
skills find
skills find react testing
skills find "pdf generation"
skills find skill --source github --limit 10
skills find skill --source atomgit --limit 5
```

**选项：**
- `-l, --limit <number>`: 最大返回结果数，默认 10
- `-s, --source <source>`: 搜索来源，可选值：`all`（默认）、`github`、`gitee`、`atomgit`

**注意：** AtomGit 搜索需要在运行时的 `.env` 配置文件中设置 `ATOMGIT_TOKEN` 环境变量。

#### `skills add <source>`

从 GitHub 或本地路径安装技能。

```bash
# 从本地目录安装
skills add ./my-skill

# 从 GitHub 仓库安装
skills add github.com/user/skill-repo
skills add github.com/user/skill-repo --branch develop

# 从多技能仓库安装（指定子目录）
skills add https://github.com/user/skills-repo/tree/main/skills/my-skill
skills add https://atomgit.com/user/skills-repo/tree/main/skills/skill-creator

# 带选项安装
skills add github.com/user/skill-repo -y  # 跳过确认
skills add github.com/user/skill-repo --branch develop --commit abc123
```

**选项：**
- `-g, --global`: 全局安装（用户级别）
- `-p, --path <path>`: 技能本地路径
- `-b, --branch <branch>`: Git 分支名称
- `-t, --tag <tag>`: Git 标签名称
- `-c, --commit <commit>`: Git 提交 ID
- `-n, --name <name>`: 技能名称覆盖
- `--validate/--no-validate`: 安装前验证技能（默认：True）
- `-y, --yes`: 跳过确认提示

> **提示**：对于包含多个技能的仓库，使用 `/tree/<分支>/<技能路径>` 格式指定具体的子目录。这样可以避免交互式选择提示。

#### `skills list`

列出已安装的技能。

```bash
skills list
skills list --limit 50 --page 1
skills list --json
```

**选项：**
- `-l, --limit <number>`: 最大返回结果数，默认 20
- `-p, --page <number>`: 页码，默认 0
- `--json`: JSON 格式输出

#### `skills run <skillId>`

执行技能。

```bash
skills run my-skill -p '{"param1": "value"}'
skills run my-skill --tool tool-name -p '{"param1": "value"}'
skills run my-skill -i  # 交互模式
```

**选项：**
- `-t, --tool <name>`: 要执行的工具名称
- `-p, --params <json>`: JSON 字符串格式的参数
- `-f, --params-file <file>`: 从 JSON 文件读取参数
- `-i, --interactive`: 交互式参数输入

#### `skills remove <skillId>`

移除已安装的技能。

```bash
skills remove my-skill
skills rm my-skill -y
```

**选项：**
- `-y, --yes`: 跳过确认提示

#### `skills info <skillId>`

显示技能的详细信息。

```bash
skills info my-skill
```

#### `skills init [name]`

初始化新的技能项目。

```bash
skills init my-new-skill
skills init my-new-skill --directory ./skills
```

**选项：**
- `-d, --directory <dir>`: 目标目录，默认：当前目录
- `-t, --template <template>`: 技能模板，默认：basic

#### `skills check`

检查技能更新。

```bash
skills check
```

## 编程 API

### 基本使用

```python
from agent_skills import SkillsClient, create_client

# 创建客户端
client = create_client()

# 列出技能
result = client.list_skills(limit=10)
for skill in result.skills:
    print(f"{skill.name}: {skill.description}")

# 执行技能
result = client.execute_skill("my-skill", {"input": "data"})
if result.success:
    print(result.output)
else:
    print(f"Error: {result.error_message}")
```

### 运行时管理

```python
from agent_skills import RuntimeManager, RuntimeOptions

manager = RuntimeManager()

# 检查运行时是否已安装
if not manager.is_installed():
    # 下载并安装运行时
    manager.download_runtime("0.0.16")

# 启动运行时
options = RuntimeOptions(port=8080, host="127.0.0.1")
process = manager.start(options)

# 检查状态
status = manager.status()
print(f"Running: {status.running}, Version: {status.version}")

# 停止运行时
manager.stop()
```

### 技能定义

```python
from agent_skills import define_skill, SkillMetadata, ToolDefinition, ToolParameter, ParamType

# 定义技能
skill = define_skill(
    metadata=SkillMetadata(
        name="my-skill",
        version="1.0.0",
        description="我的自定义技能",
        author="您的名字",
    ),
    tools=[
        ToolDefinition(
            name="my-tool",
            description="一个执行某些操作的工具",
            parameters=[
                ToolParameter(
                    name="input",
                    param_type=ParamType.STRING,
                    description="输入参数",
                    required=True,
                ),
            ],
        ),
    ],
)
```

### 配置

```python
from agent_skills import get_config

# 从带有 SKILL_ 前缀的环境变量获取配置
config = get_config()
api_key = config.get("API_KEY")  # 来自 SKILL_API_KEY 环境变量
```

## 配置

### 环境变量

- `SKILL_RUNTIME_API_URL`: API 服务器 URL（默认：http://127.0.0.1:8080）
- `SKILL_INSTALL_PATH`: 技能安装的默认路径
- `SKILL_*`: 可通过 `get_config()` 访问的自定义配置

## 开发

### 设置开发环境

```bash
# 克隆仓库
git clone https://atomgit.com/uctoo/agentskills-runtime.git
cd agentskills-runtime/sdk/python

# 创建虚拟环境
python -m venv venv
source venv/bin/activate  # Windows 上：venv\Scripts\activate

# 安装开发依赖
pip install -e ".[dev]"
```

### 运行测试

```bash
# 运行所有测试
pytest

# 运行并生成覆盖率报告
pytest --cov=agent_skills

# 运行特定测试文件
pytest tests/test_models.py
```

### 代码质量

```bash
# 格式化代码
black src tests

# 排序导入
isort src tests

# 类型检查
mypy src

# 代码检查
ruff check src tests
```

## 许可证

MIT 许可证 - 详见 [LICENSE](LICENSE)。

## 发布到 PyPI

### 前提条件

1. 在 [PyPI](https://pypi.org/account/register/) 创建账户
2. 从 [PyPI 账户设置](https://pypi.org/manage/account/token/) 生成 API 令牌
3. 使用您的令牌更新 `.pypirc`：

```ini
[pypi]
username = __token__
password = pypi-xxxx...  # 您的 PyPI API 令牌
```

### 发布到 PyPI

```bash
# 安装发布依赖
pip install -e ".[publish]"

# 方法 1：使用发布脚本
python publish.py

# 方法 2：手动发布
python -m build
python -m twine upload dist/*

# 先发布到 TestPyPI（推荐用于测试）
python publish.py --test
```

### 重要说明

- **永远不要将包含真实令牌的 `.pypirc` 提交到版本控制**
- `.gitignore` 文件默认排除 `.pypirc`
- 在发布到生产 PyPI 之前，使用 TestPyPI 进行测试
- 每次发布的版本号必须唯一

## 链接

- [PyPI 包](https://pypi.org/project/agentskills-runtime/)
- [文档](https://atomgit.com/uctoo/agentskills-runtime#readme)
- [仓库](https://atomgit.com/uctoo/agentskills-runtime)
- [问题追踪](https://atomgit.com/uctoo/agentskills-runtime/issues)
- [JavaScript SDK](../javascript)
