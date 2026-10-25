#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
yuanbao_search.py — 元宝搜索检索内核（SearchPro）+ 可信度四因子标注 + 政策原文库交叉验证
功能与 yuanbao_search.ts 完全一致（CLI 签名与输出结构逐字对齐）

运行方式:
    python yuanbao_search.py --query "专精特新 中小企业 申报 条件" --industry gov --cnt 50 --freshness 1y
    python yuanbao_search.py --selftest

输出: stdout 单行 JSON（结构与 design §2.7.2 一致）；诊断与心跳一律 stderr。
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime

from policy_kb import build_index, load_kb, match_policy
from sign import CredentialError, build_signed_request, load_credential

CNT_ENUM = [10, 20, 30, 40, 50]
TIMEOUT_MS = 5000          # spec §4.1：单次检索 ≤5s
MAX_RETRY = 2              # spec §4.2：退避重试至多 2 次
QUERY_MAX = 200

GOV_HINTS = [".gov.cn", "gov.cn", ".gov.", "beijing.gov"]
PORTAL_HINTS = [
    "xinhuanet.com", "people.com.cn", "cctv.com", "cctv.cn", "chinadaily.com.cn",
    "chinanews.com.cn", "news.cn", "workercn.cn", "gmw.cn", "people.com",
    "163.com", "sina.com.cn", "sohu.com", "qq.com", "baidu.com", "zhihu.com",
]


def warn(msg, warns):
    warns.append(msg)
    sys.stderr.write("[yuanbao-search] 告警：%s\n" % msg)


def clamp_cnt(cnt):
    """Cnt 收敛到枚举 {10,20,30,40,50}"""
    try:
        cnt = int(cnt)
    except Exception:
        return 50
    if cnt <= 0:
        return 50
    return min(CNT_ENUM, key=lambda c: abs(cnt - c))


def normalize_freshness(raw, warns):
    """时效窗归一化 → d[N](1-30) / m[N](1-12) / y[N](1-5) / YYYY-MM-DD / A,B"""
    import re

    s = (raw or "").strip()
    if not s:
        return "", 0

    def cl(n, lo, hi):
        return max(lo, min(hi, n))

    m = re.match(r"^(\d+)\s*([dwmy])$", s, re.I)
    if m:
        n = int(m.group(1))
        u = m.group(2).lower()
        if u == "d":
            return "d%d" % cl(n, 1, 30), cl(n, 1, 30)
        if u == "w":
            return "d%d" % cl(n * 7, 1, 30), cl(n * 7, 1, 30)
        if u == "m":
            return "m%d" % cl(n, 1, 12), cl(n, 1, 12) * 30
        return "y%d" % cl(n, 1, 5), cl(n, 1, 5) * 365

    m = re.match(r"^([dmy])(\d+)$", s, re.I)
    if m:
        u = m.group(1).lower()
        n = int(m.group(2))
        if u == "d":
            return "d%d" % cl(n, 1, 30), cl(n, 1, 30)
        if u == "m":
            return "m%d" % cl(n, 1, 12), cl(n, 1, 12) * 30
        return "y%d" % cl(n, 1, 5), cl(n, 1, 5) * 365

    m = re.match(r"^(\d{4}-\d{2}-\d{2})(?:\.\.(\d{4}-\d{2}-\d{2}))?$", s)
    if m:
        if m.group(2):
            return "%s,%s" % (m.group(1), m.group(2)), 0
        return m.group(1), 0

    warn("--freshness 取值无法识别（%s），本次不携带时效窗" % s, warns)
    return "", 0


def build_payload(args, warns):
    if args.site and args.exclude:
        sys.stderr.write("[yuanbao-search] 错误：--site 与 --exclude 互斥，请只指定其中一个\n")
        sys.exit(2)
    if args.exclude:
        parts = [x.strip() for x in args.exclude.split("|") if x.strip()]
        if len(parts) > 5:
            sys.stderr.write("[yuanbao-search] 错误：--exclude 最多支持 5 个域名（| 分隔）\n")
            sys.exit(2)

    payload = {"Query": args.query}
    if args.industry:
        payload["Industry"] = args.industry
    payload["Cnt"] = clamp_cnt(args.cnt)
    # Mode 默认不携带：实测 Mode=1 旗舰版仅召回 1 条且无 score（design R3 / G4）
    if args.site:
        payload["Site"] = args.site.strip()
    elif args.exclude:
        payload["Site"] = "exclude:%s" % args.exclude.strip()
    if args.deeplinks:
        payload["Deeplinks"] = True
    value, days = normalize_freshness(args.freshness, warns)
    if value:
        payload["Freshness"] = value
    return payload, days


