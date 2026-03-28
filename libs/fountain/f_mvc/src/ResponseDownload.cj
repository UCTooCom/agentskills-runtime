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
package f_mvc

public func download(ctx: HttpContext, data: File): Unit {
    let fd = FileDownload(ctx, multi: false)
    fd.write(data)
}

public func download(ctx: HttpContext, data: InputStream, filename: String, length!: Int64 = -1): Unit {
    let fd = FileDownload(ctx, multi: false)
    fd.write(filename, data, length: length)
}

public func download(ctx: HttpContext, data: Array<Byte>, filename: String): Unit {
    let stream = ByteBuffer()
    stream.write(data)
    download(ctx, stream, filename, length: data.size)
}

public func download<C>(ctx: HttpContext, data: C): Unit where C <: Iterable<(InputStream, String)> {
    let fd = FileDownload(ctx, multi: true)
    for (d in data) {
        fd.write(d[1], d[0])
    }
}

public func download(ctx: HttpContext, data: Array<File>): Unit {
    let fd = FileDownload(ctx, multi: true)
    for (d in data) {
        fd.write(d)
    }
}
