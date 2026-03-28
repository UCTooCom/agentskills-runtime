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
package f_data.validation

import std.convert.*
import f_base.*
import f_regex.*
import f_data.*

@Annotation[target: [MemberVariable, MemberProperty, Parameter]]
public class IsNotEmpty <: Validator {
    public const init(messageIfNotMatch!: String = '') {
        super(messageIfNotMatch: messageIfNotMatch)
    }
    public func validate(value: ?String): Bool {
        (value ?? '').size > 0
    }
}

@Annotation[target: [MemberVariable, MemberProperty, Parameter]]
public class IsNotBlank <: Validator {
    public const init(messageIfNotMatch!: String = '') {
        super(messageIfNotMatch: messageIfNotMatch)
    }
    public func validate(value: ?String): Bool {
        (value ?? '').trimAsciiBlanks().size > 0
    }
}
@Annotation[target: [MemberVariable, MemberProperty, Parameter]]
public class StringSize <: Validator {
    public const StringSize(messageIfNotMatch!: String = '', private let min!: Int64 = 0, private let max!: Int64 = 0x7FFF_FFFF_FFFF_FFFF) {
        super(messageIfNotMatch: messageIfNotMatch)
    }
    public func validate(value: ?String): Bool {
        let v = value ?? ''
        v.size >= 0 && v.size <= max
    }
}

@Annotation[target: [MemberVariable, MemberProperty, Parameter]]
public class IsInteger <: Validator {
    public const init(messageIfNotMatch!: String = '') {
        super(messageIfNotMatch: messageIfNotMatch)
    }
    public func validate(value: ?String): Bool {
        let v = value ?? ''
        Regex.INTEGER.matches(v)
    }
}

@Annotation[target: [MemberVariable, MemberProperty, Parameter]]
public class IsDecimal <: Validator {
    public const init(messageIfNotMatch!: String = '') {
        super(messageIfNotMatch: messageIfNotMatch)
    }
    public func validate(value: ?String): Bool {
        let v = value ?? ''
        Regex.DECIMAL.matches(v)
    }
}

@Annotation[target: [MemberVariable, MemberProperty, Parameter]]
public class IsEmail <: Validator {
    public const init(messageIfNotMatch!: String = '') {
        super(messageIfNotMatch: messageIfNotMatch)
    }
    public func validate(value: ?String): Bool {
        let v = value ?? ''
        Regex.EMAIL.matches(v)
    }
}

@Annotation[target: [MemberVariable, MemberProperty, Parameter]]
public class IsChineseCellPhone <: Validator {
    public const IsChineseCellPhone(
        messageIfNotMatch!: String = '',
        private let withCountryCode!: Bool = false,
        private let countryCodeSeparator!: String = ')'
    ) {
        super(messageIfNotMatch: messageIfNotMatch)
    }
    public func validate(value: ?String): Bool {
        var rege = ''
        if (withCountryCode) {
            rege = match (countryCodeSeparator) {
                case ')' => '(86)'
                case x => '86${x}'
            }
        }
        return '^${rege}1\\d{10}'.regex(solid: true).matches(value ?? '')
    }
}

@Annotation[target: [MemberVariable, MemberProperty, Parameter]]
public class IsIntegerRange <: Validator {
    public const IsIntegerRange(
        messageIfNotMatch!: String = '',
        private let min!: Int64 = 0,
        private let max!: Int64 = 0x7FFF_FFFF_FFFF_FFFF,
        private let minInclusive!: Bool = true,
        private let maxInclusive!: Bool = false
    ) {
        super(messageIfNotMatch: messageIfNotMatch)
    }
    public const init(range: Range<Int64>){
        this(min: range.start, max: range.end, minInclusive: range.hasStart, maxInclusive: range.isClosed || range.hasEnd)
    }
    public func validate(value: ?String): Bool {
        match (Int64.tryParse(value ?? '')) {
            case Some(x) => if (minInclusive) {
                x >= min
            } else {
                x > min
            } && if (maxInclusive) {
                x <= max
            } else {
                x < max
            }
            case _ => false
        }
    }
}

@Annotation[target: [MemberVariable, MemberProperty, Parameter]]
public class IsBool <: Validator {
    public const init(messageIfNotMatch!: String = '') {
        super(messageIfNotMatch: messageIfNotMatch)
    }
    public func validate(value: ?String): Bool {
        let val = (value ?? '').toAsciiLower()
        return val == 'true' || val == 'false'
    }
}
@Annotation[target: [MemberVariable, MemberProperty, Parameter]]
public class IsDateTime <: Validator {
    public const IsDateTime(
        messageIfNotMatch!: String = '',
        private let format!: String = "yyyy-MM-dd HH:mm:ss"
    ) {
        super(messageIfNotMatch: messageIfNotMatch)
    }
    public func validate(value: ?String): Bool {
        try {
            DateTime.parse(value ?? '', format)
            true
        } catch (_){
            false
        }
    }
}
@Annotation[target: [MemberVariable, MemberProperty, Parameter]]
public class IsDuration <: Validator {
    public const init(messageIfNotMatch!: String = '') {
        super(messageIfNotMatch: messageIfNotMatch)
    }
    public func validate(value: ?String): Bool {
        Regex.DURATION.matches(value ?? '')
    }
}
@Annotation[target: [MemberVariable, MemberProperty, Parameter]]
public class IsIntegers <: Validator {
    public const IsIntegers(messageIfNotMatch!: String = '', private let separator!: String = ",") {
        super(messageIfNotMatch: messageIfNotMatch)
    }
    public func validate(value: ?String): Bool {
        '^\\d+(${separator}\\d+)*$'.regex(solid: true).matches(value ?? '')
    }
}

@Annotation[target: [MemberVariable, MemberProperty, Parameter]]
public class DoesMatchRegex <: Validator {
    public const DoesMatchRegex(messageIfNotMatch!: String = '', private let regex!: String) {
        super(messageIfNotMatch: messageIfNotMatch)
    }
    public func validate(value: ?String): Bool {
        this.regex.regex(solid: true).matches(value ?? '')
    }
}