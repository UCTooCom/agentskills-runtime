/**
 * @file
 * This is about constant.
 */

package yaml4cj.yaml

let YAML_NULL_TAG = "tag:yaml.org,2002:null" // The tag !!null with the only possible value: null.
let YAML_BOOL_TAG = "tag:yaml.org,2002:bool" // The tag !!bool with the values: true and false.
let YAML_STR_TAG = "tag:yaml.org,2002:str" // The tag !!str for string values.
let YAML_INT_TAG = "tag:yaml.org,2002:int" // The tag !!int for integer values.
let YAML_FLOAT_TAG = "tag:yaml.org,2002:float" // The tag !!float for float values.
let YAML_TIMESTAMP_TAG = "tag:yaml.org,2002:timestamp" // The tag !!timestamp for date and time values.

let YAML_SEQ_TAG = "tag:yaml.org,2002:seq" // The tag !!seq is used to denote sequences.
let YAML_MAP_TAG = "tag:yaml.org,2002:map" // The tag !!map is used to denote mapping.

// Not in original libyaml.
let YAML_BINARY_TAG = "tag:yaml.org,2002:binary"
let YAML_MERGE_TAG = "tag:yaml.org,2002:merge"
