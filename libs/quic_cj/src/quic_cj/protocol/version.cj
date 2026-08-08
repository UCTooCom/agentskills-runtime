package quic_cj.protocol

public type Version = UInt32

public let VERSION_UNKNOWN: Version = 0xFFFFFFFFu32
public let VERSION_DRAFT_29: Version = 0xFF00001Du32
public let VERSION_1: Version = 0x00000001u32
public let VERSION_2: Version = 0x6B3343CFu32

public func isValidVersion(v: Version): Bool {
    v == VERSION_1 || v == VERSION_2
}

public func chooseSupportedVersion(ours: Array<Version>, theirs: Array<Version>): Option<Version> {
    for (ourVer in ours) {
        for (theirVer in theirs) {
            if (ourVer == theirVer) {
                return Some(ourVer)
            }
        }
    }
    return None
}
