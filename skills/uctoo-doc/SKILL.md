---
name: uctoo-doc
description: UCTOO 项目文档查询与阅读助手。帮助用户快速查找和阅读 UCTOO 项目的各类文档，包括 API 设计规范、数据库设计文档、后端架构文档等。当用户提及 UCTOO 文档、API 规范、数据库设计、项目文档、技术文档等关键词时，应使用此技能。
license: MIT
compatibility: 需要网络访问 Gitee 文档仓库；需要 runtime 内置文件工具支持
---

# UCTOO 文档查询助手

## 概述

本技能帮助用户快速查找和阅读 UCTOO 项目的各类技术文档，包括 API 设计规范、数据库设计文档、后端架构文档等。

## 核心能力

1. **文档检索**：从 Gitee 仓库检索最新的 UCTOO 项目文档
2. **本地文档读取**：读取 runtime 项目中的本地技能文件和文档
3. **文档阅读**：获取并展示文档内容，支持 Markdown 格式
4. **知识问答**：基于文档内容回答用户的技术问题
5. **快速定位**：帮助用户快速找到特定章节或内容

## 可用工具

### 1. file_read - 读取本地文件

**功能**：读取本地文件内容，支持行范围选择和行号显示

**参数说明**：

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| path | String | ✅ 是 | - | 文件路径（推荐使用绝对路径） |
| withLineNumber | Boolean | ❌ 否 | false | 是否在输出中添加行号 |
| startLine | Int | ❌ 否 | 1 | 起始行号（从1开始） |
| endLine | Int | ❌ 否 | -1 | 结束行号（-1 表示文件末尾） |
| offset | Int | ❌ 否 | 0 | 偏移量（兼容旧版API，与startLine等效） |
| limit | Int | ❌ 否 | 0 | 读取行数限制（兼容旧版API） |

**使用示例**：

```
file_read: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\skills\\uctoo-doc\\SKILL.md"}
```

```
file_read: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\docs\\builtin-tools.md", "withLineNumber": true, "startLine": 1, "endLine": 100}
```

**返回结果示例**：
```json
{
  "success": "true",
  "path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\skills\\uctoo-doc\\SKILL.md",
  "content": "# UCTOO 文档查询助手\n\n## 概述\n...",
  "lineCount": "50"
}
```

### 2. directory_list - 列出目录内容

**功能**：列出指定目录的文件和子目录

**参数说明**：

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| path | String | ✅ 是 | - | 目录路径（推荐使用绝对路径） |
| recursive | Boolean | ❌ 否 | false | 是否递归列出子目录 |
| pattern | String | ❌ 否 | - | 文件匹配模式（如 `*.md`） |

**使用示例**：

```
directory_list: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\skills"}
```

```
directory_list: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\skills", "recursive": true, "pattern": "*.md"}
```

### 3. file_search - 搜索文件内容

**功能**：在文件或目录中搜索指定文本

**参数说明**：

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| path | String | ✅ 是 | - | 文件或目录路径（推荐使用绝对路径） |
| query | String | ✅ 是 | - | 搜索关键词 |
| recursive | Boolean | ❌ 否 | false | 是否递归搜索目录 |
| caseSensitive | Boolean | ❌ 否 | false | 是否区分大小写 |
| filePattern | String | ❌ 否 | - | 文件匹配模式 |

**使用示例**：

```
file_search: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\docs", "query": "API设计", "recursive": true, "filePattern": "*.md"}
```

### 4. file_write - 写入本地文件

**功能**：写入内容到本地文件

**参数说明**：

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| path | String | ✅ 是 | - | 文件路径（推荐使用绝对路径） |
| content | String | ✅ 是 | - | 要写入的内容 |
| append | Boolean | ❌ 否 | false | 是否追加模式 |

**使用示例**：

```
file_write: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\test_output.txt", "content": "Hello World"}
```

### 5. file_delete - 删除文件或目录

**功能**：删除指定文件或目录

**参数说明**：

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| path | String | ✅ 是 | - | 文件或目录路径（推荐使用绝对路径） |
| recursive | Boolean | ❌ 否 | false | 删除目录时是否递归删除子内容 |

**使用示例**：

```
file_delete: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\test_output.txt"}
```

### 6. web_fetch - 获取远程文档

**功能**：从远程 URL 获取网页内容并转换为 Markdown

**参数说明**：

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| url | String | ✅ 是 | - | 文档 URL |

**使用示例**：

```
web_fetch: {"url": "https://gitee.com/uctoo/uctoo/blob/master/apps/uctoo-backend/docs/uctoo-api-design-specification.md"}
```

## 关键路径参考

**Runtime 项目根目录**：
```
D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime
```

**技能目录**：
- `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills\` - 所有技能安装目录
  - `skills\uctoo-doc\SKILL.md` - uctoo-doc 技能文档
  - `skills\skill-creator\SKILL.md` - skill-creator 技能文档
  - `skills\cangjie-coder\SKILL.md` - cangjie-coder 技能文档

**文档目录**：
- `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\docs\` - 项目文档目录
  - `docs\builtin-tools.md` - 内置工具文档
  - `docs\uctoo-v4\` - UCTOO V4 架构文档

## 工作流程

### 1. 路径检测（重要）

**第一步必须先检测当前工作目录**，确保路径正确：

```
directory_list: {"path": "."}
```

如果返回空目录或不是预期的路径，请使用**绝对路径**：

```
directory_list: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime"}
```

### 2. 接收用户请求

当用户提出文档相关需求时，首先识别用户想要查询的文档类型：
- API 相关 → API 设计规范
- 数据库相关 → 数据库设计文档
- 架构相关 → 项目架构文档
- 技能相关 → 本地技能文件（使用 `file_read`）
- 其他 → 询问用户具体需求

### 3. 选择工具策略

根据文档位置选择合适的工具：

**本地文档优先策略**：

```
用户请求文档
    │
    ├─→ 是否涉及技能文件？
    │       ├─→ 是 → 使用 file_read 读取本地 SKILL.md（使用绝对路径）
    │       └─→ 否 → 继续
    │
    ├─→ 是否涉及 runtime 本地文档？
    │       ├─→ 是 → 使用 file_read 读取本地文档（使用绝对路径）
    │       └─→ 否 → 继续
    │
    └─→ 使用 web_fetch 从 Gitee 获取远程文档
