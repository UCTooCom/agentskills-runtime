/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.core.tool.{ToolException, ToolParameter}
import magic.jsonable.TypeSchema
import magic.log.LogUtils
import magic.utils.readFile
import magic.utils.removeIfExists
import std.collection.HashMap
import std.convert.*
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonArray}
import std.fs.{File, Path, Directory, FileInfo, exists, OpenMode, rename}
import std.io.StringWriter

public class FileReadTool <: NativeFuncTool {
    public static let NAME = "file_read"
    
    public static let DESC = """
    Read content from a file.
    Supports reading with line numbers, line range selection, and encoding options.
    Returns the file content as a string.
    """

    public init() {
        super(
            name: FileReadTool.NAME,
            description: FileReadTool.DESC,
            parameters: [
                ("path", "The file path to read", TypeSchema.Str),
                ("withLineNumber", "Add line numbers to output (default false)", TypeSchema.Boolean),
                ("startLine", "Start reading from this line (default 1)", TypeSchema.Int),
                ("endLine", "End reading at this line (default -1 for end of file)", TypeSchema.Int)
            ],
            retType: TypeSchema.Str,
            examples: [
                """
                {
                  "path": "/path/to/file.txt"
                }
                """,
                """
                {
                  "path": "/path/to/file.txt",
                  "withLineNumber": true,
                  "startLine": 10,
                  "endLine": 50
                }
                """
            ],
            extra: HashMap([
                ("filterable", "true"),
                ("terminal", "false"),
                ("compactable", "true")
            ]),
            execFn: { args: HashMap<String, JsonValue> =>
                FileReadTool.executeRead(args)
            }
        )
    }

    public static func executeRead(args: HashMap<String, JsonValue>): String {
        let pathStr = FileReadTool.extractString(args, "path")
        if (pathStr.isEmpty()) {
            throw ToolException("Parameter 'path' is required")
        }

        let path = Path(pathStr)
        if (!exists(path)) {
            throw ToolException("File does not exist: ${pathStr}")
        }

        let withLineNumber = FileReadTool.extractBool(args, "withLineNumber", false)
        let startLine = FileReadTool.extractInt(args, "startLine", 1)
        let endLine = FileReadTool.extractInt(args, "endLine", Int64.Max)

        LogUtils.info("[FileReadTool] Reading file: ${pathStr}, withLineNumber: ${withLineNumber}, startLine: ${startLine}, endLine: ${endLine}")

        try {
            let content = readFile(path, withLineNumber: withLineNumber, startLine: startLine, endLine: endLine)
            
            let result = JsonObject()
            result.put("success", JsonString("true"))
            result.put("path", JsonString(pathStr))
            result.put("content", JsonString(content))
            result.put("lineCount", JsonString(content.split("\n").size.toString()))
            
            return result.toJsonString()
        } catch (ex: Exception) {
            LogUtils.error("[FileReadTool] Failed to read file: ${ex.message}")
            throw ToolException("Failed to read file: ${ex.message}")
        }
    }

    public static func extractString(args: HashMap<String, JsonValue>, key: String): String {
        if (let Some(value) <- args.get(key)) {
            match (value) {
                case jStr: JsonString =>
                    return jStr.getValue()
                case _ =>
                    let strValue = value.toString()
                    if (strValue.startsWith("\"") && strValue.endsWith("\"")) {
                        return strValue[1..(strValue.size - 1)]
                    }
                    return strValue
            }
        }
        return ""
    }

    public static func extractBool(args: HashMap<String, JsonValue>, key: String, defaultValue: Bool): Bool {
        if (let Some(value) <- args.get(key)) {
            match (value) {
                case jStr: JsonString =>
                    let strVal = jStr.getValue().toAsciiLower()
                    return strVal == "true" || strVal == "1"
                case _ =>
                    return value.toString().toAsciiLower() == "true"
            }
        }
        return defaultValue
    }