def request_once(url, body, headers, warns, transport_out):
    """出网：标准库 urllib（与 http_client.py 语义一致），超时 5s"""
    req = urllib.request.Request(url, data=body.encode("utf-8"), headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_MS / 1000.0) as resp:
            text = resp.read().decode("utf-8", errors="replace")
            status = resp.getcode()
    except urllib.error.HTTPError as e:
        try:
            text = e.read().decode("utf-8", errors="replace")
        except Exception:
            text = ""
        status = e.code
        try:
            parsed = json.loads(text)
        except Exception:
            return {"status": status, "body": None, "error": "HTTP %s" % status}
        transport_out.append("urllib")
        return {"status": status, "body": parsed, "error": None}
    except Exception as e:
        return {"status": None, "body": None, "error": str(e)}

    try:
        parsed = json.loads(text)
    except Exception:
        parsed = text
    transport_out.append("urllib")
    return {"status": status, "body": parsed, "error": None}


def classify_error(code):
    """错误分类（spec §5.1.3）→ (kind, message)"""
    if code == "RequestLimitExceeded":
        return "retryable", "调用配额超限"
    if code in ("AuthFailure", "UnauthorizedOperation"):
        # 不回显服务端原始消息中的敏感片段（G7）
        return "auth", "凭据无效或未授权"
    if code in ("ResourceUnavailable", "ResourcesSoldOut"):
        return "notopen", "资源不可用，请确认服务开通状态"
    if code == "InternalError":
        return "retryable", "服务内部错误"
    return "struct", code or "未知错误"


def _str(v):
    if isinstance(v, str):
        return v
    if v is None:
        return ""
    return str(v)


def _is_abs_url(u):
    return isinstance(u, str) and (u.startswith("http://") or u.startswith("https://"))


def parse_docs(body, warns):
    """M3 响应解析：Pages 二次 parse + 字段存在性防御"""
    empty = {"docs": [], "version": "", "requestId": "", "dropped": 0}
    if not isinstance(body, dict):
        warn("响应结构异常：顶层不是对象，按空结果处理", warns)
        return empty
    r = body.get("Response", body)
    if not isinstance(r, dict) or r.get("Error"):
        return empty
    pages = r.get("Pages") or []
    if not isinstance(pages, list):
        pages = []
    docs = []
    dropped = 0
    for p in pages:
        # G6：Pages 每个元素是 JSON 字符串，必须二次 parse
        if isinstance(p, str):
            try:
                p = json.loads(p)
            except Exception:
                dropped += 1
                continue
        if not isinstance(p, dict):
            dropped += 1
            continue
        url = _str(p.get("url"))
        if not _is_abs_url(url):
            dropped += 1  # url 是溯源唯一依据，缺失即丢弃
            continue
        doc = {
            "title": _str(p.get("title")),
            "url": url,
            "site": _str(p.get("site")),
            "date": _str(p.get("date")),
            "passage": _str(p.get("passage")),
        }
        if isinstance(p.get("content"), str):
            doc["content"] = p["content"]
        if p.get("pics") is not None:
            doc["pics"] = p["pics"]
        if isinstance(p.get("favicon"), str):
            doc["favicon"] = p["favicon"]
        if isinstance(p.get("score"), (int, float)):
            doc["score"] = p["score"]
        if isinstance(p.get("authority_level"), (int, float)):
            doc["authorityLevel"] = p["authority_level"]
        if p.get("vr") is not None:
            doc["vr"] = bool(p.get("vr"))
        if p.get("deeplinks") is not None:
            doc["deeplinks"] = p["deeplinks"]
        docs.append(doc)
    if dropped:
        warn("丢弃 %d 条无效结果（缺 url 或解析失败）" % dropped, warns)
    return {"docs": docs, "version": _str(r.get("Version")), "requestId": _str(r.get("RequestId")), "dropped": dropped}


