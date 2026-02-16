/*
 * Copyright (c) UCToo Co., Ltd. 2024-2026. All rights reserved.
 */
package magic.scripts.package_release

import std.fs.*
import std.process.{launch, ProcessRedirect, SubProcess}
import std.convert.*
import std.collection.ArrayList

main(args: Array<String>): Unit {
    let version = if (args.size > 0) { args[0] } else { "0.0.1" }
    let platform = if (args.size > 1) { args[1] } else { "win-x64" }
    
    let projectDir = Path(".")
    let targetDir = Path("./target/release")
    let releaseDir = Path("./release")
    let packageDir = Path("./target/package")
    
    println("========================================")
    println("AgentSkills Runtime Package Script")
    println("========================================")
    println("Version: ${version}")
    println("Platform: ${platform}")
    println("")
    
    if (!exists(targetDir)) {
        println("[ERROR] Build directory not found: ${targetDir}")
        println("Please run 'cjpm build --release' first.")
        return
    }
    
    if (!exists(releaseDir)) {
        Directory.create(releaseDir, recursive: true)
        println("[INFO] Created release directory: ${releaseDir}")
    }
    
    if (exists(packageDir)) {
        remove(packageDir, recursive: true)
        println("[INFO] Cleaned old package directory")
    }
    Directory.create(packageDir, recursive: true)
    
    let binDir = Path("${packageDir}/bin")
    let libDir = Path("${packageDir}/lib")
    Directory.create(binDir, recursive: true)
    Directory.create(libDir, recursive: true)
    
    println("")
    println("[STEP 1] Copying API entry point...")
    
    let apiExe = Path("${targetDir}/bin/magic.api.exe")
    let apiCjo = Path("${targetDir}/bin/magic.api.cjo")
    
    if (exists(apiExe)) {
        copy(apiExe.toString(), to: "${binDir}/agentskills-runtime.exe", overwrite: true)
        println("  [OK] agentskills-runtime.exe")
    } else {
        println("  [WARN] magic.api.exe not found")
    }
    
    if (exists(apiCjo)) {
        copy(apiCjo.toString(), to: "${binDir}/agentskills-runtime.cjo", overwrite: true)
        println("  [OK] agentskills-runtime.cjo")
    } else {
        println("  [WARN] magic.api.cjo not found")
    }
    
    println("")
    println("[STEP 2] Copying dynamic libraries...")
    
    let magicDir = Path("${targetDir}/magic")
    if (exists(magicDir)) {
        let dllCount = ArrayList<String>()
        let cjoCount = ArrayList<String>()
        
        Directory.walk(magicDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    if (!name.contains("tests")) {
                        copy(fileInfo.path.toString(), to: "${libDir}/${name}", overwrite: true)
                        dllCount.add(name)
                    }
                }
                
                if (name.endsWith(".cjo")) {
                    if (!name.contains("tests") && !name.contains("examples")) {
                        copy(fileInfo.path.toString(), to: "${libDir}/${name}", overwrite: true)
                        cjoCount.add(name)
                    }
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} dynamic libraries")
        println("  [OK] Copied ${cjoCount.size.toString()} object files")
    } else {
        println("  [ERROR] Magic directory not found: ${magicDir}")
    }
    
    println("")
    println("[STEP 3] Creating version file...")
    
    let versionFile = Path("${packageDir}/VERSION")
    let versionContent = "AGENTSKILLS_RUNTIME_VERSION=${version}\nBUILD_PLATFORM=${platform}\nBUILD_DATE=2024-01-15\n"
    File.writeTo(versionFile, versionContent.toArray())
    println("  [OK] VERSION file created")
    
    println("")
    println("[STEP 4] Creating README...")
    
    let readmeFile = Path("${packageDir}/README.txt")
    let readmeContent = """
AgentSkills Runtime ${version}
==============================

This package contains the AgentSkills Runtime binaries.

Directory Structure:
  bin/              - Executable files
    agentskills-runtime.exe  - Main API server
  lib/              - Dynamic libraries and object files

Usage:
  1. Add bin/ directory to your PATH
  2. Run: agentskills-runtime.exe [port]
  3. Default port is 8080

For more information, visit:
  https://atomgit.com/uctoo/agentskills-runtime
  https://github.com/UCTooCom/agentskills-runtime

License: MIT
"""
    File.writeTo(readmeFile, readmeContent.toArray())
    println("  [OK] README.txt created")
    
    println("")
    println("[STEP 5] Creating archive...")
    
    let archiveName = "agentskills-runtime-${platform}.tar.gz"
    let archivePath = Path("${releaseDir}/${archiveName}")
    
    let tarArgs = ["-czf", archivePath.toString(), "-C", packageDir.toString(), "."]
    let tarProcess = launch("tar", tarArgs)
    let exitCode = tarProcess.wait()
    
    if (exitCode == 0) {
        println("  [OK] Archive created: ${archivePath}")
    } else {
        println("  [ERROR] Failed to create archive, exit code: ${exitCode.toString()}")
        println("  [INFO] Trying PowerShell Compress-Archive...")
        
        let zipName = "agentskills-runtime-${platform}.zip"
        let zipPath = Path("${releaseDir}/${zipName}")
        
        let psCmd = "Compress-Archive -Path '${packageDir}/*' -DestinationPath '${zipPath}' -Force"
        let psProcess = launch("powershell", ["-Command", psCmd])
        let psExitCode = psProcess.wait()
        
        if (psExitCode == 0) {
            println("  [OK] ZIP archive created: ${zipPath}")
        } else {
            println("  [ERROR] Failed to create ZIP archive")
        }
    }
    
    println("")
    println("[STEP 6] Cleaning up...")
    remove(packageDir, recursive: true)
    println("  [OK] Temporary files cleaned")
    
    println("")
    println("========================================")
    println("Package completed successfully!")
    println("Output: ${releaseDir}/${archiveName}")
    println("========================================")
}
