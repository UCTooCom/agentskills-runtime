import std.process.*
import std.fs.*

func getOsInfo() {
    @When[os == "Linux"]
    let os = "linux"

    @When[os == "Windows"]
    let os = "windows"

    @When[os == "macOS"]
    let os = "mac"

    @When[os != "Linux" && os != "Windows" && os != "macOS"]
    let os = "unknown"

    @When[arch == "aarch64"]
    let arch = "aarch64"

    @When[arch == "x86_64"]
    let arch = "x64"

    @When[arch != "x86_64" && arch != "aarch64"]
    let arch = "unknown"

    return (os, arch)
}

func downloadAndExtract(os: String, arch: String): Int64 {
    let version = "1.0.0.1"
    let url = "https://gitcode.com/Cangjie/cangjie-stdx-bin/releases/download/v${version}/cangjie-stdx-${os}-${arch}-${version}.zip"

    let installDir = "./libs"
    let targetDir = "${installDir}/cangjie-stdx-${os}-${arch}-${version}"
    let zipFile = "${installDir}/cangjie-stdx-${os}-${arch}-${version}.zip"

    // create target directory
    let targetDirPath = Path(targetDir)
    if (exists(targetDirPath)) {
        println("target dir ${targetDir} exists，skip downloading and unzipping")
        return 0
    } else {
        Directory.create(targetDirPath, recursive: true)
    }

    // download stdx zip file
    if (!exists(zipFile)) {
        println("download from ${url} ...")
        let downloadProc = if (os == "windows") {
            launch("powershell", ["-Command", "Invoke-WebRequest", "-Uri", url, "-OutFile", zipFile])
        } else {
            launch("curl", ["-L", "-o", zipFile, url])
        }
        let downloadResult = downloadProc.wait()

        if (downloadResult != 0) {
            println("download failed")
            remove(targetDirPath)
            return downloadResult
        }
    }

    // unzip file
    println("unzip file ${zipFile} to ${targetDir}...")
    let unzipProc = if (os == "windows") {
        launch("powershell", ["-Command", "Expand-Archive", "-Path", zipFile, "-DestinationPath", targetDir, "-Force"])
    } else {
        launch("unzip", ["-q", zipFile, "-d", targetDir])
    }
    let unzipResult = unzipProc.wait()

    // delete zip file
    let filePath = Path(zipFile)
    remove(filePath)

    if (unzipResult != 0) {
        println("unzipping failed")
        remove(targetDirPath)
        return unzipResult
    }

    return 0
}

func stagePreBuild(): Int64 {
    let (os, arch) = getOsInfo()

    if (os == "unknown" || arch == "unknown") {
        println("unsupported os or arch")
        return 1
    }

    println("os: ${os}, arch: ${arch}")
    return downloadAndExtract(os, arch)
}

func stagePostBuild(): Int64 {
    println("post-build: running package_release script...")
    let proc = launch("cjpm", ["run", "--skip-build", "--name", "magic.scripts.package_release"])
    let result = proc.wait()
    if (result != 0) {
        println("post-build: package_release script failed with exit code ${result}")
    } else {
        println("post-build: package_release script completed successfully")
    }
    return result
}

main(): Int64 {
    match (Process.current.arguments[0]) {
        case "pre-build" => stagePreBuild()
        case "post-build" => stagePostBuild()
        case _ => 0
    }
}
