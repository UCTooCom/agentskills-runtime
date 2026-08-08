/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

extend JsonValue {
    func toStr(): String {
        match (this.kind()) {
            case JsString => this.asString().getValue()
            case _ => toString()
        }
    }
}

extend JsonKind {
    private func toFlag(): Int64 {
        match (this) {
            case JsNull => 0
            case JsBool => 1
            case JsInt => 2
            case JsFloat => 3
            case JsString => 4
            case JsArray => 5
            case JsObject => 6
        }
    }
    operator func ==(other: JsonKind): Bool {
        this.toFlag() == other.toFlag()
    }
}
