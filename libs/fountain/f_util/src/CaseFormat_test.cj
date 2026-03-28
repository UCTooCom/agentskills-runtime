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
package f_util

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CaseFormat_test {
    @TestCase
    public func test(): Unit {
        @Assert(CaseFormat.Pascal.convert("CaseFormat", to: CaseFormat.Camel), "caseFormat")
        @Assert(CaseFormat.Pascal.convert("CaseFormat", to: CaseFormat.LowerUnderScore), "case_format")
        @Assert(CaseFormat.Pascal.convert("CaseFormat", to: CaseFormat.UpperUnderScore), "CASE_FORMAT")
        @Assert(CaseFormat.Pascal.convert("CaseFormat", to: CaseFormat.LowerHyphen), "case-format")
        @Assert(CaseFormat.Pascal.convert("CaseFormat", to: CaseFormat.UpperHyphen), "CASE-FORMAT")

        @Assert(CaseFormat.Camel.convert("caseFormat", to: CaseFormat.Pascal), "CaseFormat")
        @Assert(CaseFormat.Camel.convert("caseFormat", to: CaseFormat.LowerUnderScore), "case_format")
        @Assert(CaseFormat.Camel.convert("caseFormat", to: CaseFormat.UpperUnderScore), "CASE_FORMAT")
        @Assert(CaseFormat.Camel.convert("caseFormat", to: CaseFormat.LowerHyphen), "case-format")
        @Assert(CaseFormat.Camel.convert("caseFormat", to: CaseFormat.UpperHyphen), "CASE-FORMAT")

        @Assert(CaseFormat.LowerUnderScore.convert("case_format", to: CaseFormat.Camel), "caseFormat")
        @Assert(CaseFormat.LowerUnderScore.convert("case_format", to: CaseFormat.Pascal), "CaseFormat")
        @Assert(CaseFormat.LowerUnderScore.convert("case_format", to: CaseFormat.UpperUnderScore), "CASE_FORMAT")
        @Assert(CaseFormat.LowerUnderScore.convert("case_format", to: CaseFormat.LowerHyphen), "case-format")
        @Assert(CaseFormat.LowerUnderScore.convert("case_format", to: CaseFormat.UpperHyphen), "CASE-FORMAT")

        @Assert(CaseFormat.UpperUnderScore.convert("CASE_FORMAT", to: CaseFormat.Camel), "caseFormat")
        @Assert(CaseFormat.UpperUnderScore.convert("CASE_FORMAT", to: CaseFormat.Pascal), "CaseFormat")
        @Assert(CaseFormat.UpperUnderScore.convert("CASE_FORMAT", to: CaseFormat.LowerUnderScore), "case_format")
        @Assert(CaseFormat.UpperUnderScore.convert("CASE_FORMAT", to: CaseFormat.LowerHyphen), "case-format")
        @Assert(CaseFormat.UpperUnderScore.convert("CASE_FORMAT", to: CaseFormat.UpperHyphen), "CASE-FORMAT")

        @Assert(CaseFormat.LowerHyphen.convert("case-format", to: CaseFormat.Camel), "caseFormat")
        @Assert(CaseFormat.LowerHyphen.convert("case-format", to: CaseFormat.Pascal), "CaseFormat")
        @Assert(CaseFormat.LowerHyphen.convert("case-format", to: CaseFormat.LowerUnderScore), "case_format")
        @Assert(CaseFormat.LowerHyphen.convert("case-format", to: CaseFormat.UpperUnderScore), "CASE_FORMAT")
        @Assert(CaseFormat.LowerHyphen.convert("case-format", to: CaseFormat.UpperHyphen), "CASE-FORMAT")

        @Assert(CaseFormat.UpperHyphen.convert("CASE-FORMAT", to: CaseFormat.Camel), "caseFormat")
        @Assert(CaseFormat.UpperHyphen.convert("CASE-FORMAT", to: CaseFormat.Pascal), "CaseFormat")
        @Assert(CaseFormat.UpperHyphen.convert("CASE-FORMAT", to: CaseFormat.LowerUnderScore), "case_format")
        @Assert(CaseFormat.UpperHyphen.convert("CASE-FORMAT", to: CaseFormat.UpperUnderScore), "CASE_FORMAT")
        @Assert(CaseFormat.UpperHyphen.convert("CASE-FORMAT", to: CaseFormat.LowerHyphen), "case-format")
    }
}
