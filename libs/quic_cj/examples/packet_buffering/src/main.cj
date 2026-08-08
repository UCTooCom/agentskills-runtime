package sample_packet_buffering

 /**
 * packet_buffering.cj — 包缓冲与内存管理演示
 *
 * 展示 QUIC 的包缓冲回收机制，包括基于环形缓冲区的对象池、
 * 引用计数和内存复用策略。
 */
 
 import quic_cj.sys.{UdpBufferPool, getUdpBuffer, putUdpBuffer}
 
 main(): Int64 {
     println("=== Packet Buffering & Memory Pool Demo ===\n")
 
     // ── 1. UDP 缓冲区池 ──
     println("── 1. UDP Buffer Pool ──")
     let pool = UdpBufferPool()
     println("  Pool size after creation: " + pool.len().toString())
 
     // 获取缓冲区
     let buf1 = pool.get()
     println("  Got buffer: size=" + buf1.size.toString())
 
     let buf2 = pool.get()
     println("  Got buffer: size=" + buf2.size.toString())
 
     // 归还缓冲区
     pool.put(buf1)
     pool.put(buf2)
     println("  Pool size after return: " + pool.len().toString())
 
     // 重复使用 - 从池中回收
     let recycled = pool.get()
     println("  Recycled buffer: size=" + recycled.size.toString())
     pool.put(recycled)
     println("  Pool size after recycle: " + pool.len().toString())
 
     // ── 2. 全局缓冲区获取/归还 ──
     println("\n── 2. Global Buffer Access ──")
     let gbuf = getUdpBuffer()
     println("  Global buffer: size=" + gbuf.size.toString())
     putUdpBuffer(gbuf)
     println("  Buffer returned to pool")
 
     // ── 3. 多缓冲区循环 ──
     println("\n── 3. Multiple Buffer Cycle ──")
     var i: Int64 = 0
     while (i < 5) {
         let b = pool.get()
         println("  Acquired buffer #" + (i + 1).toString() + ": size=" + b.size.toString())
         pool.put(b)
         println("  Released buffer #" + (i + 1).toString())
         i += 1
     }
     println("  Final pool size: " + pool.len().toString())
 
     println("\n=== Packet Buffering Demo Complete ===")
     0
 }
