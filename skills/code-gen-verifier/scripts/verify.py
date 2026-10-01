#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verify.py —— code-gen-verifier 技能的质量闸门执行体（tasks.md #222 / §3.3）

背景：§3.3 的「代码生成类缺口强制挂 code-gen-verifier 验证环节」此前只在
`extend_capability.py` 里**声明**（extension_plan.json 的 quality_gate 字段），
而本技能只有一个 SKILL.md、没有任何可执行入口——闸门永远不会被真正执行，
等价于「生成即交付」。本脚本把 SKILL.md 描述的 5 步落成可执行体。

五步验证：
  Step1 completeness —— 文件完整性：给定文件必须存在；给定 --table 时
                        五层（PO/DAO/Service/Controller/Route）必须齐全
  Step2 syntax       —— 语法验证：复用 cangjie-coder 的 cangjie_syntax_check.py
  Step3 compile      —— 编译验证：复用 cangjie-coder 的 cangjie_compile.py
                        （verify_level=compile/test 时执行，需要 cjpm 工具链）
  Step4 spec         —— uctoo-v4 规范：PO @DataAssist / DAO <: RootDAO /
                        Service APIResult<T> / Controller RESTful / Route 注册
  Step5 fix_suggest  —— 修复建议：复用 cangjie-coder 的 cangjie_fix_suggest.py

闸门纪律：工具链缺失导致某步**没能真正验证**时，默认视为未通过（--on-missing-toolchain fail），
并在 degraded / degraded_reasons 中说明原因。绝不因为「检查器没跑起来」就报 passed——
那比不设闸门更危险。无 SDK 的环境可显式用 --verify-level syntax 只跑静态层。

输入：
  --files <路径,逗号分隔>          需要验证的文件（必填，或配合 --table 使用）
  --project-path <项目根>          编译验证的项目根目录
  --verify-level syntax|compile|test   默认 compile
  --table <表名>                   可选，按表名做五层完整性检查
  --outdir <输出目录>              默认 output/verified
  --strict                         语法检查严格模式
  --timeout <秒>                   编译超时，默认 300
  --on-missing-toolchain fail|warn 工具链缺失时的判定，默认 fail

输出（JSON 落盘 + stdout 摘要）：
  { passed, verify_level, degraded, degraded_reasons, steps:[{name,passed,detail}],
    errors:[...], warnings:[...], fix_suggestions:[...] }
