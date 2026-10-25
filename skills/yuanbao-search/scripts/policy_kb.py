#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
policy_kb.py — 政策原文库交叉验证器（design §2.5.6 / M6），Python 降级版

功能与 policy_kb.ts 完全一致：
  输入：检索条目标题 + 摘要；底座：beichen-policy-assistant 的 policy-index.json（74 条北京政策）
  输出：是否命中 + 命中的 policy_no / 原文路径

三级证据（2026-10-25 修订）：
  1. title    ：标题级 2-gram Jaccard ≥ 0.6，或包含覆盖 ≥ 80%
  2. core     ：核心名重叠系数 ≥ 0.75（长通知标题里嵌着短政策名时，Jaccard 会被分母摊薄）
  3. fulltext ：政策全名（≥8 字）出现在「标题 + 摘要」归一化文本中

强约束：索引不可解析 → ok=False → 调用方按门禁降级处理。
"""

import json
import os
import re

J_THRESHOLD = 0.6
COVER_RATIO = 0.8
FULLTEXT_MIN_LEN = 8
OVERLAP_THRESHOLD = 0.75
OVERLAP_MIN_GRAMS = 8

_PUNCT = re.compile(r"[()（）【】\[\]《》·,.，。、/\\:：;；'\"“”‘’!？?\-_—|]")


def default_kb_path():
    """默认索引路径：../beichen-policy-assistant/knowledge/policy-index.json"""
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.abspath(
        os.path.join(here, "..", "..", "beichen-policy-assistant", "knowledge", "policy-index.json")
    )


def normalize_title(s):
    """全角转半角 + 去空白 + 去标点 + 小写"""
    if not s:
        return ""
    buf = []
    for ch in str(s):
        code = ord(ch)
        if code == 0x3000:
            buf.append(" ")
            continue
        if 0xFF01 <= code <= 0xFF5E:
            buf.append(chr(code - 0xFEE0))
            continue
        buf.append(ch)
    out = "".join(buf)
    out = re.sub(r"\s+", "", out)
    out = _PUNCT.sub("", out)
    return out.lower()


def bigrams(s):
    """2-gram 字符集（按字符，中文安全）"""
    if not s:
        return set()
    if len(s) == 1:
        return {s}
    return {s[i] + s[i + 1] for i in range(len(s) - 1)}


def jaccard(a, b):
    if not a or not b:
        return 0.0
    inter = len(a & b)
    union = len(a | b)
    return (inter / union) if union else 0.0


def overlap(a, b):
    """重叠系数 |A∩B| / min(|A|,|B|)"""
    if not a or not b:
        return 0.0
    small = a if len(a) <= len(b) else b
    return len(a & b) / len(small)


def load_kb(kb_path=None):
    """加载政策索引。任何解析失败都返回 ok=False（不抛异常），由调用方降级。"""
    target = kb_path if kb_path else default_kb_path()
    empty = {"ok": False, "count": 0, "indexPath": target, "entries": [], "error": ""}
    try:
        if not os.path.exists(target):
            empty["error"] = "政策索引不存在：%s" % target
            return empty
        with open(target, "r", encoding="utf-8") as f:
            raw = json.load(f)
    except Exception as e:
        empty["error"] = "政策索引读取/解析失败：%s" % e
        return empty

    items = raw if isinstance(raw, list) else (raw.get("policies") if isinstance(raw, dict) else None)
    if not isinstance(items, list):
        empty["error"] = "政策索引结构异常：未找到 policies 数组"
        return empty
    entries = []
    for it in items:
        if not isinstance(it, dict):
            continue
        entries.append(
            {
                "policy_no": str(it.get("policy_no", "")),
                "domain": str(it.get("domain", "")),
                "level": str(it.get("level", "")),
                "department": str(it.get("department", "")),
                "title": str(it.get("title", "")),
                "status": str(it.get("status", "")),
                "file": str(it.get("file", "")),
            }
        )
    if not entries:
        empty["error"] = "政策索引为空"
        return empty
    return {"ok": True, "count": len(entries), "indexPath": target, "entries": entries, "error": ""}


def build_index(kb):
    """构建归一化索引（启动时一次，74 条规模开销可忽略）"""
    norms = []
    grams = []
    for p in kb["entries"]:
        n = normalize_title(p["title"])
        norms.append(n)
        grams.append(bigrams(n))
    return {"kb": kb, "norms": norms, "grams": grams}


def match_policy(title, passage, index):
    """交叉验证：命中 → 绑定 policy_no 与原文路径"""
    miss = {"hit": False, "policyNo": "", "policyTitle": "", "file": "", "score": 0.0, "evidence": ""}
    if not index["kb"]["ok"]:
        return miss
    n = normalize_title(title)
    if not n:
        return miss
    g = bigrams(n)

    best = 0.0
    best_at = -1
    for i, other in enumerate(index["norms"]):
        if not other:
            continue
        shorter, longer = (n, other) if len(n) <= len(other) else (other, n)
        if longer.find(shorter) >= 0 and longer and (len(shorter) / len(longer)) >= COVER_RATIO:
            hit = dict(miss)
            hit.update(
                {
                    "hit": True,
                    "policyNo": index["kb"]["entries"][i]["policy_no"],
                    "policyTitle": index["kb"]["entries"][i]["title"],
                    "file": index["kb"]["entries"][i]["file"],
                    "score": max(jaccard(g, index["grams"][i]), len(shorter) / len(longer)),
                    "evidence": "title",
                }
            )
            return hit
        j = jaccard(g, index["grams"][i])
        if j > best:
            best, best_at = j, i

    if best >= J_THRESHOLD and best_at >= 0:
        hit = dict(miss)
        hit.update(
            {
                "hit": True,
                "policyNo": index["kb"]["entries"][best_at]["policy_no"],
                "policyTitle": index["kb"]["entries"][best_at]["title"],
                "file": index["kb"]["entries"][best_at]["file"],
                "score": best,
                "evidence": "title",
            }
        )
        return hit

    best_ov, best_ov_at = 0.0, -1
    for i, other in enumerate(index["grams"]):
        if len(other) < OVERLAP_MIN_GRAMS:
            continue
        ov = overlap(g, other)
        if ov > best_ov:
            best_ov, best_ov_at = ov, i
    if best_ov >= OVERLAP_THRESHOLD and best_ov_at >= 0:
        hit = dict(miss)
        hit.update(
            {
                "hit": True,
                "policyNo": index["kb"]["entries"][best_ov_at]["policy_no"],
                "policyTitle": index["kb"]["entries"][best_ov_at]["title"],
                "file": index["kb"]["entries"][best_ov_at]["file"],
                "score": best_ov,
                "evidence": "core",
            }
        )
        return hit

    blob = normalize_title("%s %s" % (title or "", passage or ""))
    if blob:
        for i, name in enumerate(index["norms"]):
            if len(name) < FULLTEXT_MIN_LEN:
                continue
            if name in blob:
                hit = dict(miss)
                hit.update(
                    {
                        "hit": True,
                        "policyNo": index["kb"]["entries"][i]["policy_no"],
                        "policyTitle": index["kb"]["entries"][i]["title"],
                        "file": index["kb"]["entries"][i]["file"],
                        "score": 1.0,
                        "evidence": "fulltext",
                    }
                )
                return hit
    miss["score"] = best
    return miss
