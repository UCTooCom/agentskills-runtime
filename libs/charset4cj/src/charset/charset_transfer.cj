/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

package charset4cj.charset

public class CharsetTransfer {

    public static func transfer(input: InputStream, output: OutputStream, inputCharset: Charset, outputCharset: Charset): Unit {
        var reader: TextReader = TextReader(input, charset: inputCharset)
        var writer: TextWriter = TextWriter(output, charset: outputCharset)
        while (let Some(buffer) <- reader.read()) {
            writer.write("${buffer}")
        }
    }
}
