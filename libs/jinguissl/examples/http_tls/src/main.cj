package sample_http_tls
/** HTTP/TLS 启动材料示例 */
import std.fs.File
import jinguissl.contract.*

main() {
    println("=== HTTP/TLS Startup Material Sample ===")

    let leafPem = String.fromUtf8(File.readFrom("../../testdata/x509/policy_leaf.pem"))
    let intermediatePem = String.fromUtf8(File.readFrom("../../testdata/x509/policy_intermediate.pem"))
    let rootPem = String.fromUtf8(File.readFrom("../../testdata/x509/policy_root.pem"))
    let chainPem = "${leafPem}\n${intermediatePem}"
    let keyPem = String.fromUtf8(File.readFrom("../../testdata/x509/policy_leaf_key_pkcs8.pem"))
    let trustPem = rootPem

    // 1. HTTP/TLS 启动就绪检查
    let readiness = contractHttpSshStartupReadiness()
    println("Readiness: httpTls=${readiness.httpTlsReady} x509=${readiness.x509Ready} overall=${readiness.overallReady}")

    // 2. 验证服务端 TLS 配置
    let validation = contractValidateHttpServerTlsConfigInput(
        chainPem, keyPem,
        alpnProtocols: ["h2", "http/1.1"]
    )
    println()
    println("Server Config Validation:")
    println("  Cert Chain: ${validation.certificateChainLength}")
    println("  Subject: ${validation.leafSubjectCommonName}")
    println("  Key: ${validation.keyAlgorithm}")
    println("  Normalized ALPN: ${validation.normalizedAlpnProtocols}")

    // 3. Try 版本（安全处理错误）
    let outcome = contractTryValidateHttpServerTlsConfigInput(
        chainPem, keyPem,
        alpnProtocols: ["h2", "http/1.1"]
    )
    println()
    println("Try Validation: ok=${outcome.ok} msg=${outcome.message}")

    // 4. 客户端 TLS 信任材料
    let trustMaterial = contractPrepareHttpClientTlsTrustMaterial(
        trustPem,
        hostname: "jingui.example.com"
    )
    println()
    println("Client Trust Material:")
    println("  Anchors: ${trustMaterial.validation.trustAnchorCount}")
    println("  Hostname: ${trustMaterial.validation.normalizedHostname}")

    // 5. HTTP/TLS 启动捆绑包（服务端）
    let tlsRequest = ContractHttpServerTlsConfigRequest(
        chainPem, keyPem,
        alpnProtocols: ["h2", "http/1.1"]
    )
    let startupRequest = ContractHttpServerLibraryStartupRequest(tlsRequest)
    let httpBundle = contractPrepareHttpServerLibraryStartupRequest(startupRequest)
    println()
    println("Server Startup Bundle: profile=${httpBundle.template.profile.toString()}")
    println("  Readiness: ${httpBundle.readiness.httpTlsReady}")

    println()
    println("HTTP/TLS startup material sample completed.")
}
