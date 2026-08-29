package ystyle::cordis_plugin.examples.macro_demo

import ystyle::cordis_plugin.macros.*
import jsonvalue.*

@Plugin[]
public class MacroPlugin {
    @Provide["echo"]
    public func echo(args: Array<JsonValue>): JsonValue {
        if (args.size > 0) {
            args[0]
        } else {
            JsonValue.Null
        }
    }

    @Provide["add"]
    public func add(args: Array<JsonValue>): JsonValue {
        let a = match (args[0]) { case JsonValue.Number(n) => n; case _ => 0.0 }
        let b = match (args[1]) { case JsonValue.Number(n) => n; case _ => 0.0 }
        JsonValue.Number(a + b)
    }
}
