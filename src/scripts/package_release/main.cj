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
    let buildDate = DateTime.now().toString()
    
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
    println("[STEP] Copying f_orm DLLs to bin...")
    
    let fOrmDir = Path("${targetDir}/f_orm")
    if (exists(fOrmDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(fOrmDir.toString()) { fileInfo =>
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
        
        println("  [OK] Copied ${dllCount.size.toString()} f_orm DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${fOrmDir}")
    }
    
    println("")
    println("[STEP] Copying charset4cj DLLs to bin...")
    
    let charsetDir = Path("${targetDir}/charset4cj")
    if (exists(charsetDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(charsetDir.toString()) { fileInfo =>
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
        
        println("  [OK] Copied ${dllCount.size.toString()} charset4cj DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${charsetDir}")
    }
    
    println("")
    println("[STEP] Copying jwt4cj DLLs to bin...")
    
    let jwtDir = Path("${targetDir}/jwt4cj")
    if (exists(jwtDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(jwtDir.toString()) { fileInfo =>
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
        
        println("  [OK] Copied ${dllCount.size.toString()} jwt4cj DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${jwtDir}")
    }
    
    println("")
    println("[STEP] Copying logcj DLLs to bin...")
    
    let logDir = Path("${targetDir}/logcj")
    if (exists(logDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(logDir.toString()) { fileInfo =>
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
        
        println("  [OK] Copied ${dllCount.size.toString()} logcj DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${logDir}")
    }
    
    println("")
    println("[STEP] Copying f_data DLLs to bin...")
    
    let fDataDir = Path("${targetDir}/f_data")
    if (exists(fDataDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(fDataDir.toString()) { fileInfo =>
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
        
        println("  [OK] Copied ${dllCount.size.toString()} f_data DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${fDataDir}")
    }
    
    println("")
    println("[STEP] Copying f_config DLLs to bin...")
    
    let fConfigDir = Path("${targetDir}/f_config")
    if (exists(fConfigDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(fConfigDir.toString()) { fileInfo =>
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
        
        println("  [OK] Copied ${dllCount.size.toString()} f_config DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${fConfigDir}")
    }
    
    println("")
    println("[STEP] Copying opengauss DLLs to bin...")
    
    let opengaussDir = Path("${targetDir}/opengauss")
    if (exists(opengaussDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(opengaussDir.toString()) { fileInfo =>
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
        
        println("  [OK] Copied ${dllCount.size.toString()} opengauss DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${opengaussDir}")
    }
    
    println("")
    println("[STEP] Copying blowfish DLLs to bin...")
    
    let blowfishDir = Path("${targetDir}/blowfish")
    if (exists(blowfishDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(blowfishDir.toString()) { fileInfo =>
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
        
        println("  [OK] Copied ${dllCount.size.toString()} blowfish DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${blowfishDir}")
    }
    
    // Copy all remaining Fountain framework modules
    let fountainModules = [
        "f_aspect", "f_base", "f_bean", "f_cache", "f_cmd", 
        "f_collection", "f_concurrent", "f_exception", "f_io", 
        "f_log", "f_macros", "f_mockdb", "f_pool", 
        "f_random", "f_regex", "f_time", "f_util", "f_version"
    ]
    
    for (moduleName in fountainModules) {
        println("")
        println("[STEP] Copying ${moduleName} DLLs to bin...")
        
        let moduleDir = Path("${targetDir}/${moduleName}")
        if (exists(moduleDir) && exists(binDir)) {
            let dllCount = ArrayList<String>()
            
            Directory.walk(moduleDir.toString()) { fileInfo =>
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
            
            println("  [OK] Copied ${dllCount.size.toString()} ${moduleName} DLLs to bin/")
        } else {
            println("  [WARN] Directory not found: ${moduleDir}")
        }
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
    println("[STEP] Creating SSL directory structure...")
    
    // Create SSL directories (but DO NOT copy actual certificates - they are sensitive)
    let sslDest = Path("${targetDir}/ssl")
    let sslBinDest = Path("${binDir}/ssl")
    
    if (!exists(sslDest)) {
        Directory.create(sslDest, recursive: true)
        println("  [OK] Created ssl directory in release root")
    }
    
    if (!exists(sslBinDest)) {
        Directory.create(sslBinDest, recursive: true)
        println("  [OK] Created ssl directory in bin")
    }
    
    // Create README in ssl directory to guide users
    let sslReadme = """
# SSL Certificates Directory

This directory should contain your SSL certificates for HTTPS support.

## Required Files

- `server.crt` - SSL certificate file
- `server.key` - SSL private key file

## How to Generate Self-Signed Certificates (for development)

```bash
# Using OpenSSL
openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -days 365 -nodes

# Or using the provided script
../bin/generate_ssl_cert.sh
```

## Production Use

For production, use certificates from a trusted CA like Let's Encrypt:

```bash
# Using certbot
certbot certonly --standalone -d yourdomain.com
```

Then copy the certificates to this directory:
- `fullchain.pem` -> `server.crt`
- `privkey.pem` -> `server.key`

## Security Note

**NEVER commit actual SSL certificates to version control!**
"""
    
    let sslReadmePath = Path("${sslDest}/README.md")
    File.writeTo(sslReadmePath, sslReadme.toArray())
    println("  [OK] Created SSL README with instructions")
    
    let sslReadmeBinPath = Path("${sslBinDest}/README.md")
    File.writeTo(sslReadmeBinPath, sslReadme.toArray())
    println("  [OK] Created SSL README in bin directory")
    
    // Note: Actual SSL certificates should NOT be packaged
    println("  [INFO] SSL certificates will NOT be packaged (sensitive information)")
    println("  [INFO] Users should generate or copy their own certificates")
    
    println("")
    println("[STEP] Creating logs directory...")
    
    let logsDir = Path("${targetDir}/logs")
    let logsBinDir = Path("${binDir}/logs")
    
    if (!exists(logsDir)) {
        Directory.create(logsDir, recursive: true)
        println("  [OK] Created logs directory in release")
    }
    
    if (!exists(logsBinDir)) {
        Directory.create(logsBinDir, recursive: true)
        println("  [OK] Created logs directory in bin")
    }
    
    println("")
    println("[STEP] Copying CJO files to bin...")
    
    let cjoCount = ArrayList<String>()
    
    // Copy all CJO files from target/release subdirectories to bin
    Directory.walk(targetDir.toString()) { fileInfo =>
        if (!fileInfo.isDirectory()) {
            let name = fileInfo.path.fileName
            
            // Skip if already in bin directory
            let parentPath = fileInfo.path.parent
            if (parentPath.toString() == binDir.toString()) {
                return true
            }
            
            if (name.endsWith(".cjo")) {
                let destPath = Path("${binDir}/${name}")
                if (!exists(destPath)) {
                    copy(fileInfo.path.toString(), to: destPath.toString(), overwrite: false)
                    cjoCount.add(name)
                }
            }
        }
        true
    }
    
    println("  [OK] Copied ${cjoCount.size.toString()} CJO files to bin/")
    
    println("")
    println("[STEP] Creating entry point...")
    
    let entryExe = Path("${binDir}/agentskills-runtime.exe")
    let appExe = Path("${binDir}/magic.app.exe")
    if (exists(appExe)) {
        copy(appExe.toString(), to: entryExe.toString(), overwrite: true)
        println("  [OK] Created agentskills-runtime.exe from magic.app.exe")
    } else if (exists(entryExe)) {
        println("  [OK] agentskills-runtime.exe already exists")
    } else {
        println("  [WARN] magic.app.exe not found, entry point may be missing")
    }
    
    println("")
    println("[STEP] Copying .env.example...")
    
    // Copy .env.example to release root (configuration template)
    let envExampleSrc = Path("${rootPath}/.env.example")
    let envExampleDest = Path("${targetDir}/.env.example")
    if (exists(envExampleSrc)) {
        copy(envExampleSrc.toString(), to: envExampleDest.toString(), overwrite: true)
        println("  [OK] Copied .env.example to release package")
        
        // Also copy to bin directory for convenience
        let envExampleBinDest = Path("${binDir}/.env.example")
        copy(envExampleSrc.toString(), to: envExampleBinDest.toString(), overwrite: true)
        println("  [OK] Copied .env.example to bin directory")
    } else {
        println("  [WARN] .env.example not found at ${envExampleSrc}, skipping")
    }
    
    // Note: .env file should NOT be packaged as it contains sensitive information
    // Users should create .env from .env.example after extracting the package
    println("  [INFO] .env file will NOT be packaged (contains sensitive information)")
    println("  [INFO] Users should create .env from .env.example after extraction")
    
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
    println("Total CJOs copied: ${cjoCount.size.toString()}")
    if (excludedDlls.size > 0) {
        println("Excluded DLLs: ${excludedDlls.size.toString()}")
    }
    println("")
    println("Directory structure in archive:")
    println("  release/")
    println("    bin/              - Executables, ALL DLLs, ALL CJOs, .env.example, ssl/, logs/")
    println("    magic/            - Runtime modules")
    println("    commonmark4cj/    - Markdown parser")
    println("    yaml4cj/          - YAML parser")
    println("    f_orm/            - ORM database framework")
    println("    f_data/           - Data processing framework")
    println("    f_config/         - Configuration management")
    println("    charset4cj/       - Character encoding library")
    println("    jwt4cj/           - JWT authentication library")
    println("    logcj/            - Logging library")
    println("    opengauss/        - OpenGauss database driver")
    println("    blowfish/         - Blowfish encryption library")
    println("    ssl/              - SSL certificates directory (empty, users provide their own)")
    println("    logs/             - Log output directory")
    println("    VERSION           - Version info")
    println("    .env.example      - Configuration template (users create .env from this)")
    println("")
    println("Setup Instructions:")
    println("  1. Extract the archive to your desired location")
    println("  2. Copy .env.example to .env and configure:")
    println("     - Database connection settings")
    println("     - API tokens (STEPFUN_API_KEY, MAAS_API_KEY, etc.)")
    println("     - SSL certificate paths")
    println("     - Other required settings")
    println("  3. Generate or copy SSL certificates to ssl/ directory:")
    println("     - ssl/server.crt (certificate)")
    println("     - ssl/server.key (private key)")
    println("  4. Run from release directory: bin/agentskills-runtime.exe [port]")
    println("     Or from bin directory: agentskills-runtime.exe [port]")
    println("")
    println("Security Notes:")
    println("  - .env file contains sensitive information, NEVER commit it to version control")
    println("  - SSL certificates are private, NEVER share or commit them")
    println("  - Always use environment variables or secure storage for production")
    println("========================================")
}