    public static func extractInt(args: HashMap<String, JsonValue>, key: String, defaultValue: Int64): Int64 {
        if (let Some(value) <- args.get(key)) {
            try {
                match (value) {
                    case jStr: JsonString =>
                        return Int64.parse(jStr.getValue())
                    case _ =>
                        return Int64.parse(value.toString())
                }
            } catch (ex: Exception) {
                return defaultValue
            }
        }
        return defaultValue
    }
}

public class FileWriteTool <: NativeFuncTool {
    public static let NAME = "file_write"
    
    public static let DESC = """
    Write content to a file.
    Supports create, append, and overwrite modes.
    Creates parent directories if they don't exist.
    """

    public init() {
        super(
            name: FileWriteTool.NAME,
            description: FileWriteTool.DESC,
            parameters: [
                ("path", "The file path to write", TypeSchema.Str),
                ("content", "Content to write to the file", TypeSchema.Str),
                ("mode", "Write mode: create, append, or overwrite (default create)", TypeSchema.Str)
            ],
            retType: TypeSchema.Str,
            examples: [
                """
                {
                  "path": "/path/to/file.txt",
                  "content": "Hello, World!"
                }
                """,
                """
                {
                  "path": "/path/to/file.txt",
                  "content": "Additional content",
                  "mode": "append"
                }
                """
            ],
            extra: HashMap([
                ("filterable", "true"),
                ("terminal", "false"),
                ("compactable", "true")
            ]),
            execFn: { args: HashMap<String, JsonValue> =>
                FileWriteTool.executeWrite(args)
            }
        )
    }

    public static func executeWrite(args: HashMap<String, JsonValue>): String {
        let pathStr = FileReadTool.extractString(args, "path")
        if (pathStr.isEmpty()) {
            throw ToolException("Parameter 'path' is required")
        }

        let content = FileReadTool.extractString(args, "content")
        let mode = FileReadTool.extractString(args, "mode")
        let writeMode = if (mode.isEmpty()) { "create" } else { mode.toAsciiLower() }

        LogUtils.info("[FileWriteTool] Writing to file: ${pathStr}, mode: ${writeMode}")

        let path = Path(pathStr)
        let parentDir = path.parent

        try {
            if (!exists(parentDir)) {
                Directory.create(parentDir, recursive: true)
                LogUtils.info("[FileWriteTool] Created parent directory: ${parentDir.toString()}")
            }

            let fileMode = if (writeMode == "append") { OpenMode.Append } else { OpenMode.Write }
            let file = File(path, fileMode)
            let writer = StringWriter(file)

            if (writeMode == "append" && exists(path)) {
                let existingContent = readFile(path)
                writer.write(existingContent)
                if (!existingContent.endsWith("\n") && !existingContent.isEmpty()) {
                    writer.write("\n")
                }
            }

            writer.write(content)
            writer.flush()
            file.close()

            let result = JsonObject()
            result.put("success", JsonString("true"))
            result.put("path", JsonString(pathStr))
            result.put("bytesWritten", JsonString(content.size.toString()))
            result.put("mode", JsonString(writeMode))

            return result.toJsonString()
        } catch (ex: Exception) {
            LogUtils.error("[FileWriteTool] Failed to write file: ${ex.message}")
            throw ToolException("Failed to write file: ${ex.message}")
        }
    }
}

public class FileEditTool <: NativeFuncTool {
    public static let NAME = "file_edit"
    
    public static let DESC = """
    Edit a file by applying text replacements.
    Supports single or multiple replacements.
    Can use literal text or regex patterns.
    """

