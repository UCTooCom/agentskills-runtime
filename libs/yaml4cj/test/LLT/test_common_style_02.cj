// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*
import std.collection.*

main() {
    // 2023年2月27日 不再提供外部能力

    // var a = NullStyleT.NullStyleT_NULL_STYLE
    // if(a.hashCode()!= 7735158833260202274) {
    //     return -1
    // }

    // var b = ScalarStyleT.ScalarStyleT_FOLDED_SCALAR_STYLE
    // if(b.hashCode()!= 7735162150664032787 || b.toString() != "ScalarStyleT_FOLDED_SCALAR_STYLE") {
    //     return -1
    // }

    // var c = SequenceStyleT.SequenceStyleT_FLOW_SEQUENCE_STYLE
    // if(c.hashCode()!= 7735158414128985144) {
    //     return -1
    // }

    // var d = MappingStyleT.MappingStyleT_ANY_MAPPING_STYLE
    // if(d.hashCode()!= 7735156289023744394) {
    //     return -1
    // }
    return 0
}
