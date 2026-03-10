// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*
import std.collection.*

main() {
    // 2023年2月27日 不再提供外部能力

    // let res1 = ParserStateT.ParserStateT_PARSE_STREAM_START_STATE
    // let res2 = ParserStateT.ParserStateT_PARSE_IMPLICIT_DOCUMENT_START_STATE
    // let res3 = ParserStateT.ParserStateT_PARSE_DOCUMENT_START_STATE
    // let res4 = ParserStateT.ParserStateT_PARSE_DOCUMENT_CONTENT_STATE
    // let res5 = ParserStateT.ParserStateT_PARSE_DOCUMENT_END_STATE
    // let res6 = ParserStateT.ParserStateT_PARSE_BLOCK_NODE_STATE
    // let res7 = ParserStateT.ParserStateT_PARSE_BLOCK_NODE_OR_INDENTLESS_SEQUENCE_STATE
    // let res8 = ParserStateT.ParserStateT_PARSE_FLOW_NODE_STATE
    // let res9 = ParserStateT.ParserStateT_PARSE_BLOCK_SEQUENCE_FIRST_ENTRY_STATE
    // let res10 = ParserStateT.ParserStateT_PARSE_BLOCK_SEQUENCE_ENTRY_STATE
    // let res11 = ParserStateT.ParserStateT_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE
    // let res12 = ParserStateT.ParserStateT_PARSE_BLOCK_MAPPING_FIRST_KEY_STATE
    // let res13 = ParserStateT.ParserStateT_PARSE_BLOCK_MAPPING_KEY_STATE
    // let res14 = ParserStateT.ParserStateT_PARSE_BLOCK_MAPPING_VALUE_STATE
    // let res15 = ParserStateT.ParserStateT_PARSE_FLOW_SEQUENCE_FIRST_ENTRY_STATE
    // let res16 = ParserStateT.ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_STATE
    // let res17 = ParserStateT.ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_KEY_STATE
    // let res18 = ParserStateT.ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE
    // let res19 = ParserStateT.ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE
    // let res20 = ParserStateT.ParserStateT_PARSE_FLOW_MAPPING_FIRST_KEY_STATE
    // let res21 = ParserStateT.ParserStateT_PARSE_FLOW_MAPPING_KEY_STATE
    // let res22 = ParserStateT.ParserStateT_PARSE_FLOW_MAPPING_VALUE_STATE
    // let res23 = ParserStateT.ParserStateT_PARSE_FLOW_MAPPING_EMPTY_VALUE_STATE
    // let res24 = ParserStateT.ParserStateT_PARSE_END_STATE

    // let arr = ParserStateT.getValues()
    // var resArr: ArrayList<Int64> = ArrayList<Int64>()
    // for (i in arr) {
    //     resArr.append(i.getCode())
    // }
    // if(
    //     ((res1.toString() != "ParserStateT_PARSE_STREAM_START_STATE") && (res1.getCode() != 0)) ||
    //     ((res2.toString() != "ParserStateT_PARSE_IMPLICIT_DOCUMENT_START_STATE") && (res2.getCode() != 1)) ||
    //     ((res3.toString() != "ParserStateT_PARSE_DOCUMENT_START_STATE") && (res3.getCode() != 2)) ||
    //     ((res4.toString() != "ParserStateT_PARSE_DOCUMENT_CONTENT_STATE") && (res4.getCode() != 3)) ||
    //     ((res5.toString() != "ParserStateT_PARSE_DOCUMENT_END_STATE") && (res5.getCode() != 4)) ||
    //     ((res6.toString() != "ParserStateT_PARSE_BLOCK_NODE_STATE") && (res6.getCode() != 5)) ||
    //     ((res7.toString() != "ParserStateT_PARSE_BLOCK_NODE_OR_INDENTLESS_SEQUENCE_STATE") && (res7.getCode() != 6)) ||
    //     ((res8.toString() != "ParserStateT_PARSE_FLOW_NODE_STATE") && (res8.getCode() != 7)) ||
    //     ((res9.toString() != "ParserStateT_PARSE_BLOCK_SEQUENCE_FIRST_ENTRY_STATE") && (res9.getCode() != 7)) ||
    //     ((res10.toString() != "ParserStateT_PARSE_BLOCK_SEQUENCE_ENTRY_STATE") && (res10.getCode() != 7)) ||
    //     ((res11.toString() != "ParserStateT_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE") && (res11.getCode() != 7)) ||
    //     ((res12.toString() != "ParserStateT_PARSE_BLOCK_MAPPING_FIRST_KEY_STATE") && (res12.getCode() != 7)) ||
    //     ((res13.toString() != "ParserStateT_PARSE_BLOCK_MAPPING_KEY_STATE") && (res13.getCode() != 7)) ||
    //     ((res14.toString() != "ParserStateT_PARSE_BLOCK_MAPPING_VALUE_STATE") && (res14.getCode() != 7)) ||
    //     ((res15.toString() != "ParserStateT_PARSE_FLOW_SEQUENCE_FIRST_ENTRY_STATE") && (res15.getCode() != 7)) ||
    //     ((res16.toString() != "ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_STATE") && (res16.getCode() != 7)) ||
    //     ((res17.toString() != "ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_KEY_STATE") && (res17.getCode() != 7)) ||
    //     ((res18.toString() != "ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE") && (res18.getCode() != 7)) ||
    //     ((res19.toString() != "ParserStateT_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE") && (res19.getCode() != 7)) ||
    //     ((res20.toString() != "ParserStateT_PARSE_FLOW_MAPPING_FIRST_KEY_STATE") && (res20.getCode() != 7)) ||
    //     ((res21.toString() != "ParserStateT_PARSE_FLOW_MAPPING_KEY_STATE") && (res21.getCode() != 7)) ||
    //     ((res22.toString() != "ParserStateT_PARSE_FLOW_MAPPING_VALUE_STATE") && (res22.getCode() != 7)) ||
    //     ((res23.toString() != "ParserStateT_PARSE_FLOW_MAPPING_EMPTY_VALUE_STATE") && (res23.getCode() != 7)) ||
    //     ((res24.toString() != "ParserStateT_PARSE_END_STATE") && (res24.getCode() != 7)) ||
    //     // res8.hashCode() != 7735156097660419551 ||
    //     (res1 != res2) != true ||
    //     (res1 == res2) != false ||
    //     resArr.toString() != "[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]"
    // ) {
    //     return -1
    // }

    return 0
}