    public init() {
        super(
            name: FileEditTool.NAME,
            description: FileEditTool.DESC,
            parameters: [
                ("path", "The file path to edit", TypeSchema.Str),
                ("oldText", "Text to find and replace", TypeSchema.Str),
                ("newText", "Replacement text", TypeSchema.Str),
                ("replaceAll", "Replace all occurrences (default false)", TypeSchema.Boolean),
                ("createIfNotExists", "Create file if it doesn't exist (default false)", TypeSchema.Boolean)
            ],
            retType: TypeSchema.Str,
            examples: [
                """
                {
                  "path": "/path/to/file.txt",
                  "oldText": "old value",
                  "newText": "new value"
                }
                """,
                """
                {
                  "path": "/path/to/file.txt",
                  "oldText": "foo",
                  "newText": "bar",
                  "replaceAll": true
                }
                """
            ],
            extra: HashMap([
                ("filterable", "true"),
                ("terminal", "false"),
                ("compactable", "true")
            ]),
            execFn: { args: HashMap<String, JsonValue> =>
                FileEditTool.executeEdit(args)
            }
        )
    }

    public static func executeEdit(args: HashMap<String, JsonValue>): String {
        let pathStr = FileReadTool.extractString(args, "path")
        if (pathStr.isEmpty()) {
            throw ToolException("Parameter 'path' is required")
        }

        let oldText = FileReadTool.extractString(args, "oldText")
        if (oldText.isEmpty()) {
            throw ToolException("Parameter 'oldText' is required")
        }

        let newText = FileReadTool.extractString(args, "newText")
        let replaceAll = FileReadTool.extractBool(args, "replaceAll", false)
        let createIfNotExists = FileReadTool.extractBool(args, "createIfNotExists", false)

        let path = Path(pathStr)

        LogUtils.info("[FileEditTool] Editing file: ${pathStr}, replaceAll: ${replaceAll}")

        try {
            if (!exists(path)) {
                if (createIfNotExists) {
                    let parentDir = path.parent
                    if (!exists(parentDir)) {
                        Directory.create(parentDir, recursive: true)
                    }
                    let file = File(path, OpenMode.Write)
                    file.close()
                } else {
                    throw ToolException("File does not exist: ${pathStr}")
                }
            }

            let content = readFile(path)
            var newContent = content
            var replacements = 0

            if (replaceAll) {
                let parts = content.split(oldText)
                if (parts.size > 1) {
                    replacements = parts.size - 1
                    newContent = String.join(parts, delimiter: newText)
                }
            } else {
                if (content.contains(oldText)) {
                    let idxOpt = content.indexOf(oldText)
                    if (let Some(idx) <- idxOpt) {
                        newContent = content[0..idx] + newText + content[(idx + oldText.size)..content.size]
                        replacements = 1
                    }
                }
            }

            if (replacements > 0) {
                let file = File(path, OpenMode.Write)
                let writer = StringWriter(file)
                writer.write(newContent)
                writer.flush()
                file.close()
            }

            let result = JsonObject()
            result.put("success", JsonString("true"))
            result.put("path", JsonString(pathStr))
            result.put("replacements", JsonString(replacements.toString()))

            return result.toJsonString()
        } catch (ex: Exception) {
            LogUtils.error("[FileEditTool] Failed to edit file: ${ex.message}")
            throw ToolException("Failed to edit file: ${ex.message}")
        }
    }
}

public class FileDeleteTool <: NativeFuncTool {
    public static let NAME = "file_delete"
    
    public static let DESC = """
    Delete a file or directory.
    Supports recursive deletion for directories.
    Use with caution as this operation cannot be undone.
    """

    public init() {
        super(
            name: FileDeleteTool.NAME,
            description: FileDeleteTool.DESC,
            parameters: [
                ("path", "The file or directory path to delete", TypeSchema.Str),
                ("recursive", "Delete directories recursively (default false)", TypeSchema.Boolean),
                ("force", "Force deletion even if file is read-only (default false)", TypeSchema.Boolean)
            ],
            retType: TypeSchema.Str,
            examples: [
                """
                {
                  "path": "/path/to/file.txt"
                }
                """,
                """
                {
                  "path": "/path/to/directory",
                  "recursive": true
                }
                """
            ],
            extra: HashMap([
                ("filterable", "true"),
                ("terminal", "false"),
                ("compactable", "true")
            ]),
            execFn: { args: HashMap<String, JsonValue> =>
                FileDeleteTool.executeDelete(args)
            }
        )
    }

