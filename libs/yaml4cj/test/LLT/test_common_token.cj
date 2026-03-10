// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*
import std.collection.*

main() {
    // 2023年2月27日 不再提供外部能力

    // let t = TokenT()
    // var startMark: String =  """
    //     { index=0, line=0, column=0 }
    //     """
    // var endMark: String =  """
    //     { index=0, line=0, column=0 }
    //     """
    // var res: String = """
    //     {
    //         typ=TokenTypeT_NO_TOKEN
    //         startMark=${startMark}
    //         endMark=${endMark}
    //         encoding=EncodingT_ANY_ENCODING
    //         value=[]
    //         suffix=[]
    //         prefix=[]
    //         style=ScalarStyleT_ANY_SCALAR_STYLE
    //         major=0
    //         minor=0
    //     }
    //     """

    // if(t.toString() != res) {
    //     return -1
    // }

    return 0
}
