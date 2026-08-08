package ssh_sample

import jinguissl_core.crypto.ssh.{SshVersionBanner, sshComputeHostKeySha256, sshExtractHostKeyAlgorithm, sshBuildEd25519HostKeyBlobFromSeed, sshEncodeEd25519HostPublicKey, SSH_HOST_KEY_ALGORITHM_ED25519, SSH_HOST_KEY_SHA256_LEN, SSH_HOST_KEY_ALGORITHM_RSA, SSH_PROTOCOL_VERSION_2_0}
import jinguissl_core.crypto.ed25519.{ed25519GeneratePrivateKeySeed, ed25519PublicKeyFromSeed}
import jinguissl_core.crypto.digest.bytesToHexLower

main() {
    println("===== JinguiSSL Core - SSH Sample =====")

    // 1. SSH Version Banner
    let banner = SshVersionBanner("2.0", "JinguiSSL_1.0")
    println("Protocol version: ${banner.protocolVersion}")
    println("Software version: ${banner.softwareVersion}")
    if (banner.protocolVersion != SSH_PROTOCOL_VERSION_2_0) {
        throw Exception("Unexpected protocol version")
    }

    // 2. Ed25519 Host Key
    println("\n--- Ed25519 Host Key ---")
    let seed = ed25519GeneratePrivateKeySeed()
    let hostKeyBlob = sshBuildEd25519HostKeyBlobFromSeed(seed)
    println("Host key blob size: ${hostKeyBlob.size}")

    let hostKeyAlgorithm = sshExtractHostKeyAlgorithm(hostKeyBlob)
    println("Host key algorithm: ${hostKeyAlgorithm}")
    if (hostKeyAlgorithm != SSH_HOST_KEY_ALGORITHM_ED25519) {
        throw Exception("Unexpected host key algorithm")
    }

    // 3. Host Key Fingerprint (SHA-256)
    let fingerprint = sshComputeHostKeySha256(hostKeyBlob)
    println("Host key SHA-256: ${bytesToHexLower(fingerprint)}")
    if (fingerprint.size != SSH_HOST_KEY_SHA256_LEN) {
        throw Exception("Fingerprint length wrong: ${fingerprint.size}")
    }

    // 4. Encode Ed25519 Public Key in SSH format
    let publicKey = ed25519PublicKeyFromSeed(seed)
    let encodedPub = sshEncodeEd25519HostPublicKey(publicKey)
    println("Encoded public key size: ${encodedPub.size}")

    // 5. Extract algorithm from encoded public key
    let algFromEncoded = sshExtractHostKeyAlgorithm(encodedPub)
    println("Algorithm from encoded key: ${algFromEncoded}")

    // 6. Verify the host key blob and encoded public key produce the same fingerprint
    let fp2 = sshComputeHostKeySha256(encodedPub)
    println("Encoded key fingerprint matches blob: ${fingerprint == fp2}")

    // 7. SSH constants
    println("\n--- SSH Constants ---")
    println("RSA host key algorithm: ${SSH_HOST_KEY_ALGORITHM_RSA}")
    println("Ed25519 host key algorithm: ${SSH_HOST_KEY_ALGORITHM_ED25519}")

    println("=== SSH sample passed ===")
}
