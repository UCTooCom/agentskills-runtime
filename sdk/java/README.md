# AgentSkills Runtime Java SDK

Java SDK for AgentSkills Runtime - Install, manage, and execute AI agent skills with built-in runtime support.
AgentSkills Runtime Java SDK - 用于安装、管理和执行 AI 代理技能的 Java SDK，内置运行时支持。

## Features

- **Runtime Management**: Install, start, stop, and check status of AgentSkills Runtime
- **Skill Management**: List, install, uninstall, and update skills
- **Skill Execution**: Execute skills with parameters
- **Tool Execution**: Execute specific tools within skills
- **Skill Search**: Search for skills from various sources
- **Skill Configuration**: Get and set skill configurations

## Installation

### Maven

Add the following dependency to your `pom.xml`:

```xml
<dependency>
    <groupId>com.opencangjie</groupId>
    <artifactId>agentskills-runtime</artifactId>
    <version>0.0.1</version>
</dependency>
```

### Gradle

Add the following dependency to your `build.gradle`:

```gradle
dependencies {
    implementation 'com.opencangjie:agentskills-runtime:0.0.1'
}
```

## Usage

### Basic Usage

```java
import com.opencangjie.skills.SkillsClient;
import com.opencangjie.skills.model.*;

// Create client
SkillsClient client = new SkillsClient();

// Health check
SkillsClient.HealthCheckResponse healthCheck = client.healthCheck();
System.out.println("Health check: " + healthCheck.getStatus());

// List skills
SkillsClient.ListSkillsOptions listOptions = new SkillsClient.ListSkillsOptions();
listOptions.setLimit(10);
SkillListResponse skills = client.listSkills(listOptions);
System.out.println("Total skills: " + skills.getTotalCount());

// Execute skill
Map<String, Object> params = new HashMap<>();
params.put("query", "Hello world");
SkillExecutionResult result = client.executeSkill("skill-id", params);
System.out.println("Execution result: " + result.getOutput());
```

### Runtime Management

```java
import com.opencangjie.skills.RuntimeManager;
import com.opencangjie.skills.model.RuntimeOptions;

// Create runtime manager
RuntimeManager runtime = new RuntimeManager();

// Check if runtime is installed
boolean installed = runtime.isInstalled();
System.out.println("Runtime installed: " + installed);

// Download runtime if not installed
if (!installed) {
    boolean downloaded = runtime.downloadRuntime("0.0.16");
    System.out.println("Runtime downloaded: " + downloaded);
}

// Start runtime
RuntimeOptions options = new RuntimeOptions();
options.setPort(8080);
options.setSkillInstallPath("./skills");
runtime.start(options);

// Check runtime status
RuntimeStatus status = runtime.status();
System.out.println("Runtime running: " + status.isRunning());

// Stop runtime
runtime.stop();
```

## API Reference

### SkillsClient

- `healthCheck()`: Check if the runtime server is responding
- `listSkills(ListSkillsOptions)`: List installed skills
- `getSkill(String skillId)`: Get skill details
- `installSkill(SkillInstallOptions)`: Install a skill
- `uninstallSkill(String skillId)`: Uninstall a skill
- `executeSkill(String skillId, Map<String, Object> params)`: Execute a skill
- `executeSkillTool(String skillId, String toolName, Map<String, Object> args)`: Execute a skill tool
- `searchSkills(SearchSkillsOptions)`: Search for skills
- `updateSkill(String skillId, Map<String, Object> updates)`: Update skill information
- `getSkillConfig(String skillId)`: Get skill configuration
- `setSkillConfig(String skillId, Map<String, Object> config)`: Set skill configuration
- `listSkillTools(String skillId)`: List skill tools

### RuntimeManager

- `isInstalled()`: Check if runtime is installed
- `downloadRuntime(String version)`: Download runtime
- `start(RuntimeOptions)`: Start runtime
- `stop()`: Stop runtime
- `status()`: Get runtime status

## Configuration

### Environment Variables

- `SKILL_RUNTIME_API_URL`: Override the default API URL (default: http://127.0.0.1:8080)
- `SKILL_INSTALL_PATH`: Default skill installation path

### Client Configuration

```java
ClientConfig config = new ClientConfig();
config.setBaseUrl("http://127.0.0.1:8080");
config.setAuthToken("your-token");
config.setTimeout(30000); // 30 seconds

SkillsClient client = new SkillsClient(config);
```

## Error Handling

The SDK throws `IOException` for network-related errors. You should handle these exceptions appropriately in your code.

## Release Notes
```
mvn clean deploy -DskipTests -Dmaven.deploy.skip=true
```

## Requirements

- Java 11 or higher
- Maven or Gradle

## Dependencies

- OkHttp 4.12.0 (HTTP client)
- Jackson Databind 2.15.2 (JSON processing)
- SLF4J 1.7.36 (logging)

## License

MIT