    public static func executeDelete(args: HashMap<String, JsonValue>): String {
        let pathStr = FileReadTool.extractString(args, "path")
        if (pathStr.isEmpty()) {
            throw ToolException("Parameter 'path' is required")
        }

        let recursive = FileReadTool.extractBool(args, "recursive", false)

        let path = Path(pathStr)

        LogUtils.info("[FileDeleteTool] Deleting: ${pathStr}, recursive: ${recursive}")

        try {
            if (!exists(path)) {
                throw ToolException("Path does not exist: ${pathStr}")
            }

            let fileInfo = FileInfo(path)
            var deleted = false

            if (fileInfo.isDirectory()) {
                if (!recursive) {
                    let entries = Directory.readFrom(path)
                    var hasEntries = false
                    for (_ in entries) {
                        hasEntries = true
                        break
                    }
                    if (hasEntries) {
                        throw ToolException("Directory is not empty: ${pathStr}. Use recursive=true to delete.")
                    }
                }
                removeIfExists(path)
                deleted = true
            } else {
                removeIfExists(path)
                deleted = true
            }

            let result = JsonObject()
            result.put("success", JsonString(if (deleted) { "true" } else { "false" }))
            result.put("path", JsonString(pathStr))
            result.put("type", JsonString(if (fileInfo.isDirectory()) { "directory" } else { "file" }))

            return result.toJsonString()
        } catch (ex: Exception) {
            LogUtils.error("[FileDeleteTool] Failed to delete: ${ex.message}")
            throw ToolException("Failed to delete: ${ex.message}")
        }
    }
}

public class DirectoryListTool <: NativeFuncTool {
    public static let NAME = "directory_list"
    
    public static let DESC = """
    List contents of a directory.
    Returns a list of files and subdirectories with their metadata.
    Supports recursive listing and filtering by pattern.
    """

    public init() {
        super(
            name: DirectoryListTool.NAME,
            description: DirectoryListTool.DESC,
            parameters: [
                ("path", "The directory path to list", TypeSchema.Str),
                ("recursive", "List recursively (default false)", TypeSchema.Boolean),
                ("pattern", "Filter pattern (e.g., *.txt, optional)", TypeSchema.Str)
            ],
            retType: TypeSchema.Str,
            examples: [
                """
                {
                  "path": "/path/to/directory"
                }
                """,
                """
                {
                  "path": "/path/to/directory",
                  "recursive": true,
                  "pattern": "*.cj"
                }
                """
            ],
            extra: HashMap([
                ("filterable", "true"),
                ("terminal", "false"),
                ("compactable", "true")
            ]),
            execFn: { args: HashMap<String, JsonValue> =>
                DirectoryListTool.executeList(args)
            }
        )
    }

    public static func executeList(args: HashMap<String, JsonValue>): String {
        let pathStr = FileReadTool.extractString(args, "path")
        if (pathStr.isEmpty()) {
            throw ToolException("Parameter 'path' is required")
        }

        let path = Path(pathStr)
        if (!exists(path)) {
            throw ToolException("Directory does not exist: ${pathStr}")
        }

        let recursive = FileReadTool.extractBool(args, "recursive", false)
        let pattern = FileReadTool.extractString(args, "pattern")

        LogUtils.info("[DirectoryListTool] Listing directory: ${pathStr}, recursive: ${recursive}, pattern: ${pattern}")

        try {
            let entries = JsonArray()
            let fileInfo = FileInfo(path)
            
            if (!fileInfo.isDirectory()) {
                throw ToolException("Path is not a directory: ${pathStr}")
            }

            DirectoryListTool.listDirectory(path, recursive, pattern, entries)

            let result = JsonObject()
            result.put("success", JsonString("true"))
            result.put("path", JsonString(pathStr))
            result.put("count", JsonString(entries.size().toString()))
            result.put("entries", entries)

            return result.toJsonString()
        } catch (ex: Exception) {
            LogUtils.error("[DirectoryListTool] Failed to list directory: ${ex.message}")
            throw ToolException("Failed to list directory: ${ex.message}")
        }
    }

