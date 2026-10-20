#!/usr/bin/env python3
"""仓颉「编译前一轮排净」静态扫描脚本。

背景（务必理解后再用）：
    cjpm/cjc 是**按包**编译的，某个包编译失败时该包的检查即中止，
    而**未轮到的包**、以及**本包尚未检查到的文件**，其中的同类错误
    **不会出现在这一轮日志里**。于是修复必然变成"报错→改→再编译→再报错"
    的多轮往返。

    本脚本用于在「着手修复」之前/之后，把已知的、**形态固定**的高频
    编译错误做一次全域扫描，让一轮修复真正修干净。

用法:
    python cangjie_precompile_scan.py --src <源码根目录> [--quiet] [--json]
    python cangjie_precompile_scan.py --src installer/src

规则（E=ERROR 必改，W=WARN 需人工确认）:
    E1 后置 `?` 类型注解（Rust 风格）：仓颉可选类型是**前置** `?T`
    E2 match 臂多语句块 `case X => {`：`{` 会被解析为 lambda 起始
    E4 `Array<T>` 变量调用了只有 ArrayList 才有的增删方法
    E5 if/while/for 的分支体没写花括号（`do{...}while(cond)` 的尾 while 除外）
    E6 main 无返回类型标注、且函数体末句是返回 Nothing 的调用（如 std.env.exit）
    W1 `let` 声明的变量被重新赋值（不可变变量）

已废止的规则（保留编号空位以免规则编号漂移）:
    E3 「缺 std.collection.* 的 import」——经大库实证为误报而删除，
        详见下方「实证数据与取舍」注释块。

输出:
    JSON 格式的检查结果（或人类可读文本）
"""

import argparse
import json
import re
import sys
from pathlib import Path

# 注意：曾有一版 E3 规则「缺 std.collection.* 的 import」，已被实证证伪并删除。
# 实证数据（本仓 src/，均能通过编译）：
#   - 512 个文件使用 ArrayList，其中 **248 个从未 import**；
#   - 430 个文件使用 HashMap，其中 **314 个从未 import**。
# 说明二者都在 prelude 内，不需 import。
# 教训：**不要凭"这个类型大概不在 prelude"的直觉去写检查规则或"补 import"**，
# 必须先在大库上做覆盖率统计与误报率验证。

# Array<T> 上没有、只有 ArrayList 等动态容器才有的方法
MUTATING_METHODS = ["add", "append", "remove", "insert", "clear"]

ASSIGN_STMT_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)")
DECL_RE = re.compile(r"^\s*(let|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::\s*([^=]+?))?\s*=")
# match 臂行尾出現 => {
MATCH_ARM_BLOCK_RE = re.compile(r"=>\s*\{\s*$")
# if/while/for 的条件括号起始（前置 do{} 右括号的情况由调用方排除）
CTRL_FLOW_RE = re.compile(r"(?:(?<=^)|(?<=[\s};]))(if|while|for)\s*\(")
# 函数/方法签名起点：用于划分 W1 的作用域边界
FUNC_SIG_RE = re.compile(
    r"^\s*(?:(?:public|protected|private|internal)\s+)?"
    r"(?:(?:static|open|override|abstract|redef|mut|unsafe)\s+)*"
    r"(?:func|init|operator func)\s"
)

# 已知返回 Nothing（bottom type）的调用。函数体最后一个表达式若命中，
# 且该函数没有显式返回类型标注 ⇒ 返回类型被推断为 Nothing。
# 对普通函数这未必错，但 main 的返回类型只允许 Unit 或整数类型（E6）。
NOTHING_RETURN_CALLS = ["exit"]

# main 且**没有**显式返回类型标注（`)` 之后直接是 `{`）
MAIN_NO_RET_RE = re.compile(r"^main\s*\([^)]*\)\s*\{")


def strip_comment(line: str) -> str:
    """去掉行注释（不处理字符串字面量内的 //，保守够用）。"""
    idx = line.find("//")
    return line[:idx] if idx >= 0 else line


def find_cj_files(root: Path) -> list:
    if root.is_file():
        return [root] if root.suffix == ".cj" else []
    return sorted(root.rglob("*.cj"))


