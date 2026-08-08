package quic_cj.protocol

public enum Perspective {
    | Server
    | Client
}

public func oppositePerspective(p: Perspective): Perspective {
    match (p) {
        case Perspective.Server => Perspective.Client
        case Perspective.Client => Perspective.Server
    }
}
