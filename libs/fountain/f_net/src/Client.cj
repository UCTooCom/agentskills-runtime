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

public open class SocketClient<T, R> <: Resource where T <: ProtocolData<T>, R <: ProtocolData<R> {
    public SocketClient(
        private let socket!: TcpSocket,
        private let encoder!: Encoder<T>,
        private let decoder!: Decoder<R>
    ) {
        socket.connect()
    }
    public init(socket!: TcpSocket, codec!: Codec<T, R>) {
        this(socket: socket, encoder: codec, decoder: codec)
    }
    public func isClosed(): Bool {
        socket.isClosed()
    }
    public func close(): Unit {
        socket.close()
    }
    public open func transfer(data: T): ?R {
        socket.write(encoder.encode(data))
        while (true) {
            let buf = Array<Byte>(128, repeat: 0)
            let len = socket.read(buf)
            if (let Some(x) <- decoder.decode(buf[0..len])) {
                return x
            }
        }
        None<R>
    }
}

public class AsyncSocketClient<T, K, R> <: SocketClient<T, R> where K <: Hashable & Equatable<K>, T <: KeyedData<K, T>,
    R <: KeyedData<K, R> {
    public init(socket!: TcpSocket, encoder!: Encoder<T>, decoder!: Decoder<R>) {
        super(socket: socket, encoder: encoder, decoder: decoder)
    }
    public init(socket!: TcpSocket, codec!: Codec<T, R>) {
        super(socket: socket, codec: codec)
    }
    private let dataMap = ConcurrentHashMap<K, SocketClientFuture<K, R>>()
    public func transfer(_: T): ?R {
        throw UnsupportedException('')
    }
    public func asyncTransfer(data: T): SocketClientFuture<K, R> {
        let future = SocketClientFuture<K, R>(dataMap)
        dataMap[data.key] = future
        spawn {
            if (let Some(d) <- super.transfer(data)) {
                dataMap.remove(d.key)?.set(d)
            } else {
                throw UnreachableException()
            }
        }
        future
    }
}

public class SocketClientFuture<K, T> where K <: Hashable & Equatable<K>, T <: KeyedData<K, T> {
    private let q = ArrayBlockingQueue<?T>(1)
    SocketClientFuture(private let map: ConcurrentHashMap<K, SocketClientFuture<K, T>>) {}
    func set(data: ?T) {
        q.add(data)
    }
    public func get(timeout!: Duration = Duration.Max): ?T {
        if (let Some(x) <- q.remove(timeout) && let Some(v) <- x) {
            map.remove(v.key)
            x
        } else {
            None<T>
        }
    }
}
