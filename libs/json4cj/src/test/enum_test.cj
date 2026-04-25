package json4cj.test

import std.unittest.testmacro.{Test, TestCase, Assert}
internal import stdx.encoding.json.stream.*
import json4cj.jsonmacro.{JsonSerialize}
import json4cj.*

/*
 * Test enum type JSON serialization and deserialization.
 *
 * Feature A: @JsonSerialize on enum declarations directly
 * Feature B: Enum as a field type in @JsonSerialize classes
 */

// ==================== Enum Declarations ====================

// Test 1: Simple enum with @JsonSerialize
@JsonSerialize
enum Status {
    | Active
    | Inactive
    | Pending
}

// Test 2: Another simple enum
@JsonSerialize
enum Direction {
    | Up
    | Down
    | Left
    | Right
}

// ==================== Classes with enum fields ====================

// Test 3: Class containing enum field
@JsonSerialize
public class Task {
    var name: String = ""
    var status: Status = Active
}

// Test 4: Class with Option<Enum> field
@JsonSerialize
public class Project {
    var title: String = ""
    var currentState: Option<Status> = None
}

// ==================== Test Cases ====================

@Test
class TestEnumDirect {

    @TestCase
    func testEnumToJsonValue(): Unit {
        let s: Status = Active
        let jv = s.toJsonValue()
        @Assert((jv as JsonString).getOrThrow().getValue() == "Active")
    }

    @TestCase
    func testEnumToJson(): Unit {
        let s: Status = Inactive
        let json = s.toJson()
        // toJson wraps in quotes: "Inactive"
        @Assert(json == "\"Inactive\"")
    }

    @TestCase
    func testEnumFromJsonValue(): Unit {
        let jv: JsonValue = JsonString("Pending")
        let s = Status.fromJsonValue(jv)
        @Assert(s.toJson() == "\"Pending\"")
    }

    @TestCase
    func testEnumFromJson(): Unit {
        let s = Status.fromJson("\"Active\"")
        @Assert(s.toJsonValue().toString() == "\"Active\"")
    }

    @TestCase
    func testEnumRoundtrip(): Unit {
        let original: Direction = Direction.Up
        let json = original.toJson()
        let restored = Direction.fromJson(json)
        @Assert(restored.toJson() == original.toJson())
    }

    @TestCase
    func testAllDirectionVariants(): Unit {
        @Assert(Direction.Up.toJson() == "\"Up\"")
        @Assert(Direction.Down.toJson() == "\"Down\"")
        @Assert(Direction.Left.toJson() == "\"Left\"")
        @Assert(Direction.Right.toJson() == "\"Right\"")
    }

    @TestCase
    func testAllStatusVariants(): Unit {
        let a: Status = Active
        let i: Status = Inactive
        let p: Status = Pending
        @Assert(a.toJson() == "\"Active\"")
        @Assert(i.toJson() == "\"Inactive\"")
        @Assert(p.toJson() == "\"Pending\"")
    }

    @TestCase
    func testEnumFromJsonValueUnknownThrows(): Unit {
        let jv: JsonValue = JsonString("Unknown")
        var threw = false
        try {
            let _ = Status.fromJsonValue(jv)
        } catch (_: Exception) {
            threw = true
        }
        @Assert(threw)
    }
}

@Test
class TestEnumInClass {

    @TestCase
    func testClassWithEnumFieldSerialization(): Unit {
        let task = Task()
        task.name = "Build API"
        task.status = Active

        let json = task.toJson()
        println("Task serialized: ${json}")
        @Assert(json.contains("\"status\""))
        @Assert(json.contains("\"Active\""))
    }

    @TestCase
    func testClassWithEnumFieldDeserialization(): Unit {
        let json = ##"{"name":"Deploy Service","status":"Active"}"##
        let task = Task.fromJson(json)
        @Assert(task.name == "Deploy Service")
        @Assert(task.status.toJson() == "\"Active\"")
    }

    @TestCase
    func testClassWithEnumFieldRoundtrip(): Unit {
        let task = Task()
        task.name = "Test Task"
        task.status = Pending

        let json = task.toJson()
        let restored = Task.fromJson(json)
        @Assert(restored.name == "Test Task")
        @Assert(restored.status.toJson() == "\"Pending\"")
    }

    @TestCase
    func testClassWithEnumDifferentValues(): Unit {
        let task1 = Task()
        task1.name = "Task 1"
        task1.status = Inactive

        let json1 = task1.toJson()
        let restored1 = Task.fromJson(json1)
        @Assert(restored1.status.toJson() == "\"Inactive\"")

        let task2 = Task()
        task2.name = "Task 2"
        task2.status = Pending

        let json2 = task2.toJson()
        let restored2 = Task.fromJson(json2)
        @Assert(restored2.status.toJson() == "\"Pending\"")
    }

    @TestCase
    func testOptionEnumSerialization(): Unit {
        let project1 = Project()
        project1.title = "Website Redesign"
        project1.currentState = Some(Active)

        let json1 = project1.toJson()
        println("Project with status: ${json1}")
        @Assert(json1.contains("\"Active\""))

        let project2 = Project()
        project2.title = "Backend API"
        project2.currentState = None

        let json2 = project2.toJson()
        println("Project without status: ${json2}")
        @Assert(json2.contains("null"))
    }

    @TestCase
    func testOptionEnumDeserialization(): Unit {
        let json = ##"{"title":"Mobile App","currentState":"Pending"}"##
        let project = Project.fromJson(json)
        @Assert(project.title == "Mobile App")
        match (project.currentState) {
            case Some(status) => @Assert(status.toJson() == "\"Pending\"")
            case None => @Assert(false)
        }
    }

    @TestCase
    func testOptionEnumNullDeserialization(): Unit {
        let json = ##"{"title":"Empty Project","currentState":null}"##
        let project = Project.fromJson(json)
        @Assert(project.title == "Empty Project")
        match (project.currentState) {
            case Some(_) => @Assert(false)
            case None => () // expected
        }
    }
}