def check_e1_postfix_option(lines: list, path: str, issues: list):
    """E1: `: Type?`（后置 ?）——仓颉可选类型是前置 `?T`。"""
    pat = re.compile(
        r":\s*([A-Za-z_][A-Za-z0-9_]*(?:\s*<[^{};()]*(?:\s*<[^{};()]*>\s*)?>)?)\s*\?(?=\s*(?:=|;|,|\)|$))"
    )
    for i, raw in enumerate(lines, 1):
        line = strip_comment(raw)
        if "?" not in line:
            continue
        m = pat.search(line)
        if m:
            issues.append({
                "rule": "E1", "severity": "ERROR", "file": path, "line": i,
                "message": "后置 `?` 类型注解（Rust 风格）。仓颉可选类型是前置 `?T` / `Option<T>`",
                "hint": "改为 `?{}` 或 `Option<{}>`".format(m.group(1), m.group(1)),
                "snippet": line.strip(),
            })


def check_e2_match_arm_block(lines: list, path: str, issues: list):
    """E2: `case X => {` —— `{` 被解析为 lambda 起始，块内首条语句会报
    `expected '=>' in lambda expression`。

    合法的例外：下一行去空白后以裸 `=>` 开头（零参 lambda 写法），
    例：JWTAuthMiddleware.cj 的形态。src/test/ 下不在主 build 图中，
    其形态不可作为合法先例。
    """
    for i, raw in enumerate(lines, 1):
        if not MATCH_ARM_BLOCK_RE.search(strip_comment(raw)):
            continue
        nxt = lines[i].strip() if i < len(lines) else ""
        if nxt.startswith("=>"):
            continue  # 零参 lambda，合法
        issues.append({
            "rule": "E2", "severity": "ERROR", "file": path, "line": i,
            "message": "match 臂写了 `{` 多语句块，会被解析为 lambda 起始",
            "hint": "改为 if/else 分支表达式，或把逻辑外提成函数，臂只留单表达式",
            "snippet": strip_comment(raw).strip(),
        })


def check_e4_array_add(lines: list, path: str, issues: list):
    """E4: `Array<T>` 是定长数组，没有 add/append/remove 等方法。"""
    text_lines = [strip_comment(l) for l in lines]
    declared = {}
    for i, l in enumerate(text_lines, 1):
        m = DECL_RE.match(l)
        if m and m.group(3):
            declared.setdefault(m.group(2), {"type": m.group(3).strip(), "line": i, "kw": m.group(1)})
    for name, info in declared.items():
        if not re.match(r"^Array\s*<", info["type"]):
            continue
        for i, l in enumerate(text_lines, 1):
            for meth in MUTATING_METHODS:
                if re.search(r"\b{}\.{}\s*\(".format(re.escape(name), meth), l):
                    issues.append({
                        "rule": "E4", "severity": "ERROR", "file": path, "line": i,
                        "message": "`{}` 声明为 `{}`（定长），却调用了 `.{}()`".format(name, info["type"], meth),
                        "hint": "若需动态增删改用 ArrayList<T>（并补 import std.collection.ArrayList）",
                        "snippet": l.strip(),
                    })


def check_e5_ctrl_flow_braces(lines: list, path: str, issues: list):
    """E5: if/while/for 的分支体必须是代码块 `{...}`。

    语法依据（language.basic_concepts.3-表达式.3-2-if-条件判断）：
        `if (cond) { exprs1 } else { exprs2 }`
        `while (cond) { exprs }`
    花括号是语法的一部分，**不能省**，分支体也不能只写单个表达式。
    典型报错：`expected '{', found 'XXX'`。

    合法例外（必须内置，否则会误报）：
        `do { exprs } while (cond)` —— 尾部的 while 是**语句终结符**，本就无块。
        判据：该行去空白后以 `}` 开头。
        实证：src/dsl/parser.cj:34/46 两处 do-while，是本仓唯一的 2 条潜在误报。

    为什么必须用括号配平而不是 `\\)\\s*[^ {]`：
        正则会把 `if (hasValue(args, idx)) {` 里 `hasValue(...)` 的**第一个** `)`
        当成条件结束（紧随的第二个 `)` 正好命中「非空格非 `{`」），
        在本仓 installer/src 上一次性炸出 20 条假阳性。
    """
    text_lines = [strip_comment(l) for l in lines]
    for i, code in enumerate(text_lines, 1):
        for m in CTRL_FLOW_RE.finditer(code):
            kw = m.group(1)
            j = m.end() - 1  # 指向 '('
            depth = 0
            while j < len(code):
                if code[j] == "(":
                    depth += 1
                elif code[j] == ")":
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            if j >= len(code) or depth != 0:
                continue  # 条件跨行，本规则不处理
            # do { } while (cond) 的尾子句合法且必无块，两个分支都要排除
            if kw == "while" and code.strip().startswith("}"):
                continue
            rest = code[j + 1:].strip()
            if not rest:
                # 条件在行尾：下一行去空白后必须是代码块起始
                nxt = text_lines[i].strip() if i < len(text_lines) else ""
                if not nxt.startswith("{"):
                    issues.append({
                        "rule": "E5", "severity": "ERROR", "file": path, "line": i,
                        "message": "`{}` 条件在行尾，但下一行不是 `{{`".format(kw),
                        "hint": "仓颉分支体必须是代码块 `{...}`，不能只写单个表达式",
                        "snippet": code.strip(),
                    })
                continue
            if rest.startswith("{"):
                continue
            issues.append({
                "rule": "E5", "severity": "ERROR", "file": path, "line": i,
                "message": "`{}` 条件之后的分支体不是代码块".format(kw),
                "hint": "写成 `{} (cond) {{ ... }}`；用作值时同理：`let x = if (c) {{ a }} else {{ b }}`".format(kw),
                "snippet": code.strip(),
            })