    protected static func listDirectory(
        dirPath: Path, 
        recursive: Bool, 
        pattern: String, 
        entries: JsonArray
    ): Unit {
        let dirEntries = Directory.readFrom(dirPath)
        for (fileInfo in dirEntries) {
            let name = fileInfo.path.fileName
            
            if (!pattern.isEmpty() && !DirectoryListTool.matchesPattern(name, pattern)) {
                continue
            }

            let entry = JsonObject()
            entry.put("name", JsonString(name))
            entry.put("path", JsonString(fileInfo.path.toString()))
            entry.put("isDirectory", JsonString(if (fileInfo.isDirectory()) { "true" } else { "false" }))
            entry.put("size", JsonString(fileInfo.size.toString()))
            
            entries.add(entry)

            if (recursive && fileInfo.isDirectory()) {
                DirectoryListTool.listDirectory(fileInfo.path, recursive, pattern, entries)
            }
        }
    }

    protected static func matchesPattern(name: String, pattern: String): Bool {
        if (pattern.isEmpty()) {
            return true
        }
        
        if (pattern.startsWith("*.")) {
            let ext = pattern[1..pattern.size]
            return name.endsWith(ext)
        }
        
        return name.contains(pattern)
    }
}

public class DirectoryCreateTool <: NativeFuncTool {
    public static let NAME = "directory_create"
    
    public static let DESC = """
    Create a new directory.
    Supports creating parent directories recursively.
    """

    public init() {
        super(
            name: DirectoryCreateTool.NAME,
            description: DirectoryCreateTool.DESC,
            parameters: [
                ("path", "The directory path to create", TypeSchema.Str),
                ("recursive", "Create parent directories if needed (default true)", TypeSchema.Boolean),
                ("existOk", "Don't error if directory already exists (default true)", TypeSchema.Boolean)
            ],
            retType: TypeSchema.Str,
            examples: [
                """
                {
                  "path": "/path/to/new/directory"
                }
                """,
                """
                {
                  "path": "/path/to/nested/directory",
                  "recursive": true
                }
                """
            ],
            extra: HashMap([
                ("filterable", "true"),
                ("terminal", "false"),
                ("compactable", "true")
            ]),
            execFn: { args: HashMap<String, JsonValue> =>
                DirectoryCreateTool.executeCreate(args)
            }
        )
    }

    public static func executeCreate(args: HashMap<String, JsonValue>): String {
        let pathStr = FileReadTool.extractString(args, "path")
        if (pathStr.isEmpty()) {
            throw ToolException("Parameter 'path' is required")
        }

        let recursive = FileReadTool.extractBool(args, "recursive", true)
        let existOk = FileReadTool.extractBool(args, "existOk", true)

        let path = Path(pathStr)

        LogUtils.info("[DirectoryCreateTool] Creating directory: ${pathStr}, recursive: ${recursive}")

        try {
            if (exists(path)) {
                if (existOk) {
                    let result = JsonObject()
                    result.put("success", JsonString("true"))
                    result.put("path", JsonString(pathStr))
                    result.put("created", JsonString("false"))
                    result.put("message", JsonString("Directory already exists"))
                    return result.toJsonString()
                } else {
                    throw ToolException("Directory already exists: ${pathStr}")
                }
            }

            Directory.create(path, recursive: recursive)

            let result = JsonObject()
            result.put("success", JsonString("true"))
            result.put("path", JsonString(pathStr))
            result.put("created", JsonString("true"))

            return result.toJsonString()
        } catch (ex: Exception) {
            LogUtils.error("[DirectoryCreateTool] Failed to create directory: ${ex.message}")
            throw ToolException("Failed to create directory: ${ex.message}")
        }
    }
}

