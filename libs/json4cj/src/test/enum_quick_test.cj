package json4cj.test

/*
 * Quick verification: @JsonSerialize on enum generates JsonCodec interface.
 * This file intentionally left minimal — full tests in enum_test.cj.
 */

import json4cj.jsonmacro.{JsonSerialize}
import json4cj.*

@JsonSerialize
enum QuickColor {
    | Red
    | Green
    | Blue
}
