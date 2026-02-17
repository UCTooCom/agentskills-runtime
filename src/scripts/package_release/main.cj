/*
 * Copyright (c) UCToo Co., Ltd. 2024-2026. All rights reserved.
 */
package magic.scripts.package_release

import std.fs.*
import std.process.{launch, ProcessRedirect, SubProcess}
import std.convert.*
import std.collection.ArrayList
import std.env.getVariable

main(args: Array<String>): Unit {
    let version = if (args.size > 0) { args[0] } else { "0.0.1" }
    let platform = if (args.size > 1) { args[1] } else { "win-x64" }
    
    let targetDir = Path("./target/release")
    let releaseDir = Path("./release")
    let binDir = Path("${targetDir}/bin")
    
    println("========================================")
    println("AgentSkills Runtime Package Script")
    println("========================================")
    println("Version: ${version}")
    println("Platform: ${platform}")
    println("")
    
    if (!exists(targetDir)) {
        println("[ERROR] Build directory not found: ${targetDir}")
        println("Please run 'cjpm build' first.")
        return
    }
    
    if (!exists(releaseDir)) {
        Directory.create(releaseDir, recursive: true)
        println("[INFO] Created release directory: ${releaseDir}")
    }
    
    let dllDirs = ["magic", "commonmark4cj", "yaml4cj"]
    let totalDlls = ArrayList<String>()
    
    for (dirName in dllDirs) {
        println("")
        println("[STEP] Copying ${dirName} DLLs to bin...")
        
        let srcDir = Path("${targetDir}/${dirName}")
        if (exists(srcDir) && exists(binDir)) {
            let dllCount = ArrayList<String>()
            
            Directory.walk(srcDir.toString()) { fileInfo =>
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
            
            println("  [OK] Copied ${dllCount.size.toString()} ${dirName} DLLs to bin/")
        } else {
            println("  [WARN] Directory not found: ${srcDir}")
        }
    }
    
    println("")
    println("[STEP] Copying cangjie-stdx libraries to bin...")
    
    let stdxDir = Path("./libs/cangjie-stdx-windows-x64-1.0.0.1/windows_x86_64_llvm/dynamic/stdx")
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
    if (exists(apiExe) && !exists(entryExe)) {
        copy(apiExe.toString(), to: entryExe.toString(), overwrite: true)
        println("  [OK] Created agentskills-runtime.exe")
    } else if (exists(entryExe)) {
        println("  [OK] agentskills-runtime.exe already exists")
    }
    
    println("")
    println("[STEP] Creating version file...")
    
    let versionFile = Path("${targetDir}/VERSION")
    let versionContent = "AGENTSKILLS_RUNTIME_VERSION=${version}\nBUILD_PLATFORM=${platform}\nBUILD_DATE=2026-02-16\n"
    File.writeTo(versionFile, versionContent.toArray())
    println("  [OK] VERSION file created")
    
    println("")
    println("[STEP] Copying .env.example...")
    
    let envExampleSrc = Path("./release/.env.example")
    let envExampleDest = Path("${targetDir}/.env.example")
    if (exists(envExampleSrc)) {
        copy(envExampleSrc.toString(), to: envExampleDest.toString(), overwrite: true)
        println("  [OK] Copied .env.example to release package")
    } else {
        println("  [WARN] .env.example not found, skipping")
    }
    
    println("")
    println("[STEP] Creating archive...")
    
    let archiveName = "agentskills-runtime-${platform}.tar.gz"
    let archivePath = Path("${releaseDir}/${archiveName}")
    
    let tarArgs = ["-czf", archivePath.toString(), "-C", "./target", "release"]
    let tarProcess = launch("tar", tarArgs)
    let exitCode = tarProcess.wait()
    
    if (exitCode == 0) {
        println("  [OK] Archive created: ./release/${archiveName}")
    } else {
        println("  [ERROR] Failed to create archive")
        return
    }
    
    println("")
    println("========================================")
    println("Package completed successfully!")
    println("Output: ./release/${archiveName}")
    println("Total DLLs copied: ${totalDlls.size.toString()}")
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
    println("Note: All required DLLs (stdx, runtime, magic) are in bin/")
    println("      Users can run agentskills-runtime.exe directly.")
    println("      Copy .env.example to bin/.env and configure API tokens.")
    println("========================================")
}
