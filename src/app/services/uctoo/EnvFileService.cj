/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.fs.{File, Path, remove, rename}
import std.regex.Regex
import std.time.DateTime
import std.env.getWorkingDirectory
import magic.utils.getEnv
import magic.log.LogUtils

public enum EnvLineType {
    | Comment
    | Blank
    | KeyValue
}

public class EnvLine {
    public var lineType: EnvLineType = Blank
    public var key: Option<String> = None<String>
    public var value: Option<String> = None<String>
    public var rawLine: String = ""

    public init() {}

    public func isKeyValue(): Bool {
        match (lineType) {
            case KeyValue => true
            case _ => false
        }
    }
}

public class EnvFileService {
    private let envRegex = Regex("^\\s*([\\w.]+)\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^#]*)\\s*(?:#.*)?$")
    private let commentRegex = Regex("^\\s*#")

    public init() {}

    public func getEnvFilePath(): String {
        let envFilePath = getEnv("ENV_FILE_PATH")
        if (let Some(path) <- envFilePath) {
            if (!path.isEmpty()) {
                return path
            }
        }
        let workDir = getWorkingDirectory()
        "${workDir.toString()}/.env"
    }

    public func parseEnvFile(content: String): ArrayList<EnvLine> {
        let lines = ArrayList<EnvLine>()
        for (line in content.split("\n")) {
            let envLine = EnvLine()
            envLine.rawLine = line

            if (line.trimAscii().isEmpty()) {
                envLine.lineType = Blank
            } else if (let Some(_) <- commentRegex.find(line)) {
                envLine.lineType = Comment
            } else if (let Some(md) <- envRegex.find(line, group: true)) {
                envLine.lineType = KeyValue
                envLine.key = Some(md.matchString(1).trimAscii())
                var val = md.matchString(2).trimAscii()
                if (val.startsWith('"')) {
                    val = val.replace('"', "")
                } else if (val.startsWith("'")) {
                    val = val.replace("'", "")
                }
                envLine.value = Some(val)
            } else {
                envLine.lineType = Blank
            }
            lines.add(envLine)
        }
        lines
    }

    public func serializeEnvFile(lines: ArrayList<EnvLine>): String {
        let sb = StringBuilder()
        for (i in 0..lines.size) {
            let line = lines[i]
            match (line.lineType) {
                case KeyValue =>
                    let key = line.key.getOrThrow()
                    let value = line.value.getOrThrow()
                    sb.append("${key}=${value}")
                case _ =>
                    sb.append(line.rawLine)
            }
            if (i < lines.size - 1) {
                sb.append("\n")
            }
        }
        sb.toString()
    }

    public func readAllEnvValues(path: String): HashMap<String, String> {
        let result = HashMap<String, String>()
        try {
            let rawContent = File.readFrom(path)
            let content = String.fromUtf8(rawContent)
            LogUtils.info("EnvFileService", "Read .env file content, size: ${content.size}")
            let lines = parseEnvFile(content)
            for (line in lines) {
                if (line.isKeyValue()) {
                    if (let Some(k) <- line.key) {
                        if (let Some(v) <- line.value) {
                            result.add(k, v)
                        }
                    }
                }
            }
            LogUtils.info("EnvFileService", "Parsed ${result.size} key-value pairs from .env file")
        } catch (e: Exception) {
            LogUtils.error("EnvFileService", "Failed to read env file: ${e.message}")
        }
        result
    }

    public func readEnvValue(path: String, key: String): Option<String> {
        try {
            let content = String.fromUtf8(File.readFrom(path))
            let lines = parseEnvFile(content)
            for (line in lines) {
                if (line.isKeyValue()) {
                    if (let Some(k) <- line.key) {
                        if (k == key) {
                            return line.value
                        }
                    }
                }
            }
        } catch (e: Exception) {
            LogUtils.error("EnvFileService", "Failed to read env value for key ${key}: ${e.message}")
        }
        None<String>
    }

    public func writeEnvKeyValue(path: String, key: String, value: String): Bool {
        try {
            let content = readEnvFileContent(path)
            let lines = parseEnvFile(content)
            var found = false
            for (i in 0..lines.size) {
                if (lines[i].isKeyValue()) {
                    if (let Some(k) <- lines[i].key) {
                        if (k == key) {
                            lines[i].value = Some(value)
                            found = true
                            break
                        }
                    }
                }
            }
            if (!found) {
                let newLine = EnvLine()
                newLine.lineType = KeyValue
                newLine.key = Some(key)
                newLine.value = Some(value)
                newLine.rawLine = "${key}=${value}"
                lines.add(newLine)
            }
            let newContent = serializeEnvFile(lines)
            atomicWriteFile(path, newContent)
            true
        } catch (e: Exception) {
            LogUtils.error("EnvFileService", "Failed to write env key ${key}: ${e.message}")
            false
        }
    }

    public func writeEnvKeyValues(path: String, items: HashMap<String, String>): Bool {
        try {
            let content = readEnvFileContent(path)
            let lines = parseEnvFile(content)
            for ((key, value) in items) {
                var found = false
                for (i in 0..lines.size) {
                    if (lines[i].isKeyValue()) {
                        if (let Some(k) <- lines[i].key) {
                            if (k == key) {
                                lines[i].value = Some(value)
                                found = true
                                break
                            }
                        }
                    }
                }
                if (!found) {
                    let newLine = EnvLine()
                    newLine.lineType = KeyValue
                    newLine.key = Some(key)
                    newLine.value = Some(value)
                    newLine.rawLine = "${key}=${value}"
                    lines.add(newLine)
                }
            }
            let newContent = serializeEnvFile(lines)
            atomicWriteFile(path, newContent)
            true
        } catch (e: Exception) {
            LogUtils.error("EnvFileService", "Failed to write env key values: ${e.message}")
            false
        }
    }

    public func backupEnvFile(path: String): Option<String> {
        try {
            let timestamp = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
            let backupPath = "${path}.backup-${timestamp}"
            let content = File.readFrom(path)
            File.writeTo(backupPath, content)
            LogUtils.info("EnvFileService", "Backed up env file to: ${backupPath}")
            Some(backupPath)
        } catch (e: Exception) {
            LogUtils.error("EnvFileService", "Failed to backup env file: ${e.message}")
            None<String>
        }
    }

    public func restoreBackup(backupPath: String, targetPath: String): Bool {
        try {
            let content = File.readFrom(backupPath)
            File.writeTo(targetPath, content)
            LogUtils.info("EnvFileService", "Restored env file from: ${backupPath}")
            true
        } catch (e: Exception) {
            LogUtils.error("EnvFileService", "Failed to restore backup: ${e.message}")
            false
        }
    }

    public func envFileExists(path: String): Bool {
        try {
            let content = File.readFrom(path)
            LogUtils.info("EnvFileService", ".env file exists at: ${path}")
            true
        } catch (e: Exception) {
            LogUtils.warn("EnvFileService", ".env file not found or unreadable at: ${path}, error: ${e.message}")
            false
        }
    }

    private func readEnvFileContent(path: String): String {
        String.fromUtf8(File.readFrom(path))
    }

    private func atomicWriteFile(path: String, content: String): Unit {
        let tmpPath = "${path}.tmp"
        File.writeTo(tmpPath, content.toArray())
        try {
            rename(Path(tmpPath), to: Path(path), overwrite: true)
        } catch (e: Exception) {
            File.writeTo(path, content.toArray())
            try {
                remove(Path(tmpPath))
            } catch (_: Exception) {}
        }
    }
}