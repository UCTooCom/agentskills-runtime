package json4cj.test

import std.unittest.*

// ===== Test covariant return with explicit cast =====

open class Animal {
    public var name: String = ""
}

class Dog <: Animal {
    public var breed: String = ""
}

class Cat <: Animal {
    public var lives: Int64 = 9
}

// Test 1: Can we return subclass and cast to base?
func createDog(): Dog {
    let dog = Dog()
    dog.name = "Buddy"
    dog.breed = "Labrador"
    return dog
}

func createAnimal(): Animal {
    // Can we return Dog as Animal?
    let dog = createDog()
    return dog  // This should work (upcast)
}

// Test 2: Can we use if-else to return different subclasses?
func createAnimalByType(animalType: String): Animal {
    if (animalType == "dog") {
        let dog = Dog()
        dog.name = "Doggy"
        return dog  // ❓ Does this work?
    } else {
        let cat = Cat()
        cat.name = "Kitty"
        return cat  // ❓ Does this work?
    }
}

@Test
public class TestCovariantReturn {
    
    @TestCase
    func testSimpleUpcast(): Unit {
        // Simple upcast should work
        let dog = createDog()
        let animal: Animal = dog  // Explicit upcast
        
        @Assert(animal.name, "Buddy")
    }

    @TestCase
    func testReturnSubclassAsBase(): Unit {
        // Function returning subclass as base type
        let animal = createAnimal()
        
        @Assert(animal.name, "Buddy")
    }

    @TestCase
    func testIfElseReturnDifferentSubclasses(): Unit {
        // The critical test: if-else returning different subclasses
        let dogAnimal = createAnimalByType("dog")
        @Assert(dogAnimal.name, "Doggy")
        
        let catAnimal = createAnimalByType("cat")
        @Assert(catAnimal.name, "Kitty")
    }
}
