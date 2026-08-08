internal import std.random.*

public class SourceData {
    public init() {}

    let s1: String = ""
    let s2 = "Hello Cangjie Lang"
    let s3 = "\"Hello Cangjie Lang\""
    let s4 = "Hello Cangjie Lang\n"
    public let s5 = "你好仓颉！【】"

    public let s6: String = """
                    """
    public let s7 = """
                Hello,
                Cangjie Lang
            """

    let s8: String = #""#
    public let s9 = ##"你好\n"##
    public let s10 = ###"
                Hello,
                Cangjie
                Lang
            "###

    let b1: Bool = true
    let b2: Bool = 1 > 3

    var t1: DateTime = DateTime.now()
    var t2 = DateTime.ofUTC(year: 2023, month: Month.August, dayOfMonth: 5)
    var customPtn = "yyyy/MM/dd HH:mm:ss OO"
    var t3 = DateTime.parse("2021-08-05T21:08:04+08:00")
    var t4 = DateTime.parse("2021/08/05 21:08:04 +10:00", customPtn)

    var jsonStr1 =
        ##"[true,"kjjjke\"eed",{"sdfd":"ggggg","eeeee":[341,false,
                    {"nnnn":55.87}]},3422,22.341,false,[22,22.22,true,"ddd"],43]"##
    var jv1: JsonValue = JsonValue.fromStr(jsonStr1)
    var res = jv1.toString()
    var jsonStr2 = ##"{"name":"Tom","age":"18","version":"0.1.1"}"##
    var jv2: JsonValue = JsonValue.fromStr(jsonStr2)

    // ######################################################################################
    public func generateStringMap(para_1: Array<Rune>): HashMap<String, String> {
        var map_1: HashMap<String, String> = HashMap<String, String>()
        for (i in 0..para_1.size) {
            map_1.add("K_${i+1}", String(para_1))
        }
        return map_1
    }

    public func generateString(len: Int64): String {
        var charArr: Array<Rune> = Array<Rune>(len, repeat: r'Q')
        return String(charArr)
    }

    public func generateSourceDataWithString(): (Array<Any>, ArrayList<Any>, HashMap<String, Any>) {
        let str_1: String = s1 + s3 + s5 //单+单
        let str_2: String = s2 + s4 + s7 + s9 //单+多
        let str_3: String = s7 + s8 + s9 + s10 //多+多
        let str_4: String = "插值==>${s5}::${s10}" //插值
        let strArr_D1: Array<Any> = [str_1, str_2, str_3, str_4]
        let strArrL_D1: ArrayList<Any> = ArrayList<Any>([str_1, str_2, str_3, str_4])
        let strMap_D1: HashMap<String, Any> = HashMap<String, Any>(
            [(s1, s3), (s5, s9), (s7, str_4), (s10, str_3), (str_1, str_2), (str_4, s8)])
        let tuple_res: (Array<Any>, ArrayList<Any>, HashMap<String, Any>) = (strArr_D1, strArrL_D1, strMap_D1)
        return tuple_res
    }

    public func generateSourceDataWithBool(): (Array<Any>, ArrayList<Any>, HashMap<String, Any>) {
        let boolArr_D1: Array<Any> = [b1, b2, b1 == b2, -23 is UInt8]
        let boolArrL_D1: ArrayList<Any> = ArrayList<Any>([b1, b2, b1 == b1, -23 is UInt8])
        let boolMap_D1: HashMap<String, Any> = HashMap<String, Any>([(s1, b1), (s5, b2), (s7, b1 == b2),
        (s10, -23 is UInt8)])
        let tuple_res: (Array<Any>, ArrayList<Any>, HashMap<String, Any>) = (boolArr_D1, boolArrL_D1, boolMap_D1)
        return tuple_res
    }

    public func generateSourceDataWithJsonValue(): (Array<Any>, ArrayList<Any>, HashMap<String, Any>) {
        let jsonValueArr_D1: Array<Any> = [jv1, jv2]
        let jsonValueArrL_D1: ArrayList<Any> = ArrayList<Any>([jv1, jv2])
        let jsonValueMap_D1: HashMap<String, Any> = HashMap<String, Any>([(s5, jv1), (s7, jv2), (s10, jv1)])
        let tuple_res: (Array<Any>, ArrayList<Any>, HashMap<String, Any>) = (jsonValueArr_D1, jsonValueArrL_D1,
            jsonValueMap_D1)
        return tuple_res
    }

    public func generateSourceDataWithTime(): (Array<Any>, ArrayList<Any>, HashMap<String, Any>) {
        let timeArr_D1: Array<Any> = [t1, t2, t3, t4]
        let timeArrL_D1: ArrayList<Any> = ArrayList<Any>([t1, t2, t3, t4])
        let timeMap_D1: HashMap<String, Any> = HashMap<String, Any>([(s5, t1), (s7, t2), (s10, t3), (s8, t4)])
        let tuple_res: (Array<Any>, ArrayList<Any>, HashMap<String, Any>) = (timeArr_D1, timeArrL_D1, timeMap_D1)
        return tuple_res
    }

    public func generateSourceDataWithCla_1(): (Array<Any>, ArrayList<Any>, HashMap<String, Any>) {
        let claArr_D1: Array<Any> = [Cla_1(-10), Cla_1(99), Cla_1(2562323)]
        let claArrL_D1: ArrayList<Any> = ArrayList<Any>([Cla_1(-10), Cla_1(99), Cla_1(2562323)])
        let claMap_D1: HashMap<String, Any> = HashMap<String, Any>(
            [(s5, Cla_1(-10)), (s7, Cla_1(99)), (s10, Cla_1(2562323))])
        let tuple_res: (Array<Any>, ArrayList<Any>, HashMap<String, Any>) = (claArr_D1, claArrL_D1, claMap_D1)
        return tuple_res
    }

    public func getMapEntry(enter: HashMap<String, Any>): (ArrayList<String>, ArrayList<Any>) {
        let aa: ArrayList<String> = ArrayList<String>()
        let bb: ArrayList<Any> = ArrayList<Any>()
        for ((k, v) in enter) {
            aa.add(k)
            bb.add(v)
        }
        let res: (ArrayList<String>, ArrayList<Any>) = (aa, bb)
        return res
    }

    public func getClaimData(enu: Enu_JWT, jwtStr: String): String {
        let strArr: Array<String> = jwtStr.split(".")
        var res: String = match (enu) {
            case Enu_JWT.HEADER => strArr[0]
            case Enu_JWT.PAYLOAD => strArr[1]
            case Enu_JWT.SIGNATURE => strArr[2]
        }
        return res
    }

    public func convertArrAnyToArrString(arrAny: Array<Any>): Array<String> {
        var arr_Str2: Array<String> = Array<String>(arrAny.size, repeat: "H")
        for (i in 0..arrAny.size) {
            arr_Str2[i] = (arrAny[i] as String).getOrThrow()
        }
        return arr_Str2
    }

    public func getRandomStr(enter: UInt64): String {
        let m: Random = Random(32)
        var res: String = ""
        for (_ in 0..enter) {
            res += m.nextUInt64(enter).toString()
        }
        return res
    }

    public func getRandomStrArr(enter: Int64): Array<String> {
        let m: Random = Random(32)
        var resArr: Array<String> = Array<String>(enter, repeat: "Q")
        for (i in 0..enter) {
            resArr[i] = m.nextInt64(enter).toString()
        }
        return resArr
    }

    public func createClaimMap(header: Array<String>, payload: Array<String>): (HashMap<String, Any>, HashMap<String, Any>) {
        var map_h: HashMap<String, Any> = HashMap<String, Any>()
        for (i in 0..header.size : 2) {
            map_h.add(header[i], (header[i + 1] as Any).getOrThrow())
        }
        var map_p: HashMap<String, Any> = HashMap<String, Any>()
        for (i in 0..payload.size : 2) {
            map_p.add(payload[i], (payload[i + 1] as Any).getOrThrow())
        }
        return (map_h, map_p)
    }

    public func createClaim(jwtBuilder: Builder, header: Array<String>, payload: Array<String>): Unit {
        for (i in 0..header.size : 2) {
            jwtBuilder.withClaim(header[i], header[i + 1])
        }
        for (i in 0..payload.size : 2) {
            jwtBuilder.withClaim(payload[i], payload[i + 1])
        }
    }
}

public enum Enu_JWT {
    | HEADER
    | PAYLOAD
    | SIGNATURE
}

public class Cla_1 <: Hashable & Equatable<Cla_1> {
    public var x: Int64
    public Cla_1(para_1: Int64) {
        this.x = para_1
    }
    public func hashCode(): Int64 {
        return Int64(x)
    }
    public operator func ==(right: Cla_1): Bool {
        return (this == right)
    }
    public operator func !=(right: Cla_1): Bool {
        return !(this == right)
    }
}
