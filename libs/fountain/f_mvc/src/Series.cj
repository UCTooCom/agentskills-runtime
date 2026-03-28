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
package f_mvc

/**
 * HTTP status series.
 * Retrievable via HttpStatus series.
 */
public class Series <: Equatable<Series> {
    public static let INFORMATIONAL = Series(1)
    public static let SUCCESSFUL = Series(2)
    public static let REDIRECTION = Series(3)
    public static let CLIENT_ERROR = Series(4)
    public static let SERVER_ERROR = Series(5)

    private static let series = HashMap<Int64, Series>()
    static init() {
        for (s in [INFORMATIONAL, SUCCESSFUL, REDIRECTION, CLIENT_ERROR, SERVER_ERROR]) {
            series[s.value] = s
        }
    }

    private Series(public let value: Int64) {}

    public static prop values: Array<Series> {
        get() {
            [INFORMATIONAL, SUCCESSFUL, REDIRECTION, CLIENT_ERROR, SERVER_ERROR]
        }
    }
    public operator func ==(series: Series) {
        refEq(this, series) || this.value == series.value
    }

    public static func valueOf(status: HttpStatus): Series {
        return status.series
    }

    public static func valueOf(status: Int64): Series {
        let series = resolve(status)
        match (series) {
            case Some(s) => s
            case _ => throw IllegalArgumentException("No matching constant for [${status}]")
        }
    }

    public static func resolve(status: Int64): Option<Series> {
        let code = status / 100
        series.get(code)
    }
}
