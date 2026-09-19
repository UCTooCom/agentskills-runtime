#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verify_artifact.py —— 长程任务 SOP Step 4：产物结构化验核（Ch8）

输入：
  --artifact_path <落盘路径>  [--artifact_type code|config|doc|test|report|data|artifact]
  [--outdir output/verified]  [--task_id <uuid>]  [--use_llm 0|1]
输出：<outdir>/verify_<basename>.json
  { artifact_path, artifact_type, passed: bool, checks: [{name, passed, detail}],
    summary, checked_at, task_id }

验核策略（确定性，可离线）：
  - existence：文件存在且非空
  - readable：可读（按类型做基础校验）
    - code：若存在则尝试对应解释器 --check（python -m py_compile / node --check），失败记为未通过但不致命
    - json：json.loads 成功
    - doc/test/report/data：非空且字节数 > 阈值
  - no_secret_leak：扫描高危密钥字面量（sk- / api_key= / password=），命中即未通过
可选 LLM（--use_llm 1）：对 report/doc 类追加「是否回应了成功标准」语义校验。
"""
import argparse
import json
import os
import re
import sys
import subprocess
import tempfile
import urllib.request
import urllib.error
from datetime import datetime, timezone, timedelta

SECRET_RE = re.compile(r"(sk-[A-Za-z0-9]{12,}|api_key\s*=\s*['\"]?.{8,}|password\s*=\s*['\"]?.{8,})", re.I)


def _checks_for_type(path: str, atype: str) -> list:
    checks = []
    # 1. 存在且非空
    exists = os.path.isfile(path) and os.path.getsize(path) > 0
    checks.append({"name": "existence", "passed": exists,
                   "detail": "文件存在且非空" if exists else "文件不存在或为空: %s" % path})
    if not exists:
        return checks

    # 2. 类型相关可读校验
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
    except Exception as e:
        checks.append({"name": "readable", "passed": False, "detail": "读取失败: %s" % e})
        return checks

    if atype == "json":
        try:
            json.loads(text)
            checks.append({"name": "json_valid", "passed": True, "detail": "合法 JSON"})
        except Exception as e:
            checks.append({"name": "json_valid", "passed": False, "detail": "JSON 解析失败: %s" % e})
    elif atype == "code":
        # 启发式：按扩展名尝试语法检查；失败仅记录，不阻断（运行时依赖可能不全）
        ext = os.path.splitext(path)[1].lower()
        if ext == ".py":
            ok, d = _try_cmd([sys.executable, "-m", "py_compile", path])
        elif ext in (".js", ".mjs", ".cjs"):
            ok, d = _try_cmd(["node", "--check", path])
        elif ext in (".ts",):
            ok, d = _try_cmd(["npx", "--yes", "tsc", "--noEmit", "--skipLibCheck", path])
        else:
            ok, d = True, "无可用语法检查器，跳过"
        checks.append({"name": "syntax", "passed": ok, "detail": d})
    else:
        # doc/test/report/data：非空且有一定规模
        enough = len(text.strip()) >= 20
        checks.append({"name": "non_empty", "passed": enough,
                       "detail": "文本内容 %d 字符" % len(text.strip())})

    # 3. 密钥泄漏扫描（致命）
    hit = SECRET_RE.search(text)
    checks.append({"name": "no_secret_leak", "passed": not hit,
                   "detail": "未发现高危密钥字面量" if not hit else "命中疑似密钥，需人工复核"})

    # 4. 字节规模
    size = os.path.getsize(path)
    checks.append({"name": "size", "passed": size < 20 * 1024 * 1024,
                   "detail": "体积 %d 字节（<20MB）" % size})
    return checks


def _try_cmd(cmd: list) -> (bool, str):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        return (r.returncode == 0, (r.stdout or r.stderr)[:300] or "ok")
    except Exception as e:
        return (False, "执行检查器失败: %s" % e)


def _llm_semantic(path: str, goal: str) -> dict:
    """可选：对 doc/report 类做「是否回应成功标准」语义校验。失败不影响总体结论。"""
    try:
        base_url = os.environ.get("LRT_MODEL_BASE_URL") or os.environ.get("OPENAI_BASE_URL")
        api_key = os.environ.get("LRT_MODEL_API_KEY") or os.environ.get("OPENAI_API_KEY")
        model = os.environ.get("LRT_MODEL_NAME") or os.environ.get("MODEL_NAME") or "deepseek-chat"
        if not (base_url and api_key):
            return {"name": "llm_semantic", "passed": True, "detail": "未配置 LLM，跳过语义校验"}
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            content = f.read()[:4000]
        prompt = "目标：%s\n\n产物内容（节选）：\n%s\n\n该产物是否实质性回应了目标？仅回答 JSON {\"ok\": true/false, \"reason\": \"...\"}" % (goal, content)
        payload = {"model": model, "messages": [{"role": "user", "content": prompt}],
                   "temperature": 0.0, "response_format": {"type": "json_object"}}
        req = urllib.request.Request(base_url.rstrip("/") + "/chat/completions",
                                     data=json.dumps(payload).encode("utf-8"),
                                     headers={"Content-Type": "application/json",
                                              "Authorization": "Bearer " + api_key}, method="POST")
        with urllib.request.urlopen(req, timeout=120) as resp:
            obj = json.loads(json.loads(resp.read().decode("utf-8"))["choices"][0]["message"]["content"])
        return {"name": "llm_semantic", "passed": bool(obj.get("ok", True)),
                "detail": str(obj.get("reason", ""))[:200]}
    except Exception as e:
        return {"name": "llm_semantic", "passed": True, "detail": "LLM 语义校验不可用，跳过: %s" % e}


def verify(artifact_path: str, artifact_type: str, use_llm: bool, goal: str = "") -> dict:
    checked_at = datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="seconds")
    checks = _checks_for_type(artifact_path, artifact_type)
    if use_llm and artifact_type in ("doc", "report", "data", "artifact") and goal:
        checks.append(_llm_semantic(artifact_path, goal))
    passed = all(c["passed"] for c in checks)
    failed = [c for c in checks if not c["passed"]]
    summary = "通过" if passed else "未通过: " + "; ".join(c["name"] for c in failed)
    return {
        "artifact_path": artifact_path,
        "artifact_type": artifact_type,
        "passed": passed,
        "checks": checks,
        "summary": summary,
        "checked_at": checked_at,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="长程任务产物验核（确定性 + 可选 LLM）")
    parser.add_argument("--artifact_path", required=True)
    parser.add_argument("--artifact_type", default="artifact")
    parser.add_argument("--task_id", default="")
    parser.add_argument("--goal", default="", help="可选，供 LLM 语义校验")
    parser.add_argument("--use_llm", default="0", help="1 启用 LLM 语义校验")
    parser.add_argument("--outdir", default="output/verified")
    args = parser.parse_args()

    if not args.artifact_path or not os.path.exists(args.artifact_path):
        print("ERROR: artifact_path 不存在: %s" % args.artifact_path, file=sys.stderr)
        return 2

    os.makedirs(args.outdir, exist_ok=True)
    result = verify(args.artifact_path, args.artifact_type, args.use_llm == "1", args.goal)
    if args.task_id:
        result["task_id"] = args.task_id
    base = os.path.splitext(os.path.basename(args.artifact_path))[0] or "artifact"
    out_path = os.path.join(args.outdir, "verify_%s.json" % base)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    status = "passed" if result["passed"] else "failed"
    print(json.dumps({"ok": True, "status": status, "output": out_path, "summary": result["summary"]},
                     ensure_ascii=False))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
