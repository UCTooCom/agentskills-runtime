package magic.app.services.aip.model

import std.deriving.*

@Derive[Equatable]
public enum MqConnectionState {
    | Disconnected
    | Connecting
    | Connected
    | Reconnecting
    | Unavailable
}