public class FileSearchTool <: NativeFuncTool {
    public static let NAME = "file_search"
    
    public static let DESC = """
    Search for text within files.
    Supports searching in a single file or recursively in a directory.
    Returns matching lines with their line numbers.
    """

    public init() {
        super(
            name: FileSearchTool.NAME,
            description: FileSearchTool.DESC,
            parameters: [
                ("path", "The file or directory path to search in", TypeSchema.Str),
                ("query", "The text to search for", TypeSchema.Str),
                ("recursive", "Search recursively in directories (default false)", TypeSchema.Boolean),
                ("caseSensitive", "Case sensitive search (default false)", TypeSchema.Boolean),
                ("filePattern", "File pattern to match (e.g., *.cj, optional)", TypeSchema.Str)
            ],
            retType: TypeSchema.Str,
            examples: [
                """
                {
                  "path": "/path/to/file.txt",
                  "query": "search term"
                }
                """,
                """
                {
                  "path": "/path/to/directory",
                  "query": "function",
                  "recursive": true,
                  "filePattern": "*.cj"
                }
                """
            ],
            extra: HashMap([
                ("filterable", "true"),
                ("terminal", "false"),
                ("compactable", "true")
            ]),
            execFn: { args: HashMap<String, JsonValue> =>
                FileSearchTool.executeSearch(args)
            }
        )
    }

    public static func executeSearch(args: HashMap<String, JsonValue>): String {
        let pathStr = FileReadTool.extractString(args, "path")
        if (pathStr.isEmpty()) {
            throw ToolException("Parameter 'path' is required")
        }

        let query = FileReadTool.extractString(args, "query")
        if (query.isEmpty()) {
            throw ToolException("Parameter 'query' is required")
        }

        let recursive = FileReadTool.extractBool(args, "recursive", false)
        let caseSensitive = FileReadTool.extractBool(args, "caseSensitive", false)
        let filePattern = FileReadTool.extractString(args, "filePattern")

        let path = Path(pathStr)

        LogUtils.info("[FileSearchTool] Searching in: ${pathStr}, query: ${query}")

        try {
            if (!exists(path)) {
                throw ToolException("Path does not exist: ${pathStr}")
            }

            let matches = JsonArray()
            let fileInfo = FileInfo(path)
            let searchQuery = if (caseSensitive) { query } else { query.toAsciiLower() }

            if (fileInfo.isDirectory()) {
                FileSearchTool.searchInDirectory(path, searchQuery, recursive, caseSensitive, filePattern, matches)
            } else {
                FileSearchTool.searchInFile(path, searchQuery, caseSensitive, matches)
            }

            let result = JsonObject()
            result.put("success", JsonString("true"))
            result.put("path", JsonString(pathStr))
            result.put("query", JsonString(query))
            result.put("matchCount", JsonString(matches.size().toString()))
            result.put("matches", matches)

            return result.toJsonString()
        } catch (ex: Exception) {
            LogUtils.error("[FileSearchTool] Failed to search: ${ex.message}")
            throw ToolException("Failed to search: ${ex.message}")
        }
    }

    protected static func searchInDirectory(
        dirPath: Path,
        query: String,
        recursive: Bool,
        caseSensitive: Bool,
        filePattern: String,
        matches: JsonArray
    ): Unit {
        let entries = Directory.readFrom(dirPath)
        for (fileInfo in entries) {
            if (fileInfo.isDirectory()) {
                if (recursive) {
                    FileSearchTool.searchInDirectory(fileInfo.path, query, recursive, caseSensitive, filePattern, matches)
                }
            } else {
                let fileName = fileInfo.path.fileName
                if (!filePattern.isEmpty() && !DirectoryListTool.matchesPattern(fileName, filePattern)) {
                    continue
                }
                FileSearchTool.searchInFile(fileInfo.path, query, caseSensitive, matches)
            }
        }
    }