def find_body_last_stmt(lines: list, start_idx: int):
    """从函数签名行（下标 start_idx）起做花括号配平，返回 body 内最后一个有效语句。

    返回 (行号, 语句文本)；找不到时返回 (-1, "")。
    **必须剔除字符串字面量与注释**：否则 `sb.append("{")` 里的花括号会被当成代码块，
    使函数"提前收尾"，得出错误的末句。
    """
    depth = 0
    started = False
    last_ln, last_txt = -1, ""
    in_str = False
    triple = False
    i = start_idx
    while i < len(lines):
        raw = lines[i] if in_str else strip_comment(lines[i])
        j = 0
        while j < len(raw):
            c = raw[j]
            if in_str:
                if triple and raw[j:j + 3] == '"""':
                    in_str, triple = False, False
                    j += 3
                    continue
                if not triple and c == '"':
                    in_str = False
                    j += 1
                    continue
                if not triple and c == "\\":
                    j += 2
                    continue
                j += 1
                continue
            if raw[j:j + 3] == '"""':
                in_str, triple = True, True
                j += 3
                continue
            if c == '"':
                in_str, triple = True, False
                j += 1
                continue
            if c == "{":
                depth += 1
                started = True
            elif c == "}":
                depth -= 1
                if started and depth <= 0:
                    return (last_ln, last_txt)
            j += 1
        t = raw.strip()
        if started and t:
            last_ln, last_txt = i + 1, t
        i += 1
    return (last_ln, last_txt)


def check_e6_main_return_type(lines: list, path: str, issues: list):
    """E6: main 没有显式返回类型标注，且函数体末句是返回 Nothing 的调用。

    报错原文：`return type of 'main' is not 'Integer' or 'Unit'`。
    根因：仓颉**省略返回类型时按函数体最后一个表达式推断**；`std.env.exit(code: Int64): Nothing`
    返回的是 bottom type，推断结果就是 Nothing，而 main 的返回类型只允许 Unit 或整数类型。
    """
    for i, raw in enumerate(lines):
        code = strip_comment(raw).strip()
        if not MAIN_NO_RET_RE.match(code):
            continue
        last_ln, last_stmt = find_body_last_stmt(lines, i)
        if not last_stmt:
            continue
        hit = None
        for name in NOTHING_RETURN_CALLS:
            if re.search(r"(?<![A-Za-z0-9_.])" + name + r"\s*\(", last_stmt):
                hit = name
                break
        if hit:
            issues.append({
                "rule": "E6", "severity": "ERROR", "file": path, "line": i + 1,
                "message": "main 未标注返回类型，而函数体末句是返回 Nothing 的 `{}(...)` 调用".format(hit),
                "hint": "显式标注 `main(args: Array<String>): Unit`（或改为返回整数类型后用 return 退出）",
                "snippet": code,
            })


