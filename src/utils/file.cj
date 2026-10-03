/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */
package magic.utils

import std.fs.{File, Path, Directory, FileInfo}

@When[cjc_version >= "1.0.0"]
import std.fs.OpenMode

import std.collection.*
@When[cjc_version >= "1.0.0"]
public import std.fs.{exists, removeIfExists, canonicalize, rename}
@When[cjc_version >= "1.0.0"]
public import std.io.readToEnd

import std.io.{StringReader, StringWriter, IOException}

/**
 * Save the content to a temp file and return its path.
 */
protected func saveTempFile(tempDir: String, content: String): Path {
    if (!exists(tempDir)) {
        Directory.create(tempDir, recursive: true)
    }
    let tempFile = File.createTemp(tempDir)
    let writer = StringWriter(tempFile)
    writer.write(content)
    writer.flush()
    tempFile.close()
    return tempFile.info.path
}

@When[cjc_version < "1.0.0"]
protected func readToEnd(file: File): Array<Byte> {
    return file.readToEnd()
}

@When[cjc_version < "1.0.0"]
protected func exists(path: String): Bool {
    return File.exists(path) || Directory.exists(path)
}

@When[cjc_version < "1.0.0"]
protected func exists(path: Path): Bool {
    return File.exists(path) || Directory.exists(path)
}

@When[cjc_version < "1.0.0"]
protected func removeIfExists(path: Path): Unit {
    if (File.exists(path)) {
        File.delete(path)
    } else if (Directory.exists(path)) {
        Directory.delete(path)
    }
}

@When[cjc_version < "1.0.0"]
protected func removeIfExists(path: String): Unit {
    removeIfExists(Path(path))
}

@When[cjc_version < "1.0.0"]
protected func fileNameWithoutExt(path: Path): String {
    return path.fileNameWithoutExtension ?? ""
}

@When[cjc_version >= "1.0.0"]
protected func fileNameWithoutExt(path: Path): String {
    return path.fileNameWithoutExtension
}

@When[cjc_version < "1.0.0"]
protected func fileExt(path: Path): String {
    return path.extensionName ?? ""
}

@When[cjc_version >= "1.0.0"]
protected func fileExt(path: Path): String {
    return path.extensionName
}

@When[cjc_version < "1.0.0"]
protected func isRegularFile(fileInfo: FileInfo): Bool {
    return fileInfo.isFile()
}

@When[cjc_version >= "1.0.0"]
protected func isRegularFile(fileInfo: FileInfo): Bool {
    return fileInfo.isRegular()
}

@When[cjc_version < "1.0.0"]
protected func canonicalize(path: Path): Path {
    return path.toCanonical()
}

@When[cjc_version < "1.0.0"]
protected func directoryOf(path: Path): Path {
    return path.directoryName ?? Path("")
}

@When[cjc_version >= "1.0.0"]
protected func directoryOf(path: Path): Path {
    return path.parent
}

@When[cjc_version < "1.0.0"]
protected func move(source: Path, to: Path, overwrite: Bool): Unit {
    if (source.isFile()) {
        File.move(source, to, overwrite)
    } else if (source.isDirectory()) {
        Directory.move(source, to, overwrite)
    }
}

@When[cjc_version >= "1.0.0"]
protected func move(source: Path, to: Path, overwrite: Bool): Unit {
    rename(source, to: to, overwrite: overwrite)
}

/**
 * Make sure the path exists and is a regular file, then read its content
 */
public func readFile(path: Path,
                     withLineNumber!: Bool = false,
                     startLine!: Int64 = 1,
                     endLine!: Int64 = Int64.Max): String {
    let (_, content) = readFileWithTruncateInfo(
        path, withLineNumber: withLineNumber, startLine: startLine, endLine: endLine
    )
    return content
}

/**
 * Read a file with line number and truncate info
 */
func readFileWithTruncateInfo(
        path: Path,
        withLineNumber!: Bool ,
        startLine!: Int64,
        endLine!: Int64): (Bool, String) {
    // 【2026-10-02 实测修复】endLine < 0 表示「读到文件末尾」。
    // FileReadTool 的 endLine 默认值就是 -1（见 src/tool/file_tools.cj），而这里此前
    // 直接拿 -1 参与 `currentLine <= endLine` 比较 —— 恒为假，于是任何一次未显式传
    // endLine 的读取都一行不收、返回空串，紧接着触发 file_tools.cj 的编码回退分支，
    // 把中文全部替换成 '?'。
    // 现场：web 聊天跑 sdd research（日志 agentskills-runtime-20261002-002418）
    // 5 次 file_read 全部返回 ???，agent 被迫自造 python 脚本绕路，烧掉约 1/3 步数预算。
    // 修法：负值统一归一到 Int64.Max（无上界），语义与 -1 的约定一致。
    let upperBound = if (endLine < 0) { Int64.Max } else { endLine }
    var currentLine = 1
    let lines = ArrayList<String>()

    try (file = File(path, OpenMode.Read)) {
        let reader = StringReader(file)
        while (let Some(line) <- reader.readln()) {
            if (currentLine < startLine) {
                // Skip this line
            } else if (currentLine <= upperBound) {
                // End of file reached
                lines.add(line)
            } else {
                break // Stop reading further
            }
            currentLine += 1
        }
    }

    if (withLineNumber) {
        // Format with line number (right-aligned)
        let width = countDigits(currentLine)
        return (
            currentLine > upperBound,
            String.join(
                lines.toArray() |>
                    enumerate |>
                    map { tuple =>
                        let lineNo = tuple[0] + startLine
                        let line = tuple[1]
                        return "${lineNo.toString().padStart(width)}  ${line}"
                    } |>
                    collectArray,
                delimiter: "\n"
            )
        )
    } else {
        return (
            currentLine > upperBound,
            String.join(lines.toArray(), delimiter: "\n")
        )
    }
}

/**
 * Alternative implementation (without logarithm)
 */
public func countDigits(num: Int64): Int64 {
    // Handle 0 case
    if (num == 0) {
        return 1
    }
    // Handle negative numbers by taking absolute value
    var n = if (num < 0) { -num } else { num }

    var count = 0
    while (n > 0) {
        n = n / 10
        count += 1
    }
    return count
}

protected func writeFile(path: Path, content: String): Unit {
    try (file = File(path, OpenMode.Write)) {
        let writer = StringWriter(file)
        writer.write(content)
        writer.flush()
    }
}

protected func readLines(path: Path): Array<String> {
    let content = readFile(path)
    let lines = content.split('\n')
    return lines |> map { line: String => line.trimAscii() } |> collectArray
}

protected func writeLines(path: Path, lines: Array<String>): Unit {
    try (file = File(path, OpenMode.Append)) {
        for (line in lines) {
            file.write("${line}\n".toArray())
        }
    }
}