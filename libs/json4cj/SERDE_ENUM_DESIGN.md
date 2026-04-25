# Serde-Style Enum Polymorphism Design

## 🎯 Core Insight

**Serde uses Enums, not Class Inheritance**

This is the fundamental difference that solves all our strategy inheritance problems.

## 📊 Comparison

### Current json4cj Approach (Class Inheritance)
```cangjie
@JsonTypeInfo[EXTERNAL]
@JsonSubTypes["dog" => Dog, "cat" => Cat]
@JsonSerialize
open class Animal { }

@JsonType["dog"]
class Dog <: Animal {
    var name: String = ""
}

// Problem: Dog doesn't know about EXTERNAL strategy
// Solution: Need complex parent class introspection
```

### Serde Approach (Enum Variants)
```rust
#[derive(Serialize, Deserialize)]
#[serde(tag = "type")]  // Strategy defined once on enum
enum Animal {
    Dog { name: String },    // Variant, not a separate class
    Cat { name: String, lives: i64 },
}
// All variants automatically inherit the strategy
```

## 🚀 Proposed json4cj Enum Approach

### Option 1: Cangjie Enum (Recommended)

```cangjie
// Define all variants in one place
@JsonSerialize
@JsonTypeInfo[EXTERNAL]
enum Animal {
    | Dog(name: String, breed: String)
    | Cat(name: String, lives: Int64)
}

// Usage
let animal = Animal.Dog("Buddy", "Labrador")
let json = animal.toJson()
// {"Dog":{"name":"Buddy","breed":"Labrador"}}

let animal2 = Animal.fromJson(json)
```

**Advantages:**
- ✅ Strategy defined once on enum
- ✅ All variants automatically inherit
- ✅ Closed set of variants (compiler knows all)
- ✅ No subclass strategy inheritance problem
- ✅ Matches Serde's design exactly
- ✅ Simpler code generation

**Challenges:**
- ⚠️ Cangjie enums with fields may have limitations
- ⚠️ Need to verify macro support on enum variants
- ⚠️ May require significant refactoring

### Option 2: Hybrid Approach (Sealed Classes)

If Cangjie enums can't support complex variants, use sealed class pattern:

```cangjie
// Sealed base class (no subclasses outside this file)
@JsonSerialize
@JsonTypeInfo[EXTERNAL]
sealed class Animal {
    // Private constructor prevents external subclassing
    private init() {}
}

// Variants in same file
class Dog <: Animal {
    var name: String = ""
    var breed: String = ""
}

class Cat <: Animal {
    var name: String = ""
    var lives: Int64 = 9
}
```

**Key difference from current approach:**
- `sealed` keyword indicates closed set of subclasses
- Macro can scan file for all subclasses
- Strategy inheritance is implicit (same file = same strategy)

## 🔧 Implementation Strategy

### Phase 1: Support Enum-based Polymorphism

1. **Extend @JsonSerialize to work on enums**
   - Already works for simple enums
   - Need to support enums with field-carrying variants

2. **New Enum Processor**
   - Generate serialization code for each variant
   - Apply strategy from enum-level annotation
   - No strategy inheritance problem (single type)

3. **Variant Code Generation**
   ```cangjie
   // For EXTERNAL strategy
   enum Animal {
       | Dog(name: String, breed: String)
       | Cat(name: String, lives: Int64)
   }
   
   // Generated code:
   public func toJsonValue(): JsonValue {
       match (this) {
           case Dog(name, breed) =>
               var innerMap = HashMap<String, JsonValue>()
               innerMap.add("name", name.toJsonValue())
               innerMap.add("breed", breed.toJsonValue())
               var outerMap = HashMap<String, JsonValue>()
               outerMap.add("Dog", JsonObject(innerMap))
               JsonObject(outerMap)
           
           case Cat(name, lives) =>
               var innerMap = HashMap<String, JsonValue>()
               innerMap.add("name", name.toJsonValue())
               innerMap.add("lives", lives.toJsonValue())
               var outerMap = HashMap<String, JsonValue>()
               outerMap.add("Cat", JsonObject(innerMap))
               JsonObject(outerMap)
       }
   }
   ```

### Phase 2: Keep Class Inheritance (Backward Compatible)

For users who need open inheritance:
- Keep current class-based approach
- Fix strategy inheritance via runtime lookup
- Document limitations

## 📝 Recommendation

**Follow Serde's lead: Use Enums for polymorphism**

1. **Primary API**: Enum-based polymorphism (like Serde)
   - Cleaner design
   - No strategy inheritance issues
   - Compiler-enforced variant completeness
   - Better type safety

2. **Secondary API**: Class-based polymorphism (existing)
   - Keep for backward compatibility
   - Use for open inheritance scenarios
   - Fix strategy inheritance with runtime check

3. **Migration Path**:
   - Document enum approach as recommended
   - Provide examples comparing both
   - Keep class approach for special cases

## 🎯 Next Steps

1. **Investigate Cangjie enum capabilities**
   - Can enums carry fields?
   - Can macros access enum variants?
   - What are the limitations?

2. **Prototype enum-based polymorphism**
   - Simple test with 2-3 variants
   - All 4 tagging strategies
   - Serialization + deserialization

3. **Compare with class-based approach**
   - Code complexity
   - Performance
   - User experience
   - Maintainability

4. **Decision point**
   - If enums work well → Migrate to enum-first design
   - If enums limited → Fix class-based strategy inheritance

## 📚 References

- [Serde Enum Representations](https://serde.rs/enum-representations.html)
- [Serde Attributes](https://serde.rs/attributes.html)
- Current implementation: `polymorphic_processor.cj`
- Design doc: `POLYMORPHIC_DESIGN.md`