def extract_api_error(body):
    if not isinstance(body, dict):
        return ""
    r = body.get("Response", body)
    if isinstance(r, dict) and r.get("Error"):
        err = r["Error"]
        if isinstance(err, dict):
            return _str(err.get("Code"))
        return _str(err)
    return ""


def normalize_scores(docs):
    """批次内 min-max 归一化；vr 且无 score 的条目不参与（返回 None）"""
    nums = [d["score"] for d in docs if isinstance(d.get("score"), (int, float))]
    if not nums:
        return [None] * len(docs)
    mx, mn = max(nums), min(nums)
    out = []
    for d in docs:
        v = d.get("score")
        if not isinstance(v, (int, float)):
            out.append(None)
        elif mx == mn:
            out.append(0.5)
        else:
            out.append(round((v - mn) / (mx - mn), 4))
    return out


def judge_authority(doc):
    v = doc.get("authorityLevel")
    if not isinstance(v, (int, float)):
        return "不可用", "本次服务档位未提供"
    if v >= 4:
        return "高", "%s(高)" % v
    if v == 3:
        return "中", "%s(中)" % v
    return "低", "%s(低)" % v


def judge_source(doc):
    hay = ("%s %s" % (doc.get("site", ""), doc.get("url", ""))).lower()
    for h in GOV_HINTS:
        if h in hay:
            return "最高", "%s（政府信源）" % (doc.get("site") or doc.get("url"))
    for h in PORTAL_HINTS:
        if h in hay:
            return "中间", "%s（门户/机构）" % (doc.get("site") or doc.get("url"))
    return "最低", ("%s（未知站点）" % doc["site"]) if doc.get("site") else "site 为空（未知站点）"


def judge_freshness(doc, days):
    d = doc.get("date", "")
    if not d:
        return "未知", "无发布时间"
    t = _parse_date(d)
    if t is None:
        return "未知", "日期无法解析(%s)" % d
    window = days if days > 0 else 365  # 未指定时效窗时按 1 年兜底
    diff = (time.time() - t) / 86400.0
    if diff < 0:
        return "现行有效", "%s（晚于当前时间，按有效计）" % d
    if diff <= window:
        return "现行有效", "%s 在 %d 天时效窗内" % (d, window)
    return "已过期", "%s 超出 %d 天时效窗" % (d, window)


def _parse_date(s):
    for fmt in ("%Y-%m-%d", "%Y/%m/%d %H:%M:%S", "%Y/%m/%d", "%Y-%m-%d %H:%M:%S", "%Y年%m月%d日"):
        try:
            return time.mktime(datetime.strptime(s, fmt).timetuple())
        except Exception:
            continue
    try:
        return time.mktime(datetime.strptime(s[:10], "%Y-%m-%d").timetuple())
    except Exception:
        return None


def downgrade(level):
    return {"高": "中", "中": "低", "低": "低"}[level]


def judge_status(source_tier, freshness, kb_hit):
    """
    结论状态判定（2026-10-25 修订为「可核验出处」门禁）
    置「待核实」的三条硬门禁：信源不可核验 / 已过期 / 原文库不可用且非政府信源
    """
    if source_tier == "最低":
        return "待核实", "信源不可核验（未知站点/自媒体）"
    if freshness == "已过期":
        return "待核实", "已超出时效窗（过期政策不作申报依据）"
    if kb_hit == "库不可用" and source_tier != "最高":
        return "待核实", "原文库不可用且非政府信源"
    return "可采信", "具备可核验出处"


