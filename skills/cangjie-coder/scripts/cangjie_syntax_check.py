#!/usr/bin/env python3
"""仓颉代码语法检查脚本

对仓颉代码文件进行静态语法检查，验证代码符合仓颉语言规范。

用法:
    python cangjie_syntax_check.py --file /path/to/file.cj [--strict]

输出:
    JSON格式的检查结果
"""

import argparse
import json
import re
import sys
from pathlib import Path


CANGJIE_KEYWORDS = {
    "Bool", "Rune", "Float16", "Float32", "Float64",
    "Int8", "Int16", "Int32", "Int64", "IntNative",
    "UInt8", "UInt16", "UInt32", "UInt64", "UIntNative",
    "Array", "VArray", "String", "Nothing", "Unit",
    "break", "case", "catch", "continue", "do", "else",
    "finally", "for", "if", "match", "return", "spawn",
    "try", "throw", "while",
    "as", "abstract", "class", "const", "enum", "extend",
    "func", "foreign", "import", "init", "interface",
    "let", "macro", "main", "mut", "open", "operator",
    "override", "package", "private", "prop", "protected",
    "public", "redef", "static", "struct", "super",
    "synchronized", "this", "This", "type", "unsafe", "where",
    "false", "true", "quote"
}

CANGJIE_TYPES = {
    "Int8", "Int16", "Int32", "Int64", "Int",
    "UInt8", "Byte", "UInt16", "UInt32", "UInt64", "UInt",
    "Float16", "Float32", "Float64",
    "Bool", "Rune", "String", "Unit", "Nothing",
    "Array", "VArray", "ArrayList", "HashMap", "HashSet",
    "Option"
}


def check_syntax(file_path: str, strict: bool = False) -> dict:
    result = {
        "tool": "cangjie_syntax_check",
        "file_path": file_path,
        "passed": True,
        "issues": [],
        "warnings": []
    }

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
            lines = content.splitlines()
    except FileNotFoundError:
        result["passed"] = False
        result["issues"].append({
            "line": 0,
            "column": 0,
            "message": f"文件不存在: {file_path}",
            "severity": "error",
            "category": "file"
        })
        return result
    except Exception as e:
        result["passed"] = False
        result["issues"].append({
            "line": 0,
            "column": 0,
            "message": f"文件读取失败: {str(e)}",
            "severity": "error",
            "category": "file"
        })
        return result

    check_package_declaration(lines, result)
    check_import_statements(lines, result)
    check_variable_declarations(lines, result, strict)
    check_function_declarations(lines, result, strict)
    check_class_declarations(lines, result, strict)
    check_error_handling(lines, result, strict)
    check_naming_conventions(lines, result, strict)

    if result["issues"]:
        result["passed"] = False

    return result


def check_package_declaration(lines: list, result: dict):
    has_package = False
    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("package "):
            has_package = True
            break
        if stripped and not stripped.startswith("//") and not stripped.startswith("/*"):
            if not stripped.startswith("import "):
                break

    if not has_package and lines:
        result["warnings"].append({
            "line": 1,
            "column": 1,
            "message": "文件缺少package声明",
            "severity": "warning",
            "category": "package"
        })


def check_import_statements(lines: list, result: dict):
    import_lines = []
    code_started = False

    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("import "):
            if code_started:
                result["issues"].append({
                    "line": i,
                    "column": 1,
                    "message": "import语句应在文件顶部，package声明之后",
                    "severity": "warning",
                    "category": "import"
                })
            import_lines.append((i, stripped))
        elif stripped and not stripped.startswith("//") and not stripped.startswith("/*"):
            code_started = True


def check_variable_declarations(lines: list, result: dict, strict: bool):
    var_pattern = re.compile(r'^\s*(let|var|const)\s+(\w+)\s*:\s*(\w+)')

    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            continue

        match = var_pattern.match(stripped)
        if match:
            decl_type = match.group(1)
            var_name = match.group(2)
            type_name = match.group(3)

            if strict and decl_type == "var":
                result["warnings"].append({
                    "line": i,
                    "column": 1,
                    "message": f"建议使用let替代var声明不可变变量 '{var_name}'",
                    "severity": "warning",
                    "category": "best_practice"
                })


def check_function_declarations(lines: list, result: dict, strict: bool):
    func_pattern = re.compile(r'^\s*func\s+(\w+)\s*\(')

    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        match = func_pattern.match(stripped)
        if match:
            func_name = match.group(1)
            if strict and not func_name[0].islower():
                result["warnings"].append({
                    "line": i,
                    "column": 1,
                    "message": f"函数名 '{func_name}' 应使用camelCase命名",
                    "severity": "warning",
                    "category": "naming"
                })


def check_class_declarations(lines: list, result: dict, strict: bool):
    class_pattern = re.compile(r'^\s*(public\s+|open\s+|abstract\s+)*(class|struct|enum|interface)\s+(\w+)')

    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        match = class_pattern.match(stripped)
        if match:
            modifiers = match.group(1) or ""
            type_keyword = match.group(2)
            type_name = match.group(3)

            if strict and type_keyword == "class" and "public" not in modifiers:
                result["warnings"].append({
                    "line": i,
                    "column": 1,
                    "message": f"类 '{type_name}' 建议添加public修饰符",
                    "severity": "warning",
                    "category": "visibility"
                })


def check_error_handling(lines: list, result: dict, strict: bool):
    has_try_catch = False
    has_option = False
    has_throw = False

    for line in lines:
        stripped = line.strip()
        if "try" in stripped and "{" in stripped:
            has_try_catch = True
        if "Option<" in stripped or "?Int" in stripped or "?String" in stripped:
            has_option = True
        if "throw" in stripped:
            has_throw = True

    if strict and not has_try_catch and not has_option:
        result["warnings"].append({
            "line": 0,
            "column": 0,
            "message": "文件未使用try-catch或Option<T>进行错误处理",
            "severity": "warning",
            "category": "error_handling"
        })


def check_naming_conventions(lines: list, result: dict, strict: bool):
    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("/*"):
            continue

        if "Int" in stripped and "Int32" not in stripped and "Int64" not in stripped and "Int8" not in stripped and "Int16" not in stripped:
            if re.search(r'\bInt\b', stripped) and "Int64" not in stripped:
                if strict:
                    result["warnings"].append({
                        "line": i,
                        "column": 0,
                        "message": "建议使用Int64替代Int，显式指定整数位宽",
                        "severity": "warning",
                        "category": "type_safety"
                    })


def main():
    parser = argparse.ArgumentParser(description="仓颉代码语法检查")
    parser.add_argument("--file", required=True, help="仓颉代码文件路径")
    parser.add_argument("--strict", action="store_true", help="严格模式，检查最佳实践")
    args = parser.parse_args()

    result = check_syntax(args.file, args.strict)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    sys.exit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()