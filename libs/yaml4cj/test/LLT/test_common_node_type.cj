// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*
import std.collection.*

main() {
    // 2023年2月27日 不再提供外部能力

    // let res1 = NodeTypeT.NodeTypeT_NO_NODE
    // let res2 = NodeTypeT.NodeTypeT_SCALAR_NODE
    // let res3 = NodeTypeT.NodeTypeT_SEQUENCE_NODE
    // let res4 = NodeTypeT.NodeTypeT_MAPPING_NODE

    // let arr = NodeTypeT.getValues()
    // var resArr: ArrayList<Int64> = ArrayList<Int64>()
    // for (i in arr) {
    //     resArr.append(i.getCode())
    // }

    // let ye1 = YamlError(Exception("error"))
    // let ye2 = YamlError("this is error")

    // if(
    //     res1.getCode() != 0 ||
    //     res2.getCode() != 1 ||
    //     res3.getCode() != 2 ||
    //     res4.getCode() != 3 ||
    //     // res1.hashCode() != 7735157941695098723 ||
    //     (res1 != res2) != true ||
    //     (res1 == res2) != false ||
    //     resArr.toString() != "[0, 1, 2, 3]" ||
    //     ye1.getMessage() != "error" ||
    //     ye2.toString() != "Exception: this is error"
    // ) {
    //     return -1
    // }

    return 0
}
