/*
 * Copyright (c) UCToo Co., Ltd. 2024-2026. All rights reserved.
 */
package magic.scripts.package_release

import std.fs.*
import std.process.{launch, ProcessRedirect, SubProcess}
import std.convert.*
import std.collection.ArrayList
import std.env.getVariable
import std.time.DateTime
import std.unicode.*

func getVersionFromCjpm(): String {
    let cjpmPath = Path("./cjpm.toml")
    if (exists(cjpmPath)) {
        try {
            let contentBytes = File.readFrom(cjpmPath)
            let content = String.fromUtf8(contentBytes)
            let lines = content.split('\n')
            for (line in lines) {
                if (line.trim().startsWith("version = ")) {
                    let versionPart = line.trim()["version = ".size..]
                    let version = versionPart.trim().replace("\"", "")
                    return version
                }
            }
        } catch (e: Exception) {
            println("[WARN] Failed to read version from cjpm.toml: ${e.message}")
        }
    }
    return "0.0.1"
}

func getPlatformSuffix(): String {
    let os = getVariable("OS")
    if (os.isSome()) {
        let osName = os.getOrThrow()
        let osLower = osName.toLower()
        if (osLower.contains("windows") || osLower.contains("win")) {
            return ".exe"
        }
    }
    return ""
}

func getCurrentPlatform(): String {
    let os = getVariable("OS")
    let arch = getVariable("PROCESSOR_ARCHITECTURE")
    
    if (os.isSome()) {
        let osName = os.getOrThrow()
        let osLower = osName.toLower()
        let archName = if (arch.isSome()) { 
            let archValue = arch.getOrThrow()
            archValue.toLower() 
        } else { 
            "x64" 
        }
        
        if (osLower.contains("windows") || osLower.contains("win")) {
            if (archName.contains("arm64") || archName.contains("aarch64")) {
                return "win-arm64"
            }
            return "win-x64"
        }
    }
    return "win-x64"
}

func getBuildDate(): String {
    let now = DateTime.now()
    let year = now.year
    let month = now.month
    let day = now.dayOfMonth
    let monthValue: Int64 = match (month) {
        case January => 1
        case February => 2
        case March => 3
        case April => 4
        case May => 5
        case June => 6
        case July => 7
        case August => 8
        case September => 9
        case October => 10
        case November => 11
        case December => 12
    }
    let monthStr = if (monthValue < 10) { "0${monthValue}" } else { monthValue.toString() }
    let dayStr = if (day < 10) { "0${day}" } else { day.toString() }
    return "${year}-${monthStr}-${dayStr}"
}

func getProjectRoot(): ?Path {
    var currentDir = canonicalize(Path("."))
    
    for (i in 0..10) {
        let cjpmPath = Path("${currentDir}/cjpm.toml")
        if (exists(cjpmPath)) {
            return currentDir
        }
        let parent = currentDir.parent
        if (parent.isEmpty()) {
            break
        }
        currentDir = parent
    }
    return None
}

func shouldExcludeDll(name: String): Bool {
    let excludePatterns = [
        "libmagic.examples.",
        "libmagic.test_",
        "libmagic.tests.",
        "magic.examples.",
        "magic.test_",
        "magic.tests."
    ]
    
    for (pattern in excludePatterns) {
        if (name.contains(pattern)) {
            return true
        }
    }
    return false
}

func shouldExcludeDirectory(dirName: String): Bool {
    let excludeDirs = [
        "examples",
        "test_",
        "tests",
        ".build-logs",
        ".bin-cache",
        ".cjpm-history"
    ]
    
    for (pattern in excludeDirs) {
        if (dirName.contains(pattern)) {
            return true
        }
    }
    return false
}

