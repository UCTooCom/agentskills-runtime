package sample_version_negotiation

 /**
 * version_negotiation.cj — QUIC 版本协商演示
 *
 * 展示 QUIC 的版本协商机制（RFC 9000 §6）。
 * 演示如何组合和解析版本协商包，以及客户端/服务端的版本选择。
 */
 
 import quic_cj.*
 import quic_cj.protocol.{VERSION_1, VERSION_2, VERSION_DRAFT_29, VERSION_UNKNOWN, isValidVersion, chooseSupportedVersion}
 import quic_cj.wire.{composeVersionNegotiation, parseVersionNegotiationPacket, isVersionNegotiationPacket}
 
 main(): Int64 {
     println("=== QUIC Version Negotiation Demo ===\n")
 
     // ── 1. 版本有效性检查 ──
     println("── 1. Version Validation ──")
     println("  VERSION_1 (" + VERSION_1.toString() + "): valid=" +
             isValidVersion(VERSION_1).toString())
     println("  VERSION_2 (" + VERSION_2.toString() + "): valid=" +
             isValidVersion(VERSION_2).toString())
     println("  VERSION_DRAFT_29: valid=" +
             isValidVersion(VERSION_DRAFT_29).toString())
     println("  VERSION_UNKNOWN: valid=" +
             isValidVersion(VERSION_UNKNOWN).toString())
 
     // ── 2. 版本选择 ──
     println("\n── 2. Version Selection ──")
     let ourVersions: Array<UInt32> = [VERSION_1, VERSION_2]
 
      if (let Some(v1) <- chooseSupportedVersion(ourVersions, [VERSION_1])) {
          println("  Peer supports v1: selected=0x" + v1.toString())
      } else {
          println("  Peer supports v1: no common version")
      }

      if (let Some(v2) <- chooseSupportedVersion(ourVersions, [VERSION_2])) {
          println("  Peer supports v2: selected=0x" + v2.toString())
      } else {
          println("  Peer supports v2: no common version")
      }

      if (let Some(v12) <- chooseSupportedVersion(ourVersions, [VERSION_1, VERSION_2])) {
          println("  Peer supports v1+v2: selected=0x" + v12.toString())
      } else {
          println("  Peer supports v1+v2: no common version")
      }

      if (let Some(vNone) <- chooseSupportedVersion(ourVersions, [VERSION_DRAFT_29])) {
          println("  Peer supports draft-29: selected=0x" + vNone.toString())
      } else {
          println("  Peer supports draft-29: no common version")
      }
 
     // ── 3. 版本协商包 ──
     println("\n── 3. Version Negotiation Packet ──")
     let destId: Array<Byte> = [0x01u8, 0x02u8, 0x03u8, 0x04u8]
     let srcId: Array<Byte> = [0x05u8, 0x06u8, 0x07u8, 0x08u8]
     let serverVersions: Array<UInt32> = [VERSION_1, VERSION_2]
 
     let vnPacket = composeVersionNegotiation(destId, srcId, serverVersions)
     println("  VN packet size: " + vnPacket.size.toString() + " bytes")
     println("  Is VN packet: " + isVersionNegotiationPacket(vnPacket).toString())
 
      if (let Some((parsedDest, parsedSrc, parsedVersions)) <- parseVersionNegotiationPacket(vnPacket)) {
          println("  Parsed successfully:")
          println("    Dest ConnID: " + parsedDest.size.toString() + " bytes")
          println("    Src ConnID: " + parsedSrc.size.toString() + " bytes")
          println("    Versions: " + parsedVersions.size.toString())
          var i: Int64 = 0
          while (i < parsedVersions.size) {
              println("    [" + i.toString() + "]: 0x" + parsedVersions[i].toString())
              i += 1
          }
      }
 
     // ── 4. 配置的版本选择 ──
     println("\n── 4. Config Version Selection ──")
     let v1Only = Config()
     v1Only.versions = [VERSION_1]
     println("  QUIC v1 only config: valid=" + v1Only.validate().toString())
 
     let v2Only = Config()
     v2Only.versions = [VERSION_2]
     println("  QUIC v2 only config: valid=" + v2Only.validate().toString())
 
     let dualStack = Config()
     dualStack.versions = [VERSION_1, VERSION_2]
     println("  Dual-stack config: valid=" + dualStack.validate().toString())
 
     println("\n=== Version Negotiation Demo Complete ===")
     0
 }