    protected static func searchInFile(
        filePath: Path,
        query: String,
        caseSensitive: Bool,
        matches: JsonArray
    ): Unit {
        try {
            let content = readFile(filePath)
            let searchContent = if (caseSensitive) { content } else { content.toAsciiLower() }
            let lines = content.split("\n")
            let searchLines = searchContent.split("\n")

            for (i in 0..lines.size) {
                if (searchLines[i].contains(query)) {
                    let matchResult = JsonObject()
                    matchResult.put("file", JsonString(filePath.toString()))
                    matchResult.put("line", JsonString((i + 1).toString()))
                    matchResult.put("content", JsonString(lines[i]))
                    matches.add(matchResult)
                }
            }
        } catch (ex: Exception) {
            LogUtils.info("[FileSearchTool] Could not read file: ${filePath.toString()}")
        }
    }
}

public class FileCopyTool <: NativeFuncTool {
    public static let NAME = "file_copy"
    
    public static let DESC = """
    Copy a file or directory to a new location.
    Supports recursive copying for directories.
    """

    public init() {
        super(
            name: FileCopyTool.NAME,
            description: FileCopyTool.DESC,
            parameters: [
                ("source", "Source file or directory path", TypeSchema.Str),
                ("destination", "Destination path", TypeSchema.Str),
                ("overwrite", "Overwrite existing files (default false)", TypeSchema.Boolean),
                ("recursive", "Copy directories recursively (default true)", TypeSchema.Boolean)
            ],
            retType: TypeSchema.Str,
            examples: [
                """
                {
                  "source": "/path/to/source.txt",
                  "destination": "/path/to/destination.txt"
                }
                """,
                """
                {
                  "source": "/path/to/source_dir",
                  "destination": "/path/to/destination_dir",
                  "recursive": true
                }
                """
            ],
            extra: HashMap([
                ("filterable", "true"),
                ("terminal", "false"),
                ("compactable", "true")
            ]),
            execFn: { args: HashMap<String, JsonValue> =>
                FileCopyTool.executeCopy(args)
            }
        )
    }

    public static func executeCopy(args: HashMap<String, JsonValue>): String {
        let sourceStr = FileReadTool.extractString(args, "source")
        if (sourceStr.isEmpty()) {
            throw ToolException("Parameter 'source' is required")
        }

        let destStr = FileReadTool.extractString(args, "destination")
        if (destStr.isEmpty()) {
            throw ToolException("Parameter 'destination' is required")
        }

        let overwrite = FileReadTool.extractBool(args, "overwrite", false)
        let recursive = FileReadTool.extractBool(args, "recursive", true)

        let source = Path(sourceStr)
        let dest = Path(destStr)

        LogUtils.info("[FileCopyTool] Copying: ${sourceStr} -> ${destStr}")

        try {
            if (!exists(source)) {
                throw ToolException("Source does not exist: ${sourceStr}")
            }

            let sourceInfo = FileInfo(source)

            if (sourceInfo.isDirectory()) {
                if (!recursive) {
                    throw ToolException("Source is a directory. Use recursive=true to copy.")
                }
                FileCopyTool.copyDirectory(source, dest, overwrite)
            } else {
                FileCopyTool.copyFile(source, dest, overwrite)
            }

            let result = JsonObject()
            result.put("success", JsonString("true"))
            result.put("source", JsonString(sourceStr))
            result.put("destination", JsonString(destStr))
            result.put("type", JsonString(if (sourceInfo.isDirectory()) { "directory" } else { "file" }))

            return result.toJsonString()
        } catch (ex: Exception) {
            LogUtils.error("[FileCopyTool] Failed to copy: ${ex.message}")
            throw ToolException("Failed to copy: ${ex.message}")
        }
    }

