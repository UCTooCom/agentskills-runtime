package ystyle::jsonrpc

import std.core.Resource

public interface Transport <: Resource {
    func send(data: Array<Byte>): Unit
    func receive(): ?Array<Byte>
    func isClosed(): Bool
}
