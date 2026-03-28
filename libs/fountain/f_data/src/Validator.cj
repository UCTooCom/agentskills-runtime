/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
package f_data

public abstract class Validator {
    public const Validator(public let messageIfNotMatch!: String = '') {}
    public func validate(value: ?String): Bool

    public const operator func &(right: Validator){
        AndValidator(this, right)
    }
    public const operator func |(right: Validator){
        OrValidator(this, right)
    }
    public const operator func !(){
        NotValidator(this)
    }
}
@Annotation[target: [MemberVariable, MemberProperty, Parameter]]
public class CombinedValidator <: Validator {
    public const CombinedValidator(messageIfNotMatch: String, public let validator: Validator){
        super(messageIfNotMatch: messageIfNotMatch)
    }
    public const init(validator: Validator){
        this('', validator)
    }
    public func validate(value: ?String): Bool {
        this.validator.validate(value)
    }
}
public class DummyValidator <: Validator {
    public static const instance = DummyValidator()
    private const init() {}
    public func validate(value: ?String): Bool {
        return true
    }
}
public class AndValidator <: Validator{
    const AndValidator(private let left: Validator, private let right: Validator){}
    public func validate(value: ?String): Bool {
        left.validate(value) && right.validate(value)
    }
}
public class OrValidator <: Validator{
    const OrValidator(private let left: Validator, private let right: Validator){}
    public func validate(value: ?String): Bool {
        left.validate(value) || right.validate(value)
    }
}
public class NotValidator <: Validator{
    const NotValidator(private let condition: Validator){}
    public func validate(value: ?String): Bool {
        !condition.validate(value)
    }
}