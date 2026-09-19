#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Parse raw Sogou AI-market results, extract numeric data points near year mentions.
Prints ASCII-safe summary only (avoids console encoding issues)."""

import json
import os
import re

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "..", "output", "raw", "ai_market_raw_5y.json")
OUT = os.path.join(BASE, "..", "output", "data", "ai_market_datapoints.json")


def norm_domain(url):
    m = re.match(r"https?://([^/]+)", url or "")
    return m.group(1) if m else (url or "")[:40]


def main():
    with open(RAW, encoding="utf-8") as f:
        data = json.load(f)

    datapoints = []
    for q, payload in data.items():
        for r in payload.get("results", []):
            text = (r.get("title", "") + " " + r.get("snippet", ""))
            # find year mentions and nearby numbers
            for ym in re.finditer(r"(20[12][0-9])\s*年?年?", text):
                year = ym.group(1)
                window = text[max(0, ym.start() - 60): ym.end() + 60]
                nums = re.findall(r"(\d{1,3}(?:,\d{3})*(?:\.\d+)?)\s*(亿美元|亿元|%|billion|million)?", window)
                vals = []
                for n, unit in nums:
                    v = n.replace(",", "")
                    if unit:
                        vals.append(v + unit.encode("unicode_escape").decode("ascii"))
                    else:
                        vals.append(v)
                if vals:
                    datapoints.append({
                        "year": year,
                        "values": vals[:6],
                        "domain": norm_domain(r.get("url", "")),
                    })

    os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(datapoints, f, ensure_ascii=False, indent=2)

    print("[TOTAL QUERIES] %d" % len(data))
    print("[TOTAL RESULTS] %d" % sum(len(p.get("results", [])) for p in data.values()))
    print("[DATAPOINTS] %d" % len(datapoints))
    print("[SAVED] " + os.path.abspath(OUT))
    print("--- ASCII-SAFE DATAPOINT SUMMARY ---")
    for dp in datapoints:
        printable = "|".join(v for v in dp["values"] if all(ord(c) < 128 for c in v))
        if printable:
            print("year=%s vals=%s src=%s" % (dp["year"], printable, dp["domain"]))


if __name__ == "__main__":
    main()