def synthesize(doc, freshness_days, kb_hit, hit):
    a_val, a_note = judge_authority(doc)
    s_val, s_note = judge_source(doc)
    f_val, f_note = judge_freshness(doc, freshness_days)

    level = {"最高": "高", "中间": "中", "最低": "低"}[s_val]
    if f_val in ("已过期", "未知"):
        level = downgrade(level)
    if a_val in ("低", "不可用"):
        level = downgrade(level)

    status, gate = judge_status(s_val, f_val, kb_hit)

    if kb_hit == "已命中":
        extra = "正文引用" if hit.get("evidence") == "fulltext" else "标题相似度=%.2f" % hit.get("score", 0)
        kb_note = "已命中(policy_no=%s, %s)" % (hit.get("policyNo", ""), extra)
    elif kb_hit == "未命中":
        kb_note = "未命中（未在本地政策原文库备案，需人工复核）"
    else:
        kb_note = "库不可用"

    reason = "权威度=%s；信源=%s(%s)；时效=%s(%s)；原文库=%s → 结论状态：%s（门禁：%s）%s" % (
        a_note, s_val, s_note, f_val, f_note, kb_note, status, gate,
        "，已排除出正式报告" if status == "待核实" else "",
    )

    return {
        "authority": a_val,
        "sourceTier": s_val,
        "freshness": f_val,
        "kbHit": kb_hit,
        "policyNo": hit.get("policyNo", "") if kb_hit == "已命中" else "",
        "policyFile": hit.get("file", "") if kb_hit == "已命中" else "",
        "status": status,
        "level": level,
        "reason": reason,
    }


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--query", default="")
    ap.add_argument("--industry", default="gov")
    ap.add_argument("--freshness", default="")
    ap.add_argument("--site", default="")
    ap.add_argument("--exclude", default="")
    ap.add_argument("--cnt", default="50")
    ap.add_argument("--env-file", dest="env_file", default="")
    ap.add_argument("--kb", dest="kb_path", default="")
    ap.add_argument("--deeplinks", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--pretty", action="store_true")
    ap.add_argument("--no-kb", dest="no_kb", action="store_true")
    args = ap.parse_args()

    warns = []
    if not args.selftest:
        if not args.query.strip():
            sys.stderr.write("[yuanbao-search] 错误：--query 为必填项\n")
            sys.exit(2)
        if len(args.query) > QUERY_MAX:
            sys.stderr.write("[yuanbao-search] 错误：--query 长度超过 %d 字符\n" % QUERY_MAX)
            sys.exit(2)

    try:
        cred = load_credential(args.env_file)
    except CredentialError as e:
        sys.stderr.write("[yuanbao-search] 错误：%s\n" % e)
        sys.exit(3)

    index = None
    if args.no_kb:
        kb = {"ok": False, "count": 0, "indexPath": "", "entries": [], "error": "调用方指定 --no-kb"}
        warn("已跳过原文库交叉验证（--no-kb）：非政府信源的结论将置「待核实」", warns)
    else:
        kb = load_kb(args.kb_path)
        if not kb["ok"]:
            warn("政策原文库不可用（%s）：非政府信源的结论将置「待核实」" % kb["error"], warns)
        else:
            index = build_index(kb)

    selftest_query = "政策 申报"
    query = selftest_query if args.selftest else args.query.strip()
    if args.selftest:
        payload, freshness_days = {"Query": selftest_query, "Cnt": 10}, 0
    else:
        payload, freshness_days = build_payload(args, warns)

    signed = build_signed_request(payload, cred)
    t0 = int(time.time() * 1000)

    raw = None
    api_error = ""
    degraded = False
    transports = []

    for attempt in range(MAX_RETRY + 1):
        resp = request_once(signed["url"], signed["body"], signed["headers"], warns, transports)
        if resp["error"] is None and resp["status"] is not None:
            code = extract_api_error(resp["body"])
            if not code:
                raw = resp
                break
            kind, msg = classify_error(code)
            api_error = code
            if kind in ("auth", "notopen"):
                warn("API %s：%s（不重试）" % (code, msg), warns)
                degraded = True
                break
            if kind == "struct":
                warn("API %s：%s，按空结果处理" % (code, msg), warns)
                degraded = True
                break
            if attempt < MAX_RETRY:
                wait = 0.3 * (3 ** attempt)
                warn("API %s：%s，%dms 后重试（第 %d 次）" % (code, msg, int(wait * 1000), attempt + 1), warns)
                time.sleep(wait)
                continue
            warn("API %s：%s，重试 %d 次仍失败，降级" % (code, msg, MAX_RETRY), warns)
            degraded = True
            break
        if attempt < MAX_RETRY:
            wait = 0.3 * (3 ** attempt)
            warn("请求失败（%s），%dms 后重试（第 %d 次）" % (resp["error"], int(wait * 1000), attempt + 1), warns)
            time.sleep(wait)
            continue
        warn("请求失败（%s），重试 %d 次仍失败，降级为空结果" % (resp["error"], MAX_RETRY), warns)
        degraded = True

    elapsed = int(time.time() * 1000) - t0

    if raw is None:
        print(json.dumps({
            "ok": False, "requestId": "", "version": "", "elapsedMs": elapsed, "degraded": True,
            "error": ("API %s" % api_error) if api_error else "检索通道不可用",
            "warnings": warns, "items": [], "excluded": [],
        }, ensure_ascii=False))
        sys.exit(0)  # 降级不中断：空结果 + 告警，退出码仍为 0（G11）

    parsed = parse_docs(raw["body"], warns)
    norms = normalize_scores(parsed["docs"])

    items, excluded = [], []
    authority_missing = 0
    for i, d in enumerate(parsed["docs"]):
        if i and i % 100 == 0:
            sys.stderr.write("[yuanbao-search] 进度：已标注 %d/%d 条\n" % (i, len(parsed["docs"])))
        if not isinstance(d.get("authorityLevel"), (int, float)):
            authority_missing += 1
        m = match_policy(d["title"], d.get("passage", ""), index) if index else {
            "hit": False, "policyNo": "", "file": "", "score": 0, "evidence": ""
        }
        if not args.no_kb and kb["ok"]:
            kb_hit = "已命中" if m["hit"] else "未命中"
        else:
            kb_hit = "库不可用"
        c = synthesize(d, freshness_days, kb_hit, m)
        item = {
            "title": d["title"], "url": d["url"], "site": d["site"], "date": d["date"],
            "passage": d["passage"], "credibility": c,
        }
        if norms[i] is not None:
            item["scoreNorm"] = norms[i]
        if isinstance(d.get("authorityLevel"), (int, float)):
            item["authorityLevel"] = d["authorityLevel"]
        if "vr" in d:
            item["vr"] = d["vr"]
        if c["policyNo"]:
            item["policyNo"] = c["policyNo"]
        if c["policyFile"]:
            item["policyFile"] = c["policyFile"]
        if c["status"] == "可采信":
            items.append(item)
        else:
            excluded.append(dict(item, reason=c["reason"]))

    items.sort(key=lambda x: x.get("scoreNorm", -1), reverse=True)

    if parsed["version"] == "standard":
        warn("本次服务档位为 standard（旗舰版能力可能缺失），已记录降级事件", warns)
    if parsed["docs"] and authority_missing == len(parsed["docs"]):
        warn("authority_level 整批缺失（%d/%d），已按「不可用」降级判定" % (authority_missing, len(parsed["docs"])), warns)

    out = {
        "ok": True,
        "requestId": parsed["requestId"],
        "version": parsed["version"],
        "elapsedMs": elapsed,
        "degraded": degraded,
        "query": query,
        "transport": transports[-1] if transports else "",
        "kb": {"ok": kb["ok"], "count": kb["count"], "path": kb["indexPath"]},
        "stats": {
            "returned": len(parsed["docs"]),
            "credible": len(items),
            "excluded": len(excluded),
            "authorityMissing": authority_missing,
        },
        "warnings": warns,
        "items": items,
        "excluded": excluded,
    }

    if args.selftest:
        sys.stderr.write("\n".join([
            "── 自检结果 ──",
            "HTTP 状态：%s" % raw["status"],
            "服务档位：%s" % (parsed["version"] or "(空)"),
            "返回条数：%d" % len(parsed["docs"]),
            "耗时：%d ms" % elapsed,
            "传输通道：%s" % out["transport"],
            "authority_level：%d/%d 条可用" % (len(parsed["docs"]) - authority_missing, len(parsed["docs"])),
            "score：%d/%d 条可用" % (sum(1 for d in parsed["docs"] if isinstance(d.get("score"), (int, float))), len(parsed["docs"])),
            "deeplinks：%d/%d 条可用" % (sum(1 for d in parsed["docs"] if d.get("deeplinks") is not None), len(parsed["docs"])),
            "政策原文库：%s" % (("可用（%d 条）" % kb["count"]) if kb["ok"] else "不可用（%s）" % kb["error"]),
        ]) + "\n")

    if args.pretty:
        print(json.dumps(out, ensure_ascii=False, indent=2))
    else:
        print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        # 兜底：任何未预期异常也必须输出单行 JSON，禁止抛栈中断调用方（G11）
        sys.stderr.write("[yuanbao-search] 未预期错误：%s\n" % e)
        print(json.dumps({"ok": False, "degraded": True, "error": str(e), "items": [], "excluded": []}, ensure_ascii=False))
        sys.exit(1)
