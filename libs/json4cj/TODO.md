# json4cj TODO

Last updated: 2026-04-12

## Design Philosophy: Aligned with Rust Serde

**Why Serde, not Jackson?**
- Both use **compile-time macro code generation**, not runtime reflection
- Compile-time type safety and predictable behavior
- Zero runtime overhead - all configuration resolved at compile time
- Explicit over implicit - annotations are the configuration, no global state
- No ObjectMapper needed - each type is self-contained

**Key Differences from Jackson:**
- ❌ No ObjectMapper (global configuration)
- ❌ No runtime feature flags
- ✅ All configuration via annotations (@JsonInclude, @JsonType, etc.)
- ✅ Code is configuration - what you see is what you get

## Blocked by cjc 1.0.1

| # | Item | Detail | Unblock condition |
|---|------|--------|-------------------|
| B1 | Generic class Stream API | `extend<T>` guarded with `!isGeneric` — **all** generic classes (not just Option) cannot generate Stream `toJson(w)`/`fromJson(r)`. Two bugs: (1) `writeValue<T>()` fails: cjc cannot resolve `T <: JsonSerializable` even with `where T <: JsonValueSerializable<T>`; (2) `readValue<Option<T>>()` fails: cjc cannot resolve `Option<T> <: JsonDeserializable<Option<T>>` | cjc fixes constraint propagation; remove `!isGeneric` guard in `class_and_struct_info.cj` |

---

## Phase 2 Remaining

| # | Item | Effort | Priority | Dependencies | Key files | Status |
|---|------|--------|----------|-------------|-----------|--------|
| ~~P2-11~~ | ~~ObjectMapper base API~~ | ~~3d~~ | ~~P2~~ | ~~None~~ | ~~New file `object_mapper.cj`~~ | ❌ Removed - Serde has no ObjectMapper, each type is self-contained |
| ~~P2-12~~ | ~~Module system (JsonModule)~~ | ~~3d~~ | ~~P2~~ | ~~P2-11~~ | ~~New file `json_module.cj`~~ | ❌ Removed - Not needed without ObjectMapper |
| P2-13 | Prop property serialization | 2d | P2 | None | `class_processor.cj`, `field_config_builder.cj` | ❌ |

### P2-10: Error handling enhancement — ✅ COMPLETED

Already implemented:
- `fromJsonValue(json, path)` with `_path: String` parameter propagation
- Nested JSON Path in exceptions: `$.profile.address.zip`
- Both HashMap and Stream deserializers support path propagation
- 10 test cases in `error_handling_test.cj`

### P2-11: ObjectMapper - REMOVED

**Decision**: Following Serde design philosophy, ObjectMapper is not needed.

**Rationale:**
- Serde (Rust) has no ObjectMapper - uses explicit annotations instead
- Compile-time macro generation makes global configuration unnecessary
- Each type's behavior is self-contained and predictable
- No hidden global state or configuration

**Current approach:**
```cangjie
@JsonSerialize
@JsonInclude[NON_NULL]
class User {
    var name: String
    var bio: Option<String>
}

// Direct usage, no ObjectMapper needed
let json = user.toJson()
let user2 = User.fromJson(json)
```

### P2-12: JsonModule - REMOVED

**Decision**: Not needed without ObjectMapper.

**Rationale:**
- JsonModule was designed for ObjectMapper plugin system
- Serde uses custom derive macros and trait implementations instead
- Custom serializers can be implemented via manual trait impl

---

### P2-13: Prop property serialization

```cangjie
@JsonSerialize
class Circle {
    var radius: Float64 = 0.0
    @JsonProperty["area"]
    public prop area: Float64 {
        get() { 3.14159 * radius * radius }
    }
}
```

- Read-only prop: serialize only (no deserialize)
- Extend `ClassProcessor` / `ClassVarDeclVisitor` to handle `PropDecl`
- `FieldConfigBuilder` needs PropDecl support

---

## Phase 3 Remaining

| # | Item | Effort | Priority | Dependencies | Status |
|---|------|--------|----------|-------------|--------|
| P3-14 | Polymorphic types (Serde-aligned) | 5d | P1 | None | ✅ Internal tagging done, 3 strategies remaining |
| ~~P3-16~~ | ~~JSON Schema generation~~ | ~~4d~~ | ~~P3~~ | ~~P2-11~~ | ❌ Blocked by ObjectMapper removal |
| ~~P3-17~~ | ~~HTTP library integration~~ | ~~4d~~ | ~~P3~~ | ~~P2-11~~ | ❌ Should be done at application layer, not in json4cj |
| P3-18 | Validation framework | 3d | P2 | None | ❌ Consider as separate crate (like serde + validator) |

### P3-14: Polymorphic types (serde-aligned) — ✅ Internal Tagging COMPLETED

