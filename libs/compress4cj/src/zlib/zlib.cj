/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2025. All rights reserved.
 */

/**
 * @file
 *
 * Zlib class, which provides the compress and uncompress interfaces for decompressing and compressing the entire data.
 */
package compress4cj.zlib
import compress4cj.common.Zlib4cjException

import std.collection.*
import std.io.*

public enum ZlibType {
    | ZLIB              // cjlint-ignore !G.ENU.01 description
    | GZIP              // cjlint-ignore !G.ENU.01 description
    | DEFLATE           // cjlint-ignore !G.ENU.01 description
    | AUTO_DETECT       // cjlint-ignore !G.ENU.01 description
}

/**
 * This class Provides the overall decompression interface.
 *
 * @since 0.28.4
 */
public class Zlib {

    @Frozen
    public static func compress(data: Array<Byte>, 
                                wrap!: ZlibType = ZlibType.DEFLATE, 
                                bufferSize!: Int64 = 1024,
                                level!: Int64 = 6,
                                memLevel!: UInt32 = DEF_MEM_LEVEL,
                                strategy!: UInt32 = Z_DEFAULT_STRATEGY,
                                dict!: ?Array<Byte> = None
                                ): Array<Byte> {
        if (data.size == 0) {
            return NULL_ARR_UINT8
        }
        let lev = if (level < 0 || level > 9) {
            6
        } else {
            level
        }
        let mem = if (memLevel < 1 || memLevel > 9) {
            DEF_MEM_LEVEL
        } else {
            memLevel
        }
        let str = if (strategy < 0 || strategy > 4) {
            Z_DEFAULT_STRATEGY
        } else {
            strategy
        }
        let bufsize = if (bufferSize <= 0) {
            1024
        } else {
            bufferSize
        }
        let def: Deflate = Deflate()
        match (wrap) {
            case ZLIB => def.deflateInit2(lev, 15, mem, str)
            case GZIP => def.deflateInit2(lev, 15 + 16, mem, str)
            case DEFLATE => def.deflateInit2(lev, -15, mem, str)
            case AUTO_DETECT => def.deflateInit2(lev, -15, mem, str)
        }
        if (let Some(v) <- dict) {
            if (v.size == 0) {
                throw Zlib4cjException("deflate error: dictionary is empty, but inflate need dictionary")
            }
            if (def.setDictionary(v) != Z_OK) {
                throw Zlib4cjException("deflate error: ${def.message}")
            }
        }
        let size = def.deflateBound(data.size)
        let out = ByteBuffer(size)
        var error = Z_OK
        let buffer = Array<Byte>(bufsize, repeat: 0)
        def.setInBuf(data)
        while(def.avail_in > 0) {
            def.setOutBuf(buffer)
            error = def.deflate(Z_NO_FLUSH)
            let len = def.pos_out
            if (len > 0) {
                out.write(buffer[0..len])
                def.resetOutBuf()
            }
            if (error == Z_OK) {}
            else if (error == Z_STREAM_END) {
                break
            }
            else if (error == Z_BUF_ERROR) {
                if (def.avail_out <= 0 ) {
                    break
                }
            }
            else {
                throw IOException(def.message)  // cjlint-ignore !G.ERR.02 description
            }
        }
        def.resetOutBuf()
        def.setOutBuf(buffer)
        while (true) {
            error = def.deflate(Z_FINISH)
            let len = def.pos_out
            if (len > 0) {
                out.write(buffer[0..len])
                def.resetOutBuf()
            }
            if (error == Z_OK) {}
            else if (error == Z_STREAM_END) {
                break
            }
            else if (error == Z_BUF_ERROR) {
            }
            else {
                throw IOException(def.message)  // cjlint-ignore !G.ERR.02 description
            }
        }
        def.deflateEnd()
        return readToEnd(out)
    }

    @Frozen
    public static func uncompress(data: Array<Byte>,
                                    wrap!: ZlibType = ZlibType.AUTO_DETECT,
                                    bufferSize!: Int64 = 1024,
                                    dict!: ?Array<Byte> = None,
                                    maxOutputSize!: Int64 = 0): Array<Byte> {
        if (data.size == 0) {
            return NULL_ARR_UINT8
        }
        let bufsize = if (bufferSize <= 0) {
            1024
        } else {
            bufferSize
        }
        let inf = match (wrap) {
            case ZLIB => Inflate(1)
            case GZIP => Inflate(2)
            case DEFLATE => Inflate(-1)
            case AUTO_DETECT =>
                if (data[0] == 0x1F && data[1] == 0x8B && data[2] == 0x08) {
                    Inflate(2)
                } else if (
                    (data[0] & 15) != 8 ||
                    (data[0] >> 4) > 7 ||
                    Int64(Int64(data[0]) << 8 | Int64(data[1])) % 31 != 0
                ) {
                    Inflate(-1)
                } else {
                    Inflate(1)
                }
        }
        let out = ByteBuffer()
        let buffer = Array<Byte>(bufsize, repeat: 0)
        var error = Z_OK
        var totalWritten: Int64 = 0
        inf.setInBuf(data)
        while (inf.avail_in > 0 && error != Z_STREAM_END) {
            inf.setOutBuf(buffer)
            while(inf.avail_out > 0 && inf.avail_in > 0) {
                error = inf.inflate(Z_NO_FLUSH)
                if (error >= 0) {
                    if (error == Z_STREAM_END) {
                        break
                    }
                    if (error == Z_NEED_DICT) {
                        if (let Some(v) <- dict) {
                            if (v.size == 0) {
                                throw Zlib4cjException("inflate error: dictionary is empty, but inflate need dictionary")
                            }
                            if (inf.setDictionary(v) != Z_OK) {
                                throw Zlib4cjException("inflate error: ${error}, ${inf.message}")
                            }
                        } else {
                            throw Zlib4cjException("inflate error: ${error}, ${erroMsg(error)}, but no dictionary set")
                        }
                    }
                } else if (error == Z_DATA_ERROR) {
                    let syncRet = inf.inflateSync()
                    if (syncRet == Z_OK) { // 成功找到同步点，恢复解压
                        continue
                    } else if (syncRet == Z_BUF_ERROR) { // 需要更多数据才能恢复
                        break
                    } else if (syncRet == Z_STREAM_END) { //恢复失败
                        throw Zlib4cjException("inflate error: ${error}, ${inf.message}")
                    }
                } else {
                    throw Zlib4cjException("inflate error: ${error}, ${inf.message}")
                }
            }
            let chunkSize = buffer.size - inf.avail_out
            totalWritten += chunkSize
            // 解压炸弹防护：超过最大输出大小时提前终止
            if (maxOutputSize > 0 && totalWritten > maxOutputSize) {
                inf.inflateEnd()
                inf.end()
                throw Zlib4cjException("解压后数据超过最大允许大小: ${maxOutputSize} 字节")
            }
            out.write(buffer[0..chunkSize])
        }
        inf.inflateEnd()
        inf.end()
        return readToEnd(out)
    }   
}