    protected static func copyFile(source: Path, dest: Path, overwrite: Bool): Unit {
        if (exists(dest) && !overwrite) {
            throw ToolException("Destination already exists: ${dest.toString()}")
        }

        let parentDir = dest.parent
        if (!exists(parentDir)) {
            Directory.create(parentDir, recursive: true)
        }

        let content = readFile(source)
        let file = File(dest, OpenMode.Write)
        let writer = StringWriter(file)
        writer.write(content)
        writer.flush()
        file.close()
    }

    protected static func copyDirectory(source: Path, dest: Path, overwrite: Bool): Unit {
        if (!exists(dest)) {
            Directory.create(dest, recursive: true)
        }

        let entries = Directory.readFrom(source)
        for (fileInfo in entries) {
            let destPath = Path(dest.toString() + "/" + fileInfo.path.fileName)
            if (fileInfo.isDirectory()) {
                FileCopyTool.copyDirectory(fileInfo.path, destPath, overwrite)
            } else {
                FileCopyTool.copyFile(fileInfo.path, destPath, overwrite)
            }
        }
    }
}

public class FileMoveTool <: NativeFuncTool {
    public static let NAME = "file_move"
    
    public static let DESC = """
    Move or rename a file or directory.
    """

    public init() {
        super(
            name: FileMoveTool.NAME,
            description: FileMoveTool.DESC,
            parameters: [
                ("source", "Source file or directory path", TypeSchema.Str),
                ("destination", "Destination path", TypeSchema.Str),
                ("overwrite", "Overwrite existing files (default false)", TypeSchema.Boolean)
            ],
            retType: TypeSchema.Str,
            examples: [
                """
                {
                  "source": "/path/to/source.txt",
                  "destination": "/path/to/destination.txt"
                }
                """,
                """
                {
                  "source": "/path/to/old_name",
                  "destination": "/path/to/new_name"
                }
                """
            ],
            extra: HashMap([
                ("filterable", "true"),
                ("terminal", "false"),
                ("compactable", "true")
            ]),
            execFn: { args: HashMap<String, JsonValue> =>
                FileMoveTool.executeMove(args)
            }
        )
    }

    public static func executeMove(args: HashMap<String, JsonValue>): String {
        let sourceStr = FileReadTool.extractString(args, "source")
        if (sourceStr.isEmpty()) {
            throw ToolException("Parameter 'source' is required")
        }

        let destStr = FileReadTool.extractString(args, "destination")
        if (destStr.isEmpty()) {
            throw ToolException("Parameter 'destination' is required")
        }

        let overwrite = FileReadTool.extractBool(args, "overwrite", false)

        let source = Path(sourceStr)
        let dest = Path(destStr)

        LogUtils.info("[FileMoveTool] Moving: ${sourceStr} -> ${destStr}")

        try {
            if (!exists(source)) {
                throw ToolException("Source does not exist: ${sourceStr}")
            }

            if (exists(dest) && !overwrite) {
                throw ToolException("Destination already exists: ${destStr}")
            }

            let sourceInfo = FileInfo(source)

            if (exists(dest) && overwrite) {
                removeIfExists(dest)
            }

            let parentDir = dest.parent
            if (!exists(parentDir)) {
                Directory.create(parentDir, recursive: true)
            }

            rename(source, to: dest, overwrite: overwrite)

            let result = JsonObject()
            result.put("success", JsonString("true"))
            result.put("source", JsonString(sourceStr))
            result.put("destination", JsonString(destStr))

            return result.toJsonString()
        } catch (ex: Exception) {
            LogUtils.error("[FileMoveTool] Failed to move: ${ex.message}")
            throw ToolException("Failed to move: ${ex.message}")
        }
    }
}