退出码：0=通过 / 1=未通过 / 2=参数或环境错误
"""
import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone, timedelta

# 五层后缀 → 层名（uctoo-v4：Model→DAO→Service→Controller→Route）
LAYER_SUFFIX = [
    ("PO.cj", "Model"),
    ("DAO.cj", "DAO"),
    ("Service.cj", "Service"),
    ("Controller.cj", "Controller"),
    ("Route.cj", "Route"),
]

# Step4 规范规则：每层必须出现的特征（正则）
SPEC_RULES = {
    "PO.cj": [("@DataAssist", "PO 类缺少 @DataAssist 注解")],
    "DAO.cj": [(r"<:\s*RootDAO", "DAO 未继承 RootDAO")],
    "Service.cj": [(r"APIResult<", "Service 方法未返回 APIResult<T>")],
    "Controller.cj": [(r"\bres\.", "Controller 未使用 res.* 输出响应"),
                      (r"public\s+func", "Controller 无 public func 处理函数")],
    "Route.cj": [(r"router\.(post|get|put|delete)\s*\(", "Route 未注册任何端点"),
                 (r"/api/v1/uctoo/", "Route 端点未遵循 /api/v1/uctoo/ 前缀")],
}

SECRET_RE = re.compile(
    r"(sk-[A-Za-z0-9]{12,}|api_key\s*=\s*['\"]?.{8,}|password\s*=\s*['\"]?.{8,})", re.I)

LEVELS = ["syntax", "compile", "test"]


def _now():
    return datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="seconds")


def _cangjie_scripts_dir(explicit: str) -> str:
    """定位 cangjie-coder 的 scripts 目录（本脚本位于 skills/code-gen-verifier/scripts）。"""
    if explicit:
        return explicit
    env = os.environ.get("CANGJIE_CODER_SCRIPTS", "")
    if env and os.path.isdir(env):
        return env
    here = os.path.dirname(os.path.abspath(__file__))
    guess = os.path.normpath(os.path.join(here, "..", "..", "cangjie-coder", "scripts"))
    return guess


def _split_files(raw: str) -> list:
    """支持逗号/分号/顿号分隔，也支持换行。"""
    if not raw:
        return []
    parts = re.split(r"[,;、\n]+", raw)
    return [p.strip() for p in parts if p.strip()]


def _run_helper(script_path: str, args: list, timeout: int) -> dict:
    """调 cangjie-coder 的子脚本，返回 {ok, data, detail, missing}。"""
    if not os.path.isfile(script_path):
        return {"ok": False, "data": None,
                "detail": "检查器不存在: %s" % script_path, "missing": True}
    try:
        r = subprocess.run([sys.executable, script_path] + args,
                           capture_output=True, text=True, timeout=timeout,
                           encoding="utf-8", errors="replace")
    except Exception as e:
        return {"ok": False, "data": None, "detail": "执行检查器失败: %s" % e, "missing": False}
    out = (r.stdout or "").strip()
    try:
        data = json.loads(out) if out else None
    except Exception:
        data = None
    detail = out[:500] if out else ((r.stderr or "")[:300] or "无输出")
    return {"ok": r.returncode == 0, "data": data, "detail": detail, "missing": False}


def _strip_comments(text: str) -> str:
    """剥掉仓颉注释后再做规范匹配。

    ★ 不剥注释会漏判（实测）：被验证文件里若注释提到 `@DataAssist` 这类关键字，
      正则会在注释里命中，于是「实际缺注解」被误判为合规。
      逐字符扫描以避开字符串字面量中的 // 与 /* （如 URL "https://..."）。
    """
    out = []
    i, n = 0, len(text)
    in_str = in_char = False
    esc = False
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if in_str:
            out.append(c)
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if in_char:
            out.append(c)
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == "'":
                in_char = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
            continue
        if c == "'":
            in_char = True
            out.append(c)
            i += 1
            continue
        if c == "/" and nxt == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c == "/" and nxt == "*":
            i += 2
            while i < n and not (text[i] == "*" and i + 1 < n and text[i + 1] == "/"):
                if text[i] == "\n":
                    out.append("\n")  # 保留行结构，便于行号定位
                i += 1
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def _layer_of(path: str) -> str:
    base = os.path.basename(path)
    for suffix, layer in LAYER_SUFFIX:
        if base.endswith(suffix):
            return suffix
    return ""


def step_completeness(files: list, table: str, project_path: str):
    """Step1 文件完整性。"""
    errors, warnings = [], []
    for f in files:
        if not os.path.isfile(f):
            errors.append({"file": f, "code": "missing_file", "message": "文件不存在: %s" % f})
        elif os.path.getsize(f) == 0:
            errors.append({"file": f, "code": "empty_file", "message": "文件为空: %s" % f})

    if table and project_path and os.path.isdir(project_path):
        found = {}
        for root, _dirs, names in os.walk(project_path):
            for n in names:
                if n.startswith(table):
                    for suffix, layer in LAYER_SUFFIX:
                        if n.endswith(suffix):
                            found.setdefault(layer, os.path.join(root, n))
        for _suffix, layer in LAYER_SUFFIX:
            if layer not in found:
                errors.append({"file": "%s*%s" % (table, layer),
                               "code": "missing_layer",
                               "message": "五层缺 %s 层（表名 %s）" % (layer, table)})
    elif table and not (project_path and os.path.isdir(project_path)):
        warnings.append({"file": table, "code": "no_project_path",
                         "message": "未给 --project-path 或目录不存在，跳过五层完整性检查"})
    return errors, warnings


def step_syntax(files: list, scripts_dir: str, strict: bool, timeout: int):
    """Step2 语法验证（复用 cangjie_syntax_check.py）。

    ★ 上游约定校正（务必保留此注释）：cangjie_syntax_check.py 的 `passed` 字段
      只要 issues 非空即为 False——全是 warning 也报未通过。本项目真实源码
      （如 AgentApprovalsPO.cj）在该检查器下会产出 7~8 条 warning 而 passed=false。
      若闸门照单全收，等于拒绝所有正确代码，比不设闸门更有害。
      故此处**不信上游 passed**，改按每条 issue 的 severity 自行分级：
      error → 闸门错误；warning → 仅告警。
    """
    errors, warnings, missing = [], [], False
    checker = os.path.join(scripts_dir, "cangjie_syntax_check.py")
    for f in files:
        if not f.lower().endswith(".cj"):
            continue
        if not os.path.isfile(f):
            continue  # 已在 Step1 记为 error，不重复报
        res = _run_helper(checker, ["--file", f] + (["--strict"] if strict else []), timeout)
        if res["missing"]:
            missing = True
            warnings.append({"file": f, "code": "no_syntax_checker",
                             "message": res["detail"]})
            continue
        data = res["data"] or {}
        issues = data.get("issues") or []
        for it in issues:
            sev = str((it or {}).get("severity", "warning")).lower()
            line = (it or {}).get("line", 0)
            msg = "%s（第 %s 行）" % ((it or {}).get("message", ""), line)
            if sev == "error":
                errors.append({"file": f, "code": "syntax_error", "message": msg})
            else:
                warnings.append({"file": f, "code": "syntax_warning", "message": msg})
        # 检查器失败但无任何 issue（如自身崩溃）：不能静默放过
        if not res["ok"] and not issues:
            errors.append({"file": f, "code": "syntax_error", "message": res["detail"]})
    return errors, warnings, missing


def step_compile(project_path: str, scripts_dir: str, timeout: int):
    """Step3 编译验证（复用 cangjie_compile.py）。"""
    errors, warnings, missing = [], [], False
    if not (project_path and os.path.isdir(project_path)):
        return [], [{"file": project_path or "", "code": "no_project_path",
                     "message": "未提供有效的 --project-path，跳过编译验证"}], True
    checker = os.path.join(scripts_dir, "cangjie_compile.py")
    res = _run_helper(checker, ["--project", project_path, "--timeout", str(timeout)],
                      timeout + 30)
    if res["missing"]:
        return [], [{"file": project_path, "code": "no_compile_checker",
                     "message": res["detail"]}], True
    data = res["data"] or {}
    for e in (data.get("errors") or []):
        errors.append({"file": str(e.get("file", project_path)) if isinstance(e, dict) else project_path,
                       "code": "compile_error",
                       "message": str(e.get("message", e) if isinstance(e, dict) else e)})
    for w in (data.get("warnings") or []):
        warnings.append({"file": str(w.get("file", project_path)) if isinstance(w, dict) else project_path,
                         "code": "compile_warning",
                         "message": str(w.get("message", w) if isinstance(w, dict) else w)})
    if not res["ok"] and not (data.get("errors") or []):
        errors.append({"file": project_path, "code": "compile_error", "message": res["detail"]})
    return errors, warnings, missing


def step_spec(files: list):
    """Step4 uctoo-v4 规范验证。"""
    errors, warnings = [], []
    for f in files:
        suffix = _layer_of(f)
        if not suffix or suffix not in SPEC_RULES:
            warnings.append({"file": f, "code": "unknown_layer",
                             "message": "无法判定所属分层（PO/DAO/Service/Controller/Route），跳过规范检查"})
            continue
        if not os.path.isfile(f):
            continue
        try:
            text = open(f, "r", encoding="utf-8", errors="replace").read()
        except Exception as e:
            errors.append({"file": f, "code": "unreadable", "message": "读取失败: %s" % e})
            continue
        code = _strip_comments(text)
        for pattern, msg in SPEC_RULES[suffix]:
            if not re.search(pattern, code):
                errors.append({"file": f, "code": "spec_violation", "message": msg})
        hit = SECRET_RE.search(code)
        if hit:
            errors.append({"file": f, "code": "secret_leak", "message": "疑似硬编码密钥，需人工复核"})
    return errors, warnings


def step_fix_suggest(files: list, errors: list, scripts_dir: str, timeout: int):
    """Step5 修复建议（复用 cangjie_fix_suggest.py），旁路：失败不影响主判定。"""
    suggestions = []
    checker = os.path.join(scripts_dir, "cangjie_fix_suggest.py")
    if not os.path.isfile(checker):
        return suggestions
    bad = sorted({e["file"] for e in errors if e.get("file")})
    for f in bad:
        if not os.path.isfile(f) or not f.lower().endswith(".cj"):
            continue
        err_text = "\n".join(e["message"] for e in errors if e.get("file") == f)[:2000]
        res = _run_helper(checker, ["--file", f, "--error", err_text], timeout)
        data = res["data"] or {}
        for s in (data.get("suggestions") or []):
            suggestions.append({"file": f, "suggestion": s})
    return suggestions


def verify(files, project_path, level, table, scripts_dir, strict, timeout):
    steps, errors, warnings = [], [], []
    degraded, reasons = False, []

    e, w = step_completeness(files, table, project_path)
    errors += e
    warnings += w
    steps.append({"name": "completeness", "passed": not e,
                  "detail": "文件与五层齐全" if not e else "%d 项缺失/为空" % len(e)})

    e, w, miss = step_syntax(files, scripts_dir, strict, timeout)
    errors += e
    warnings += w
    if miss:
        degraded, _ = True, reasons.append("syntax 检查器不可用")
    steps.append({"name": "syntax", "passed": not e,
                  "detail": "语法检查通过" if not e else "%d 处语法错误" % len(e)})

    if level in ("compile", "test"):
        e, w, miss = step_compile(project_path, scripts_dir, timeout)
        errors += e
        warnings += w
        if miss:
            degraded = True
            reasons.append("compile 检查器不可用或无有效 --project-path")
        steps.append({"name": "compile", "passed": not e,
                      "detail": "编译通过" if not e else "%d 处编译错误" % len(e)})
    else:
        steps.append({"name": "compile", "passed": True,
                      "detail": "verify_level=%s，按约定跳过编译验证" % level})

    e, w = step_spec(files)
    errors += e
    warnings += w
    steps.append({"name": "spec", "passed": not e,
                  "detail": "符合 uctoo-v4 规范" if not e else "%d 处规范违规" % len(e)})

    fix_suggestions = step_fix_suggest(files, errors, scripts_dir, timeout)
    steps.append({"name": "fix_suggest", "passed": True,
                  "detail": "产出 %d 条修复建议" % len(fix_suggestions)})

    # 闸门纪律：工具链缺失 = 没有真正验证，默认判未通过
    passed = not errors
    if degraded and not errors:
        passed = False

    failed = [s["name"] for s in steps if not s["passed"]]
    summary = "通过" if passed else "未通过: " + ("; ".join(failed) or "闸门降级未真正验证")
    return {
        "tool": "code-gen-verifier",
        "passed": passed,
        "verify_level": level,
        "project_path": project_path,
        "files": files,
        "table": table,
        "degraded": degraded,
        "degraded_reasons": reasons,
        "on_missing_toolchain": None,  # 由 main 填
        "steps": steps,
        "errors": errors,
        "warnings": warnings,
        "fix_suggestions": fix_suggestions,
        "summary": summary,
        "checked_at": _now(),
    }


def main() -> int:
    p = argparse.ArgumentParser(description="code-gen-verifier 质量闸门（生成代码的语法/编译/规范验证）")
    p.add_argument("--files", default="", help="待验证文件，逗号/分号分隔")
    p.add_argument("--files-file", default="", help="待验证文件清单（每行一个）")
    p.add_argument("--project-path", default="", help="项目根目录（编译验证用）")
    p.add_argument("--verify-level", default="compile", choices=LEVELS)
    p.add_argument("--table", default="", help="可选，按表名做五层完整性检查")
    p.add_argument("--outdir", default="output/verified")
    p.add_argument("--output", default="", help="显式指定输出 JSON 路径")
    p.add_argument("--strict", action="store_true", help="语法检查严格模式")
    p.add_argument("--timeout", type=int, default=300, help="编译超时（秒）")
    p.add_argument("--on-missing-toolchain", default="fail", choices=["fail", "warn"],
                   help="工具链缺失导致无法验证时的判定，默认 fail（未验证即未通过）")
    p.add_argument("--cangjie-scripts", default="", help="cangjie-coder 的 scripts 目录")
    args = p.parse_args()

    files = _split_files(args.files)
    if args.files_file:
        if not os.path.isfile(args.files_file):
            print("ERROR: --files-file 不存在: %s" % args.files_file, file=sys.stderr)
            return 2
        files += _split_files(open(args.files_file, "r", encoding="utf-8").read())
    # 去重保序
    seen, uniq = set(), []
    for f in files:
        if f not in seen:
            seen.add(f)
            uniq.append(f)
    files = uniq

    if not files and not args.table:
        print("ERROR: --files 与 --table 至少要提供一个", file=sys.stderr)
        return 2

    scripts_dir = _cangjie_scripts_dir(args.cangjie_scripts)
    result = verify(files, args.project_path, args.verify_level, args.table,
                    scripts_dir, args.strict, args.timeout)
    result["on_missing_toolchain"] = args.on_missing_toolchain
    # 显式选择 warn 时，降级不再判未通过（由调用方承担风险）
    if args.on_missing_toolchain == "warn" and result["degraded"] and not result["errors"]:
        result["passed"] = True
        result["summary"] = "通过（降级：%s）" % "、".join(result["degraded_reasons"] or ["部分步骤未执行"])

    out_path = args.output or os.path.join(args.outdir, "verify_code_gen.json")
    d = os.path.dirname(os.path.abspath(out_path))
    if d:
        os.makedirs(d, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(json.dumps({
        "ok": True,
        "status": "passed" if result["passed"] else "failed",
        "degraded": result["degraded"],
        "output": out_path,
        "summary": result["summary"],
        "error_count": len(result["errors"]),
        "fix_suggestion_count": len(result["fix_suggestions"]),
    }, ensure_ascii=False))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
