/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_net

import std.env

public class PipelineServer<EN, DE> <: Resource where EN <: ProtocolData<EN>, DE <: ProtocolData<DE> {
    private static func log() {
        LoggerFactory.getLogger<PipelineServer<EN, DE>>()
    }
    private let closed = AtomicBool(false)
    public PipelineServer(
        private let server!: TcpServerSocket,
        private let encoder!: Encoder<EN>,
        private let decoder!: Decoder<DE>,
        private let executor!: (DE) -> EN
    ) {
        server.bind()
        start()
        env.atExit(close)
    }
    public init(
        server!: TcpServerSocket,
        codec!: Codec<EN, DE>,
        executor!: (DE) -> EN
    ) {
        this(server: server, encoder: codec, decoder: codec, executor: executor)
    }

    private func start(): Unit {
        while (!closed.load() && let socket <- server.accept()) {
            let decoder = this.decoder.decoder()
            spawn {
                while (!(closed.load() || socket.isClosed())) {
                    let buf = Array<Byte>(128, repeat: 0)
                    let len = try {
                        socket.read(buf)
                    } catch (e: Exception) {
                        log().warn<SocketAddress>('socket {} read', e, [socket.remoteAddress])
                        continue
                    }
                    if (let Some(d) <- decoder.decode(buf[0..len])) {
                        if (d.isToClose) {
                            try {
                                socket.close()
                            } catch (e: Exception) {
                                log().warn<SocketAddress>('socket {} close', e, [socket.remoteAddress])
                            }
                        } else {
                            let r = try {
                                executor(d)
                            } catch (e: Exception) {
                                log().warn<SocketAddress>('pipeline executor {}', e, [socket.remoteAddress])
                                continue
                            }
                            let bytes = try {
                                encoder.encoder().encode(r)
                            } catch (e: Exception) {
                                log().warn<SocketAddress>('pipeline encode {}', e, [socket.remoteAddress])
                                continue
                            }
                            try {
                                socket.write(bytes)
                            } catch (e: Exception) {
                                log().warn<SocketAddress>('socket {} write', e, [socket.remoteAddress])
                            }
                        }
                    }
                }
            }
        }
    }
    public func isClosed(): Bool {
        server.isClosed()
    }
    public func close(): Unit {
        closed.store(true)
        server.close()
    }
}
