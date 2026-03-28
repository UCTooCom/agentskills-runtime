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
package f_util

import std.math.numeric.Decimal
import f_base.*
import f_random.ThreadLocalRandom

/**
 * 1.      Alice和Bob先对p 和g达成一致，而且公开出来。Eve也就知道它们的值了。
 *
 * 2.      Alice取一个私密的整数a，不让任何人知道，发给Bob 计算结果：A=(g pow a) mod p. Eve 也看到了A的值。
 *
 * 3.      类似,Bob 取一私密的整数b,发给Alice计算结果B=(g pow b) mod p.同样Eve也会看见传递的B是什么。
 *
 * 4.      Alice 计算出S=(B pow a) mod p=((g pow b) pow a) mod p=(g pow (a*b)) mod p.
 *
 * 5.      Bob 也能计算出S=(A pow b) mod p=((g pow a) pow b) mod p=(g pow (a*b)) mod p.
 *
 * 6.      Alice 和 Bob 现在就拥有了一个共用的密钥S.
 *
 * 7.      虽然Eve看见了p,g, A and B, 但是鉴于计算离散对数的困难性，她无法知道a和b 的具体值。所以Eve就无从知晓密钥S 是什么了。
 * 永远是alice发起密钥交换请求
 * let alice = DiffieHellmanKeyExchangerClient();
 * let semi=alice.semi(16);
 * //alice将semi发送给bob
 *
 * //bob接收到请求
 * let bob = DiffieHellmanKeyExchangerServer();
 * let bobKey = bob.key(A,p);//bob保存key，不对外公开
 * let B=bob.finish(g,p);//bob将B作为响应返回给alice
 *
 * //alice接收到响应
 * let aliceKey=alice.key(B,p);//alice保存key，不对外公开
 */
public struct Semi {
    public Semi(public let g: Array<Byte>, public let p: Array<Byte>, public let A: BigInt) {}
}

public class DiffieHellmanKeyExchangerClient <: DiffieHellmanKeyExchanger {
    public func semi(gBytes!: Int32 = 16, pBytes!: Int32 = 16) {
        ab()
        let g = randomBytes(bytes: gBytes)
        let p = randomBytes(bytes: pBytes)
        let A = middle(g, p)
        Semi(g, p, A)
    }
}

public class DiffieHellmanKeyExchangerServer <: DiffieHellmanKeyExchanger {
    public func key(m: Array<Byte>, p: Array<Byte>): String {
        var result = "0"
        while (result == '0') {
            ab_ = 0
            result = super.key(m, p)
        }
        return result
    }
    /**
     * Bob 必须首先执行Bob.key
     * @param g
     * @param p
     * @return B
     */
    public func finish(g: Array<Byte>, p: Array<Byte>): BigInt {
        return middle(g, p)
    }
}

abstract sealed class DiffieHellmanKeyExchanger {
    protected var ab_: Int64 = random() //ab

    protected func ab() {
        if (ab_ == 0) {
            ab_ = random()
        }
    }
    public open func key(m: Array<Byte>, p: Array<Byte>): String {
        ab()
        let mm = middle(m, p)
        return mm.toString(radix: 36)
    }

    protected func middle(g: Array<Byte>, p: Array<Byte>): BigInt {
        (Decimal(BigInt(true, g)) ** ab_).toBigInt() % BigInt(true, p)
    }
    protected static func random() {
        ThreadLocalRandom.current.nextInt64()
    }
    protected static func randomBytes(bytes!: Int32 = 16) {
        ThreadLocalRandom.current.nextBytes(bytes)
    }
    public static func randomByteLen(): Int32 {
        let rand = ThreadLocalRandom.current
        var r = 0i32
        do {
            r = rand.nextInt32()
        } while (r <= 0)
        r
    }
}
