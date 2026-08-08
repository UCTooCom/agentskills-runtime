/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2022-2026. All rights reserved.
 */

package charset4cj.charset

/**
* process text reader
*/
public class TextReader{
    var input:InputStream
    var charset:Charset
    var bufSize: Int64
    var buf:Array<UInt8>
    var bufLimit:Int64
    var eof = false

    public init(input:InputStream, charset!:Charset = Charsets.UTF8, bufSize!:Int64 = 8192){
        this.input = input
        this.charset = charset
        this.bufSize = bufSize
        buf = Array<UInt8>(bufSize, repeat:0)
        bufLimit = 0
    }

    public func readAllLine():ArrayList<String>{
        let list = ArrayList<String>()
        while(let Some(line) <- readln()){
            list.add(line)
        }
        return list
    }

    public func read(): Option<Rune>{
        if (checkEOF()) {
            return None
        }
        var decoder = charset.newDecoder()
        var dest = Array<Rune>(1, repeat:r'\0')
        let src = buf.slice(0, this.bufLimit)
        var (srcIndex, destIndex) = decoder.decode(src, dest)
        if(destIndex == 1){
            rotateLeft(srcIndex)
            return dest[0]
        }
        return None
    }
    /**
    * read a of line String, when eof, return None
    */
    public func readln(): Option<String>{
        if (checkEOF()) {
            return None
        }
        // 如果有换行符
        var linefeed = UInt8(UInt32(r'\n'))
        var enter = UInt8(UInt32(r'\r'))
        var decoder = charset.newDecoder()
        let src = buf.slice(0, this.bufLimit)
        var indexOp = indexOfs(src, linefeed)
        if(indexOp == None){
            var dest = Array<Rune>(src.size, repeat:r'\0')
            var (srcIndex, destIndex) = decoder.decode(src, dest)
            rotateLeft(srcIndex)
            return Some(String(dest.slice(0, destIndex)))
        }else{
            var index = indexOp.getOrThrow()
            // skip \n
            var len = index
            // skip \r
            if(index > 0 && src[index - 1] == enter){
                len -= 1
            }
            let line = if(len > 0) {decoder.decode(src.slice(0, len))} else {""}
            // 剩余buf前移
            rotateLeft(index + 1)
            return Some(line)
        }
    }

    // 将 buf 从 index 位置移动到0，依次左移
    private func rotateLeft(index:Int64){
        for(i in index..buf.size){
            buf[i - index] = buf[i]
        }
        this.bufLimit = this.bufLimit - index
    }

    private func checkEOF(): Bool {
        if (eof && this.bufLimit == 0) {
            return true
        }
        while(this.bufLimit < buf.size - 1){
            var subArray = buf.slice(this.bufLimit, buf.size - this.bufLimit)
            let len = input.read(subArray)
            if(len == 0){ // if end of stream break loop
                eof = true
                break
            }
            this.bufLimit += len
        }
        return eof && this.bufLimit == 0
    }

}

func indexOfs(src: Array<UInt8>, byte: Byte): Option<Int64> {
    for (i in 0..src.size) {
        if (src[i] == byte) {
            return i
        }
    }
    return None 
}