```

### 4. 检索文档

#### 4.1 读取本地技能文件

使用 `file_read` 工具读取 runtime 项目中的技能文件：

```
file_read: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\skills\\uctoo-doc\\SKILL.md"}
```

**常用本地技能路径**：
- `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills\uctoo-doc\SKILL.md` - uctoo-doc 技能文档
- `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills\skill-creator\SKILL.md` - skill-creator 技能文档
- `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\docs\builtin-tools.md` - 内置工具文档

#### 4.2 浏览技能目录

使用 `directory_list` 查看可用技能：

```
directory_list: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\skills", "recursive": true}
```

#### 4.3 获取远程文档

使用 `web_fetch` 工具从 Gitee 获取文档内容：

```
web_fetch: {"url": "https://gitee.com/uctoo/uctoo/blob/master/apps/uctoo-backend/docs/uctoo-api-design-specification.md"}
```

**注意**：
- 优先使用 `/blob/` 路径（HTML 页面），`web_fetch` 会自动转换为 Markdown
- 也可以使用 `/raw/` 路径获取原始 Markdown 内容

### 5. 展示内容

- 将获取的文档内容以清晰的格式展示给用户
- 如果文档较长，可以提供章节摘要和导航
- 支持用户提问关于文档内容的特定问题

### 6. 知识问答

基于文档内容回答用户问题：
- 准确引用文档中的相关内容
- 提供上下文解释
- 如果文档中没有明确答案，诚实告知用户

## 使用示例

### 示例 1：查询 API 设计规范

**用户请求**："我想了解 UCTOO 的 API 设计规范"

**操作**：
1. 使用 `web_fetch` 获取 API 设计规范文档
2. 展示文档内容
3. 根据用户进一步提问提供详细解答

### 示例 2：查询数据库设计

**用户请求**："数据库表结构是怎么设计的？"

**操作**：
1. 使用 `web_fetch` 获取数据库设计文档
2. 提取并展示表结构相关内容
3. 解释实体关系

### 示例 3：读取本地技能文档

**用户请求**："我想了解 uctoo-doc 技能的使用方法"

**操作**：
1. 使用 `file_read` 读取本地技能文件（使用绝对路径）
   ```
   file_read: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\skills\\uctoo-doc\\SKILL.md"}
   ```
2. 展示技能文档内容
3. 解释技能的功能和使用方法

### 示例 4：浏览技能目录

**用户请求**："当前有哪些可用的技能？"

**操作**：
1. 使用 `directory_list` 列出技能目录（使用绝对路径）
   ```
   directory_list: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\skills", "recursive": true}
   ```
2. 展示技能列表
3. 根据用户选择读取具体技能文档

### 示例 5：搜索文档内容

**用户请求**："API 中如何处理认证？"

**操作**：
1. 使用 `file_search` 在文档目录中搜索（使用绝对路径）
   ```
   file_search: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\docs", "query": "认证", "recursive": true, "filePattern": "*.md"}
   ```
2. 或者使用 `web_fetch` 获取 API 设计规范文档后搜索
3. 提取并展示认证机制的具体实现

### 示例 6：查找 skill-creator 技能

**用户请求**："我需要找到 skill-creator 技能的 SKILL.md 文件"

**操作**：
1. 先检测目录结构
   ```
   directory_list: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\skills"}
   ```
2. 找到 skill-creator 目录后读取 SKILL.md
   ```
   file_read: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\skills\\skill-creator\\SKILL.md"}
   ```

## 关键规则

1. **使用绝对路径**：所有文件工具操作必须使用完整的绝对路径，避免相对路径导致的目录检测错误
2. **路径检测优先**：每次操作前先使用 `directory_list: {"path": "."}` 检测当前工作目录，如果为空则切换到绝对路径
3. **本地优先**：优先使用 `file_read` 读取本地文档，本地文档不可用时再使用 `web_fetch`
4. **准确引用**：回答问题时引用文档原文，确保准确性
5. **参数正确**：使用 `file_read` 时必须使用以下参数名：
   - `path`（必填，绝对路径）
   - `withLineNumber`（可选）
   - `startLine`（可选）
   - `endLine`（可选）
6. **主动询问**：如果用户需求不明确，主动询问具体想了解的文档部分
7. **持续支持**：支持用户对文档内容的深入提问

## 注意事项

- 文档内容可能较长，建议分章节展示
- 如果 Gitee 访问受限，可以尝试备用链接或告知用户
- 保持文档内容的原样引用，不随意修改
- **必须使用绝对路径**，相对路径可能导致文件工具找不到目标文件
- `file_read` 的行号参数 `startLine` 和 `endLine` 从 1 开始计数
- Windows 路径分隔符使用 `\\`（双反斜杠）或 `/`（正斜杠）
- 如果目录列表返回为空，说明当前工作目录不正确，请使用绝对路径重试
