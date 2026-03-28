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

public class AsyncServer<EN, DE> <: Resource where EN <: ProtocolData<EN>, DE <: ProtocolData<DE> {
    private static func log() {
        LoggerFactory.getLogger<AsyncServer<EN, DE>>()
    }
    private let closed = AtomicBool(false)
    public AsyncServer(
        private let overload!: EN,
        private let execError!: EN,
        private let encodeError!: EN = execError,
        private let codecQueues!: Array<ArrayBlockingQueue<() -> Unit>> = initQueues(8, 1024),
        private let taskQueues!: Array<ArrayBlockingQueue<() -> Unit>> = codecQueues,
        private let writeQueues!: Array<ArrayBlockingQueue<() -> Unit>> = codecQueues,
        private let rateLimiter!: RateLimiter<EN> = UnlimitedRateLimiter<EN>(),
        private let server!: TcpServerSocket,
        private let encoder!: Encoder<EN>,
        private let decoder!: Decoder<DE>,
        private let executor!: (DE) -> EN
    ) {
        startConsume()
        server.bind()
        start()
        env.atExit(close)
    }
    public init(
        overload!: EN,
        execError!: EN,
        encodeError!: EN = execError,
        codecQueues!: Array<ArrayBlockingQueue<() -> Unit>> = initQueues(8, 1024),
        taskQueues!: Array<ArrayBlockingQueue<() -> Unit>> = codecQueues,
        writeQueues!: Array<ArrayBlockingQueue<() -> Unit>> = codecQueues,
        rateLimiter!: RateLimiter<EN> = UnlimitedRateLimiter<EN>(),
        server!: TcpServerSocket,
        codec!: Codec<EN, DE>,
        executor!: (DE) -> EN
    ) {
        this(overload: overload, execError: execError, encodeError: encodeError, codecQueues: codecQueues,
            taskQueues: taskQueues, writeQueues: writeQueues, rateLimiter: rateLimiter, server: server, encoder: codec,
            decoder: codec, executor: executor)
    }
    public static func initQueues(parallelism: Int64, bufferSize: Int64) {
        let p = if (((parallelism - 1) & parallelism) == 0) {
            parallelism
        } else {
            var p = 1
            while (p < parallelism) {
                p <<= 1
            }
            p
        }
        Array<ArrayBlockingQueue<() -> Unit>>(p) {
            _ => ArrayBlockingQueue<() -> Unit>(bufferSize)
        }
    }

    private func startConsume(): Unit {
        func startTasks(queues: Array<ArrayBlockingQueue<() -> Unit>>) {
            for (q in queues) {
                spawn {
                    while (let task <- q.remove()) {
                        task()
                    }
                }
            }
        }
        startTasks(codecQueues)
        startTasks(taskQueues)
        startTasks(writeQueues)
    }
    private func start(): Unit {
        while (!closed.load() && let socket <- server.accept()) {
            execSocket(socket)
        }
    }
    private func execSocket(socket: TcpSocket) {
        let decoder = this.decoder.decoder()
        spawnSocket(socket, decoder)
    }
    private func spawnSocket(socket: TcpSocket, decoder: Decoder<DE>) {
        spawn {
            loopSocket(socket, decoder)
        }
    }
    private func loopSocket(socket: TcpSocket, decoder: Decoder<DE>) {
        while (!(closed.load() || socket.isClosed())) {
            let buf = Array<Byte>(128, repeat: 0)
            let len = try {
                socket.read(buf)
            } catch (e: Exception) {
                log().warn<SocketAddress>('socket {} read', e, [socket.remoteAddress])
                continue
            }
            enqueueDecoding(socket, buf[0..len], decoder)
        }
    }
    private func enqueueDecoding(socket: TcpSocket, buf: Array<Byte>, decoder: Decoder<DE>) {
        codecQueues[calidx(socket, codecQueues.size)].add(
            {
                => if (let Some(d) <- decoder.decode(buf)) {
                    if (d.isToClose) {
                        try {
                            socket.close()
                        } catch (e: Exception) {
                            log().warn<SocketAddress>('socket {} close', e, [socket.remoteAddress])
                        }
                    } else {
                        enqueueTask(socket, d)
                    }
                }
            })
    }
    private func enqueueTask(socket: TcpSocket, d: DE) {
        taskQueues[calidx(socket, taskQueues.size)].add(
            {
                =>
                let r = rateLimiter
                    .exec(overload) {
                        try {
                            executor(d)
                        } catch (e: Exception) {
                            log().warn<SocketAddress>('task execute', e, [socket.remoteAddress])
                            execError
                        }
                    }
                    .getOrThrow()
                enqueueEncoding(socket, r)
            }
        )
    }
    private func enqueueEncoding(socket: TcpSocket, r: EN) {
        codecQueues[calidx(socket, codecQueues.size)].add(
            {
                =>
                let bytes = try {
                    encoder.encoder().encode(r)
                } catch (e: Exception) {
                    log().warn<SocketAddress>('async socket encode {}', e, [socket.remoteAddress])
                    encoder.encoder().encode(encodeError)
                }
                enqueueWriting(socket, bytes)
            }
        )
    }
    private func enqueueWriting(socket: TcpSocket, bytes: Array<Byte>) {
        writeQueues[calidx(socket, writeQueues.size)].add(
            {
                => try {
                    socket.write(bytes)
                } catch (e: Exception) {
                    log().warn<SocketAddress>('async socket write {}', e, [socket.remoteAddress])
                }
            })
    }
    private func calidx(socket: TcpSocket, size: Int64) {
        socket.hashCode() & (size - 1)
    }
    public func isClosed(): Bool {
        server.isClosed()
    }
    public func close(): Unit {
        closed.store(true)
        server.close()
    }
}
