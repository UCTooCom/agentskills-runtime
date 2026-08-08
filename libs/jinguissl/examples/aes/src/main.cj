package sample_aes

/** aes — AES 后端探测与引擎解析 */
import jinguissl.contract.*

main() {
    println("=== AES Backend Probing Sample ===")

    // List all hardware mount points
    let mounts = contractAesListHardwareMountPoints()
    println("Hardware mount points (${mounts.size} found):")
    for (mount in mounts) {
        println("  - ${mount.backend} (available=${mount.available}, accelerated=${mount.accelerated})")
    }

    // Default hardware backend hint
    let hint = contractAesDefaultHardwareBackendHint()
    println("Default backend hint: ${hint}")

    // Probe a specific backend
    let probe = contractAesProbeHardware(backendHint: "shim")
    println("Shim probe: available=${probe.available}, accelerated=${probe.accelerated}")

    // Resolve AES engine with Auto mode
    let engineInfo = contractResolveAesEngine()
    println("Resolved engine: ${engineInfo.active.toString()}")
    println("Backend: ${engineInfo.backend}")
    println("Accelerated: ${engineInfo.accelerated}")

    // Hardware roadmap
    let roadmap = contractAesHardwareRoadmap()
    println("Hardware roadmap (${roadmap.size} entries):")
    for (entry in roadmap) {
        println("  - ${entry.architecture}: ${entry.backend} (status=${entry.status})")
    }

    println("AES probing completed.")
}
