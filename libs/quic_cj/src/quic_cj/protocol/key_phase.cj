package quic_cj.protocol

public type KeyPhase = Int64

public enum KeyPhaseBit {
    | Undefined
    | Zero
    | One

}

public func keyPhaseBit(p: KeyPhase): KeyPhaseBit {
    if (p % 2 == 0) { KeyPhaseBit.Zero }
    else { KeyPhaseBit.One }
}
