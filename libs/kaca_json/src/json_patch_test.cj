package kaca_json

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

private func opName(op: PatchOp): String {
    match (op) {
        case PatchOp.Add => "Add"
        case PatchOp.Remove => "Remove"
        case PatchOp.Replace => "Replace"
        case PatchOp.Move => "Move"
        case PatchOp.Copy => "Copy"
        case PatchOp.Test => "Test"
    }
}

@Test
public class JsonPatchTests {
    private func buildBase(): JsonValue {
        let obj = HashMap<String, JsonValue>()
        obj["a"] = JsonValue.JsonNumber(1.0)
        obj["b"] = JsonValue.JsonString("two")
        obj["c"] = JsonValue.JsonArray(ArrayList<JsonValue>())
        return JsonValue.JsonObject(obj)
    }

    @TestCase
    public func testCreateList() {
        @Assert(JsonPatch.createList().size, 0)
    }

    @TestCase
    public func testAddNewField() {
        let ops = JsonPatch.createList()
        ops.add(JsonPatch.add("/d", JsonValue.JsonNumber(4.0)))
        let result = JsonPatch.apply(buildBase(), ops)
        @Assert(result.get("d").isSome())
        @Assert(result.get("d").getOrThrow().requireNumber(), 4.0)
    }

    @TestCase
    public func testRemoveField() {
        let ops = JsonPatch.createList()
        ops.add(JsonPatch.remove("/a"))
        let result = JsonPatch.apply(buildBase(), ops)
        @Assert(result.get("a").isNone())
        @Assert(result.get("b").isSome())
    }

    @TestCase
    public func testReplaceField() {
        let ops = JsonPatch.createList()
        ops.add(JsonPatch.replace("/a", JsonValue.JsonNumber(99.0)))
        let result = JsonPatch.apply(buildBase(), ops)
        @Assert(result.get("a").getOrThrow().requireNumber(), 99.0)
    }

    @TestCase
    public func testMoveField() {
        let ops = JsonPatch.createList()
        ops.add(JsonPatch.move("/a", "/moved"))
        let result = JsonPatch.apply(buildBase(), ops)
        @Assert(result.get("a").isNone())
        @Assert(result.get("moved").isSome())
    }

    @TestCase
    public func testCopyField() {
        let ops = JsonPatch.createList()
        ops.add(JsonPatch.copy("/a", "/a_copy"))
        let result = JsonPatch.apply(buildBase(), ops)
        @Assert(result.get("a").isSome())
        @Assert(result.get("a_copy").isSome())
    }

    @TestCase
    public func testTestPass() {
        let ops = JsonPatch.createList()
        ops.add(JsonPatch.test("/a", JsonValue.JsonNumber(1.0)))
        @Assert(JsonPatch.apply(buildBase(), ops).isObject())
    }

    @TestCase
    public func testTestFail() {
        let ops = JsonPatch.createList()
        ops.add(JsonPatch.test("/a", JsonValue.JsonNumber(999.0)))
        try {
            let _ = JsonPatch.apply(buildBase(), ops)
            @Assert(false)
        } catch (_: Exception) { @Assert(true) }
    }

    @TestCase
    public func testPatchOpAdd() {
        let op = PatchOperation.add("/p", JsonValue.JsonNumber(1.0))
        @Assert(opName(op.op), "Add")
        @Assert(op.path, "/p")
    }

    @TestCase
    public func testPatchOpRemove() {
        let op = PatchOperation.remove("/x")
        @Assert(opName(op.op), "Remove")
    }

    @TestCase
    public func testPatchOpReplace() {
        let op = PatchOperation.replace("/x", JsonValue.JsonBool(false))
        @Assert(opName(op.op), "Replace")
    }

    @TestCase
    public func testPatchOpMove() {
        let op = PatchOperation.move("/from", "/to")
        @Assert(opName(op.op), "Move")
        let hasFrom = match (op.fromPath) { case Some(from) => from == "/from"; case None => false }
        @Assert(hasFrom)
    }

    @TestCase
    public func testPatchOpCopy() {
        let op = PatchOperation.copy("/src", "/dst")
        @Assert(opName(op.op), "Copy")
    }

    @TestCase
    public func testPatchOpTest() {
        let op = PatchOperation.test("/k", JsonValue.JsonNull)
        @Assert(opName(op.op), "Test")
    }

    @TestCase
    public func testPatchMultiple() {
        let v = buildBase()
        let ops = JsonPatch.createList()
        ops.add(JsonPatch.remove("/a"))
        ops.add(JsonPatch.add("/x", JsonValue.JsonNumber(10.0)))
        ops.add(JsonPatch.replace("/b", JsonValue.JsonString("updated")))
        let result = JsonPatch.apply(v, ops)
        @Assert(result.get("a").isNone())
        @Assert(result.get("x").getOrThrow().requireNumber(), 10.0)
        @Assert(result.get("b").getOrThrow().requireString(), "updated")
    }

    @TestCase
    public func testGetPathParts() {
        let op = PatchOperation.add("/a/b/c", JsonValue.JsonNull)
        let parts = op.getPathParts()
        @Assert(parts.size, 3)
        @Assert(parts[0], "a")
        @Assert(parts[2], "c")
    }

    @TestCase
    public func testJsonPatchFunc() {
        let ops = JsonPatch.createList()
        ops.add(JsonPatch.add("/n", JsonValue.JsonString("v")))
        @Assert(jsonPatch(buildBase(), ops).get("n").isSome())
    }
}
