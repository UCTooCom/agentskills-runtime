#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智能投研助理 - Step 1: 自动抓取（Fetch Market Data）
自动抓取目标公司的行情、公告、新闻等多源数据，输出原始 JSON。

用法:
    python3 fetch_market_data.py --companies "600519,000858" [--date 2026-08-07] [--outdir output/raw]

数据源（均为公开/合规接口，可按需增删）:
    - 行情: 东方财富公开行情接口 (push2.eastmoney.com)
    - 新闻: 财经门户公开 RSS/接口（示例占位，可按需配置）
"""

import argparse
import json
import os
import sys
import time
import urllib.request
import urllib.parse
from datetime import datetime

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False


def http_get(url: str, timeout: int = 15, headers: dict = None) -> dict:
    """通用 HTTP GET，返回 JSON 或 None"""
    hdrs = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) InvestmentResearchAssistant/1.0",
        "Referer": "https://quote.eastmoney.com/",
    }
    if headers:
        hdrs.update(headers)
    if HAS_REQUESTS:
        resp = requests.get(url, headers=hdrs, timeout=timeout)
        resp.raise_for_status()
        return resp.json()
    # fallback urllib
    req = urllib.request.Request(url, headers=hdrs)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8", errors="replace"))


def resolve_codes(companies: str) -> list:
    """将输入解析为代码列表。支持 '600519'、'600519,000858' 或 '贵州茅台,五粮液'"""
    codes = []
    for item in companies.replace("，", ",").split(","):
        item = item.strip()
        if not item:
            continue
        if item.isdigit():
            # 统一补 6 位代码
            code = item.zfill(6)
            market = 1 if code.startswith(("6", "9")) else 0  # 1=沪 0=深
            codes.append({"code": code, "market": market, "name": ""})
        else:
            # 名称占位，由后续脚本/模型解析
            codes.append({"code": "", "market": 0, "name": item})
    return codes


def fetch_quote(secid: str) -> dict:
    """抓取个股行情快照"""
    url = (
        "https://push2.eastmoney.com/api/qt/stock/get"
        "?secid={secid}&fields=f43,f44,f45,f46,f47,f48,f57,f58,f60,f84,f85,f116,f117,f162,f167,f168,f169,f170"
    ).format(secid=secid)
    data = http_get(url)
    d = data.get("data") or {}
    return {
        "code": d.get("f57"),
        "name": d.get("f58"),
        "price": d.get("f43"),          # 最新价(需/100)
        "change_pct": d.get("f170"),    # 涨跌幅%
        "volume": d.get("f47"),         # 成交量(手)
        "amount": d.get("f48"),         # 成交额
        "pe": d.get("f162"),            # 市盈率(动)
        "pb": d.get("f167"),            # 市净率
        "market_cap": d.get("f116"),    # 总市值
        "high": d.get("f44"),
        "low": d.get("f45"),
        "open": d.get("f46"),
        "prev_close": d.get("f60"),
    }


def main():
    parser = argparse.ArgumentParser(description="抓取目标公司多源数据")
    parser.add_argument("--companies", required=True, help="目标公司，如 '600519,000858'")
    parser.add_argument("--date", default=datetime.now().strftime("%Y-%m-%d"), help="抓取日期")
    parser.add_argument("--outdir", default="output/raw", help="输出目录")
    args = parser.parse_args()

    codes = resolve_codes(args.companies)
    if not codes:
        print(json.dumps({"success": False, "error": "empty companies"}, ensure_ascii=False))
        sys.exit(1)

    os.makedirs(args.outdir, exist_ok=True)
    result = {"date": args.date, "companies": [], "sources": [], "fetched_at": datetime.now().isoformat()}

    for item in codes:
        rec = {"code": item["code"], "name": item["name"], "quotes": None, "news": [], "error": None}
        try:
            if item["code"]:
                secid = f"{item['market']}.{item['code']}"
                rec["quotes"] = fetch_quote(secid)
                time.sleep(0.3)  # 控制抓取频率，避免触发限流
        except Exception as e:
            rec["error"] = str(e)
        result["companies"].append(rec)
        result["sources"].append("eastmoney-quote")

    out_file = os.path.join(args.outdir, f"{args.date}.json")
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(json.dumps({"success": True, "output": out_file, "company_count": len(codes)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