def check_w1_let_reassign(lines: list, path: str, issues: list):
    """W1: `let` 声明的变量被重新赋值 → `cannot assign to immutable value`。

    作用域近似：**以函数/方法签名为边界**划分作用域，在每个作用域内
    记录每个名字「最后一次」声明用的是 `let` 还是 `var`。只有最后一次是
    `let` 时报 WARN。

    为什么这样做（血泪教训）：
    最初版本用「整个文件的 let 名字集合」判定，在本仓 src/ 上炸出 564 条
    **误报**——典型如 `agent_task.cj`：387 行是 `let toolResult`（某方法内），
    而 416 行在另一个方法里是 `var toolResult`，424 行的合法赋值因此被误报；
    `dag_team_orchestrator.cj` 的 `var prompt` 同理。
    教训：**静态检查必须做作用域划分**，否则工具类会淹没在噪音里。
    """
    text_lines = [strip_comment(l) for l in lines]
    last_kind: dict = {}  # 当前函数作用域内： name -> 'let' | 'var'
    declared_at: dict = {}
    for i, l in enumerate(text_lines, 1):
        if FUNC_SIG_RE.match(l):
            last_kind.clear()
            declared_at.clear()
            continue
        m = DECL_RE.match(l)
        if m:
            name, kind = m.group(2), m.group(1)
            last_kind[name] = kind
            declared_at[name] = i
            continue
        a = ASSIGN_STMT_RE.match(l)
        if not a:
            continue
        name = a.group(1)
        if last_kind.get(name) != "let":
            continue
        issues.append({
            "rule": "W1", "severity": "WARN", "file": path, "line": i,
            "message": "`{}` 于第 {} 行由 `let` 声明（不可变），此处却在重新赋值".format(
                name, declared_at.get(name, "?")),
            "hint": "改为 `var`；若是类成员的 prop setter 或跨作用域同名，可忽略",
            "snippet": l.strip(),
        })


def scan_file(path: Path, root: Path) -> list:
    try:
        content = path.read_text(encoding="utf-8")
    except Exception as e:
        return [{"rule": "E0", "severity": "ERROR", "file": str(path), "line": 0,
                 "message": "读取失败: {}".format(e), "hint": "", "snippet": ""}]
    lines = content.splitlines()
    rel = str(path.relative_to(root)) if path != root else path.name
    issues: list = []
    check_e1_postfix_option(lines, rel, issues)
    check_e2_match_arm_block(lines, rel, issues)
    check_e4_array_add(lines, rel, issues)
    check_e5_ctrl_flow_braces(lines, rel, issues)
    check_e6_main_return_type(lines, rel, issues)
    check_w1_let_reassign(lines, rel, issues)
    return issues


def main():
    parser = argparse.ArgumentParser(description="仓颉编译前「一轮排净」静态扫描")
    parser.add_argument("target", nargs="?", default=".", help="源码根目录或单个 .cj 文件")
    parser.add_argument("--src", dest="src_opt", help="源码根目录（兼容既有 --src 写法）")
    parser.add_argument("--json", action="store_true", help="只输出 JSON")
    parser.add_argument("--quiet", action="store_true", help="只输出汇总行")
    args = parser.parse_args()

    root = Path(args.src_opt if args.src_opt else args.target).resolve()
    if not root.exists():
        print(json.dumps({"error": "path not found: {}".format(root)}, ensure_ascii=False))
        sys.exit(2)

    files = find_cj_files(root)
    all_issues: list = []
    for f in files:
        all_issues.extend(scan_file(f, root))

    errors = [i for i in all_issues if i["severity"] == "ERROR"]
    warns = [i for i in all_issues if i["severity"] == "WARN"]

    result = {
        "scanned_files": len(files),
        "root": str(root),
        "error_count": len(errors),
        "warn_count": len(warns),
        "passed": len(errors) == 0,
        "issues": all_issues,
    }

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    elif not args.quiet:
        for i in all_issues:
            print("[{}][{}] {}:{}".format(i["severity"], i["rule"], i["file"], i["line"]))
            print("    {}".format(i["message"]))
            if i["hint"]:
                print("    -> {}".format(i["hint"]))
            if i["snippet"]:
                print("    | {}".format(i["snippet"]))
            print()
        print("=" * 60)
    if not args.json:
        print("扫描 {} 个 .cj 文件 | ERROR={} WARN={} | {}".format(
            len(files), len(errors), len(warns),
            "可提交编译" if result["passed"] else "需修完 ERROR 再编译"))

    sys.exit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()
