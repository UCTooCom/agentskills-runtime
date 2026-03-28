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
package f_base

public enum OS <: Equatable<OS> & ToString & Hashable {
    | Linux
    | Windows
    | macOS
    | HarmonyOS

    public operator func ==(other: OS): Bool {
        match ((this, other)) {
            case (Linux, Linux) | (Windows, Windows) | (macOS, macOS) | (HarmonyOS, HarmonyOS) => true
            case _ => false
        }
    }
    public prop isWindows: Bool {
        get() {
            this == Windows
        }
    }
    public prop isLinux: Bool {
        get() {
            this == Linux
        }
    }
    public prop isMacOS: Bool {
        get() {
            this == macOS
        }
    }
    public prop isHarmonyOS: Bool {
        get() {
            this == HarmonyOS
        }
    }
    public func toString(): String {
        match (this) {
            case Linux => "Linux"
            case Windows => "Windows"
            case macOS => "macOS"
            case HarmonyOS => "HarmonyOS"
        }
    }
    public static func valueOf(value: String): OS {
        match (value.toAsciiLower()) {
            case "linux" => Linux
            case "windows" => Windows
            case "macos" => macOS
            case "harmonyos" => HarmonyOS
            case _ => throw IllegalArgumentException("unsupported os name: ${value}")
        }
    }
    public func hashCode(): Int64 {
        'fountain.base.OS.${this}'.hashCode()
    }

    @When[os == "Linux"]
    public static prop current: OS {
        get() {
            Linux
        }
    }

    @When[os == "Windows"]
    public static prop current: OS {
        get() {
            Windows
        }
    }

    @When[os == "macOS"]
    public static prop current: OS {
        get() {
            macOS
        }
    }

    @When[os == "HarmonyOS"]
    public static prop current: OS {
        get() {
            HarmonyOS
        }
    }

    @When[os != "Windows"]
    public prop nextLine: String {
        get() {
            '\n'
        }
    }

    @When[os == "Windows"]
    public prop nextLine: String {
        get() {
            '\r\n'
        }
    }
}
