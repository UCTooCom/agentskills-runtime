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
package f_log

// //'\u{1B}[1;43;31mTEXT\u{1B}[0m'
// //\u{1B}[大于等于0个;分隔的样式数字串;0或1个背景色数字串;0或1个前景色数字串m显示的文本\u{1B}[0m
// //如果样式、背景色、前景色都没有：'\u{1B}[0mTEXT\u{1B}[0m'。这是默认样式

// /*
// * 颜色命名参考标准值
// * https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
// * https://jakob-bagterp.github.io/colorist-for-python/user-guide/materials/ansi-escape-codes/#foreground-text-and-background-colors
// * https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
// * https://www.cnblogs.com/aifengqi/p/15395422.html
// * https://talyian.github.io/ansicolors/
// * https://bixense.com/clicolors/
// * https://no-color.org/
// */
// //前景色
// Black  "30"
// Red  "31"
// Green  "32"
// Yellow  "33"
// Blue  "34"
// Magenta  "35"
// Cyan  "36"
// White  "37"
// BrightBlack  "90"
// BrightRed  "91"
// BrightGreen  "92"
// BrightYellow  "93"
// BrightBlue  "94"
// BrightMagenta  "95"
// BrightCyan  "96"
// BrightWhite  "97"

// //背景色
// Black  "40"            黑
// Red  "41"              红
// Green  "42"            绿
// Yellow  "43"           黄
// Blue  "44"             蓝
// Magenta  "45"          洋红
// Cyan  "46"             青
// White  "47"            白
// BrightBlack  "100"      
// BrightRed  "101"
// BrightGreen  "102"
// BrightYellow  "103"
// BrightBlue  "104"
// BrightMagenta  "105"
// BrightCyan  "106"
// BrightWhite  "107"

// //字体样式
// Bold  "1"
// Dimmed  "2"
// Italic  "3"
// Underline  "4"
// Blink  "5"
// Reversed  "7"
// Hidden  "8"
// Strikethrough  "9"

// //'\u{1B}[1;43;31mTEXT\u{1B}[0m'
// //\u{1B}[大于等于0个;分隔的样式数字串;0或1个背景色数字串;0或1个前景色数字串m显示的文本\u{1B}[0m
// //如果样式、背景色、前景色都没有：'\u{1B}[0mTEXT\u{1B}[0m'。这是默认样式
// OFF     
// FATAL   \u{1B}[1;5;43;91mFATAL\u{1B}[0m
// ERROR   \u{1B}[1;91mERROR\u{1B}[0m
// WARN    \u{1B}[1;91mWARN\u{1B}[0m
// INFO    \u{1B}[92mINFO\u{1B}[0m
// DEBUG   \u{1B}[34mDEBUG\u{1B}[0m
// ALL     