main(args: Array<String>): Unit {
    println("========================================")
    println("AgentSkills Runtime Package Script")
    println("========================================")
    println("")
    
    let projectRoot = getProjectRoot()
    if (projectRoot.isNone()) {
        println("[ERROR] Could not find project root (directory containing cjpm.toml)")
        println("Please run this script from the project root directory or a subdirectory.")
        return
    }
    
    let rootPath = projectRoot.getOrThrow()
    println("[INFO] Project root: ${rootPath}")
    
    let version = getVersionFromCjpm()
    let platform = if (args.size > 0) { args[0] } else { getCurrentPlatform() }
    
    let targetDir = Path("${rootPath}/target/release")
    let releaseDir = Path("${rootPath}/release")
    let binDir = Path("${targetDir}/bin")
    
    println("Version: ${version}")
    println("Platform: ${platform}")
    println("Target dir: ${targetDir}")
    println("")
    
    if (!exists(targetDir)) {
        println("[ERROR] Build directory not found: ${targetDir}")
        println("Please run 'cjpm build' first from the project root directory.")
        return
    }
    
    if (!exists(releaseDir)) {
        Directory.create(releaseDir, recursive: true)
        println("[INFO] Created release directory: ${releaseDir}")
    }
    
    let totalDlls = ArrayList<String>()
    let excludedDlls = ArrayList<String>()
    
    println("")
    println("[STEP] Copying magic DLLs to bin (excluding examples/tests)...")
    
    let magicDir = Path("${targetDir}/magic")
    if (exists(magicDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(magicDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    if (shouldExcludeDll(name)) {
                        excludedDlls.add(name)
                        return true
                    }
                    
                    let destPath = Path("${binDir}/${name}")
                    if (!exists(destPath)) {
                        copy(fileInfo.path.toString(), to: destPath.toString(), overwrite: false)
                        dllCount.add(name)
                        totalDlls.add(name)
                    }
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} magic DLLs to bin/")
        if (excludedDlls.size > 0) {
            println("  [INFO] Excluded ${excludedDlls.size.toString()} example/test DLLs")
        }
    } else {
        println("  [WARN] Directory not found: ${magicDir}")
    }
    
    println("")
    println("[STEP] Copying commonmark4cj DLLs to bin...")
    
    let commonmarkDir = Path("${targetDir}/commonmark4cj")
    if (exists(commonmarkDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(commonmarkDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    if (!exists(destPath)) {
                        copy(fileInfo.path.toString(), to: destPath.toString(), overwrite: false)
                        dllCount.add(name)
                        totalDlls.add(name)
                    }
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} commonmark4cj DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${commonmarkDir}")
    }
    
    println("")
    println("[STEP] Copying yaml4cj DLLs to bin...")
    
    let yamlDir = Path("${targetDir}/yaml4cj")
    if (exists(yamlDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(yamlDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    if (!exists(destPath)) {
                        copy(fileInfo.path.toString(), to: destPath.toString(), overwrite: false)
                        dllCount.add(name)
                        totalDlls.add(name)
                    }
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} yaml4cj DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${yamlDir}")
    }
    
    println("")
    println("[STEP] Copying cangjie-stdx libraries to bin...")
    
    let stdxDir = Path("${rootPath}/libs/cangjie-stdx-windows-x64-1.0.0.1/windows_x86_64_llvm/dynamic/stdx")
    if (exists(stdxDir) && exists(binDir)) {
        let stdxCount = ArrayList<String>()
        
        Directory.walk(stdxDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    if (!exists(destPath)) {
                        copy(fileInfo.path.toString(), to: destPath.toString(), overwrite: false)
                        stdxCount.add(name)
                        totalDlls.add(name)
                    }
                }
            }
            true
        }
        
        println("  [OK] Copied ${stdxCount.size.toString()} stdx DLLs to bin/")
    } else {
        println("  [WARN] stdx directory not found: ${stdxDir}")
    }
    
    println("")
    println("[STEP] Copying cangjie runtime libraries to bin...")
    
    let cangjieHome = getVariable("CANGJIE_HOME")
    if (cangjieHome.isSome()) {
        let home = cangjieHome.getOrThrow()
        let runtimeDir = Path("${home}/runtime/lib/windows_x86_64_llvm")
        if (exists(runtimeDir) && exists(binDir)) {
            let runtimeCount = ArrayList<String>()
            
            Directory.walk(runtimeDir.toString()) { fileInfo =>
                if (!fileInfo.isDirectory()) {
                    let name = fileInfo.path.fileName
                    
                    if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                        let destPath = Path("${binDir}/${name}")
                        if (!exists(destPath)) {
                            copy(fileInfo.path.toString(), to: destPath.toString(), overwrite: false)
                            runtimeCount.add(name)
                            totalDlls.add(name)
                        }
                    }
                }
                true
            }
            
            println("  [OK] Copied ${runtimeCount.size.toString()} runtime DLLs to bin/")
        } else {
            println("  [WARN] runtime directory not found: ${runtimeDir}")
        }
    } else {
        println("  [WARN] CANGJIE_HOME environment variable not set")
        println("  [INFO] Please ensure CANGJIE runtime DLLs are available in PATH")
    }
    
    println("")
    println("[STEP] Creating entry point...")
    
    let entryExe = Path("${binDir}/agentskills-runtime.exe")
    let apiExe = Path("${binDir}/magic.api.exe")
    if (exists(apiExe)) {
        copy(apiExe.toString(), to: entryExe.toString(), overwrite: true)
        println("  [OK] Created agentskills-runtime.exe from magic.api.exe")
    } else if (exists(entryExe)) {
        println("  [OK] agentskills-runtime.exe already exists")
    } else {
        println("  [WARN] magic.api.exe not found, entry point may be missing")
    }
    
    println("")
    println("[STEP] Creating version file...")
    
    let buildDate = getBuildDate()
    let versionFile = Path("${targetDir}/VERSION")
    let versionContent = "AGENTSKILLS_RUNTIME_VERSION=${version}\nBUILD_PLATFORM=${platform}\nBUILD_DATE=${buildDate}\n"
    File.writeTo(versionFile, versionContent.toArray())
    println("  [OK] VERSION file created")
    println("  [INFO] Version: ${version}, Platform: ${platform}, Date: ${buildDate}")
    
    println("")
    println("[STEP] Copying .env.example...")
    
    let envExampleSrc = Path("${rootPath}/.env.example")
    let envExampleDest = Path("${targetDir}/.env.example")
    if (exists(envExampleSrc)) {
        copy(envExampleSrc.toString(), to: envExampleDest.toString(), overwrite: true)
        println("  [OK] Copied .env.example to release package")
    } else {
        println("  [WARN] .env.example not found at ${envExampleSrc}, skipping")
    }
    
    println("")
    println("[STEP] Updating package.json runtime version...")
    
    let packageJsonPath = Path("${rootPath}/sdk/javascript/package.json")
    if (exists(packageJsonPath)) {
        try {
            let packageJsonBytes = File.readFrom(packageJsonPath)
            let packageJsonContent = String.fromUtf8(packageJsonBytes)
            let updatedContent = packageJsonContent.replace(
                "\"version\": \"${version}\"",
                "\"version\": \"${version}\""
            )
            let versionPattern = "\"runtime\": {\n    \"version\": \""
            let versionEndPattern = "\","
            let startIdx = updatedContent.indexOf(versionPattern)
            if (startIdx.isSome()) {
                let start = startIdx.getOrThrow() + versionPattern.size
                let endIdx = updatedContent.indexOf(versionEndPattern, start)
                if (endIdx.isSome()) {
                    let end = endIdx.getOrThrow()
                    let oldVersion = updatedContent[start..end]
                    if (oldVersion != version) {
                        let beforeVersion = updatedContent[0..start]
                        let afterVersion = updatedContent[end..updatedContent.size]
                        let newContent = beforeVersion + version + afterVersion
                        File.writeTo(packageJsonPath, newContent.toArray())
                        println("  [OK] Updated runtime version in package.json: ${oldVersion} -> ${version}")
                    } else {
                        println("  [OK] Runtime version already up to date: ${version}")
                    }
                }
            }
        } catch (e: Exception) {
            println("  [WARN] Could not update package.json: ${e.message}")
        }
    } else {
        println("  [WARN] package.json not found at ${packageJsonPath}")
    }
    
    println("")
    println("[STEP] Removing unnecessary directories from release package...")
    
    let dirsToRemove = ["examples", "tests", ".build-logs", ".bin-cache", ".cjpm-history"]
    for (dirName in dirsToRemove) {
        let dirPath = Path("${targetDir}/${dirName}")
        if (exists(dirPath)) {
            try {
                remove(dirPath, recursive: true)
                println("  [OK] Removed: ${dirName}/")
            } catch (e: Exception) {
                println("  [WARN] Could not remove ${dirName}: ${e.message}")
            }
        }
    }
    
    println("")
    println("[STEP] Creating archive...")
    
    let archiveName = "agentskills-runtime-${platform}.tar.gz"
    let archivePath = Path("${releaseDir}/${archiveName}")
    
    let tarArgs = ["-czf", archivePath.toString(), "-C", "${rootPath}/target", "release"]
    let tarProcess = launch("tar", tarArgs)
    let exitCode = tarProcess.wait()
    
    if (exitCode == 0) {
        println("  [OK] Archive created: ${releaseDir}/${archiveName}")
    } else {
        println("  [ERROR] Failed to create archive (exit code: ${exitCode.toString()})")
        return
    }
    
    println("")
    println("========================================")
    println("Package completed successfully!")
    println("========================================")
    println("Output: ${releaseDir}/${archiveName}")
    println("Version: ${version}")
    println("Platform: ${platform}")
    println("Build Date: ${buildDate}")
    println("Total DLLs copied: ${totalDlls.size.toString()}")
    if (excludedDlls.size > 0) {
        println("Excluded DLLs: ${excludedDlls.size.toString()}")
    }
    println("")
    println("Directory structure in archive:")
    println("  release/")
    println("    bin/              - Executables and ALL DLLs")
    println("    magic/            - Runtime modules")
    println("    commonmark4cj/    - Markdown parser")
    println("    yaml4cj/          - YAML parser")
    println("    VERSION           - Version info")
    println("    .env.example      - Configuration template")
    println("")
    println("Usage:")
    println("  1. Extract the archive to your desired location")
    println("  2. Copy .env.example to bin/.env and configure API tokens")
    println("  3. Run: agentskills-runtime.exe [port]")
    println("========================================")
}