**Completed** (commit `ac45a8d`):
- ✅ Internal tagging strategy: `@JsonTypeInfo[tag="type"]` + `@JsonSubTypes["dog" => Dog]`
- ✅ Subclass discriminator: `@JsonType["dog"]`
- ✅ PolymorphicProcessor generates full serialization/deserialization code
- ✅ Dynamic dispatch with `open` methods
- ✅ `ArrayList<BaseType>` polymorphism support
- ✅ 12 comprehensive test cases (polymorphic_macro_test.cj)
- ✅ Error handling: unknown type, missing discriminator

**Remaining** (3 days):
- ⏳ External tagging: `{"Dog":{"name":"Buddy"}}` - Serde's `#[serde(tag = "type")]`
- ⏳ Adjacent tagging: `{"type":"dog","data":{"name":"Buddy"}}` - Serde's `#[serde(tag = "type", content = "data")]`
- ⏳ Untagged: infer from fields (no type field) - Serde's `#[serde(untagged)]`

### P3-14: Polymorphic types (serde-aligned)

Feasibility already verified (see DESIGN_AND_ROADMAP.md §2.5):
- ✅ Cangjie supports implicit upcast (`ArrayList<Animal>` can hold `Dog`)
- ✅ Covariant return types work (function returning `Animal` can `return Dog()`)
- ✅ `is` type check + `as` downcast (`Option<T>`) work
- ⚠️ Base class must be `open`, methods must be `open`

```cangjie
@JsonTypeInfo[tag = "type"]
@JsonSubTypes[["dog" => Dog, "cat" => Cat]]
@JsonSerialize
class Animal {
    var name: String = ""
}
```

4 tagging strategies (aligned with Serde):
- Internal: `{"type":"dog","name":"Buddy"}` - `#[serde(tag = "type")]` ✅ Done
- External: `{"Dog":{"name":"Buddy"}}` - `#[serde(tag = "type")]` with wrapper
- Adjacent: `{"type":"dog","data":{"name":"Buddy"}}` - `#[serde(tag = "type", content = "data")]`
- Untagged: `{"name":"Buddy"}` - `#[serde(untagged)]` (infer from fields)

### P3-16: JSON Schema generation - BLOCKED

**Status**: Blocked by ObjectMapper removal.

**Decision**: Should be implemented as a separate tool (like `schemars` crate for Serde).

**Alternative**: `json4cj-schema` standalone tool that reads type metadata and generates JSON Schema.

### P3-17: HTTP library integration - REMOVED FROM SCOPE

**Decision**: This should NOT be in json4cj core library.

**Rationale:**
- Serde doesn't integrate with HTTP libraries directly
- Application layer should compose json4cj + HTTP client
- Example: kube-cj can provide integration wrappers

**Example usage:**
```cangjie
// Application layer integration, not json4cj responsibility
let json = user.toJson()
let response = httpClient.post(url, body: json)
```

### P3-18: Validation framework - SEPARATE CRATE

**Decision**: Should be a separate library `json4cj-validation` (like `validator` + `serde`).

**Design:**
```cangjie
@JsonSerialize
@JsonValidate  // Validation macro (separate crate)
class User {
    @JsonRequired
    var name: String = ""
    
    @JsonRange[1, 150]
    var age: Int64 = 0
}

// Usage
let result = user.validate()  // Returns ValidationResult
```

---

## Low-priority / Nice-to-have

| # | Item | Notes |
|---|------|-------|
| L1 | Generic struct tests (plan Task 10d) | HashMap path works; struct is just class with value semantics |
| L2 | Where clause preservation tests (plan Task 10e) | User-defined constraints preserved? |
| L3 | Code generation cleanup | Reduce `cangjieLex` string concatenation, use more `quote()` + `$()` interpolation |
| L4 | `Rune` type extension | Serialize as single-char string |
| L5 | `Array<T>` type extension | Native array vs `ArrayList<T>` |

---

## Completed (history)

| # | Item | Commit |
|---|------|--------|
| P1-1 | GlobalConfig thread-safety | `3f70696` |
| P1-2 | UInt type extensions | `e14c6ab` |
| P1-3 | Option error handling | `904f5b3` |
| P1-4 | @JsonIgnoreUnknown | `d343f1c` → `7b696ad` |
| P1-5 | @JsonInclude | `211f90d` |
| P1-6 | @JsonFormat | `713ee2f` |
| P1-7 | @JsonCreator | `87a1b6d` |
| P2-8 | Enum serialization (simple + parameterized) | Done |
| P2-9 | Stream API (JsonWriter/JsonReader) | Done |
| P2-10 | Error handling (JSON path propagation) | Done (10 test cases) |
| P2-15 | Generic class serialization | Done |
| P2-S1 | Stream Rust-like Option<T> refactoring | Done |
| P2-S2 | cjc constraint propagation bug verification | Done |
| P3-14a | Polymorphic types - Internal tagging | `ac45a8d` (12 tests) |
| ~~P2-V1~~ | ~~Bare type param @JsonCreator validation~~ | Cancelled (not needed) |
