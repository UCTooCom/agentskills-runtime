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
package f_process

import std.io.{InputStream, OutputStream}
import std.env.*
public import std.fs.{Path, canonicalize}
import charset4cj.charset.encoding.Charset
import charset4cj.charset.{Charsets, TextReader, TextWriter}
// import charset4cj.{Charset, Charsets, TextReader, TextWriter}

public func stdReader(charset!: Charset = Charsets.UTF8): TextReader {
    TextReader(getStdIn(), charset: charset)
}

public func stdOutWriter(charset!: Charset = Charsets.UTF8): TextWriter {
    TextWriter(getStdOut(), charset: charset)
}

public func stdErrWriter(charset!: Charset = Charsets.UTF8): TextWriter {
    TextWriter(getStdErr(), charset: charset)
}

public func getAbsoluteCommand(): Path {
    canonicalize(getCommand())
}

public func getAbsoluteCommandDir(): Path {
    getAbsoluteCommand().parent
}
