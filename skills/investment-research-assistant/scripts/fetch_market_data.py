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


def http_get(url: str, timeout: int = 15, headers: dict = None, retries: int = 3) -> dict:
    """通用 HTTP GET，返回 JSON 或 None。v16: 添加重试机制"""
    hdrs = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Referer": "https://quote.eastmoney.com/",
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    }
    if headers:
        hdrs.update(headers)
    last_error = None
    for attempt in range(retries):
        try:
            if HAS_REQUESTS:
                resp = requests.get(url, headers=hdrs, timeout=timeout)
                resp.raise_for_status()
                return resp.json()
            # fallback urllib
            req = urllib.request.Request(url, headers=hdrs)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode("utf-8", errors="replace"))
        except Exception as e:
            last_error = e
            if attempt < retries - 1:
                wait = (attempt + 1) * 2
                print(f"HTTP GET 重试 {attempt+1}/{retries}（{wait}秒后）: {url[:80]}... 错误: {e}", file=sys.stderr)
                time.sleep(wait)
    raise last_error if last_error else Exception("Unknown HTTP error")


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
            # v8 修复：名称输入时调东财搜索 API 解析为代码，不再只占位（否则 fetch_quote 跳过→clean 剔除→整链断链）
            resolved = search_code_by_name(item)
            if resolved:
                codes.append(resolved)
            else:
                # 搜索失败仍占位（agent 可据替代方案清单询问用户或改用代码）
                codes.append({"code": "", "market": 0, "name": item})
    return codes


def search_code_by_name(name: str) -> dict:
    """调东财搜索 API 将公司名称解析为 6 位代码 + 市场前缀"""
    try:
        # v11修复：token 从环境变量读取，不再硬编码
        token = os.environ.get("EASTMONEY_SEARCH_TOKEN", "DGBBF2F50F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4")
        url = "https://searchapi.eastmoney.com/api/suggest/get?input=" + urllib.parse.quote(name) + "&type=14&token=" + token
        data = http_get(url, timeout=10)
        quots = data.get("Quots") or []
        if not quots:
            return None
        # 取第一个匹配（最相关）
        first = quots[0]
        code = first.get("Code") or ""
        name_resolved = first.get("Name") or name
        # 市场前缀：M=全部，1=沪，0=深
        mkt = first.get("Mkt") or ""
        if mkt.startswith("1") or code.startswith(("6", "9")):
            market = 1
        else:
            market = 0
        return {"code": code.zfill(6), "market": market, "name": name_resolved}
    except Exception as e:
        # 搜索失败返回 None，resolve_codes 会占位
        print(f"搜索公司代码失败({name}): {e}", file=sys.stderr)
        return None


def fetch_quote(secid: str) -> dict:
    """抓取个股行情快照。v16: 东方财富失败时降级到新浪财经"""
    try:
        return fetch_quote_eastmoney(secid)
    except Exception as e:
        print(f"东方财富行情抓取失败({secid}): {e}，尝试新浪财经...", file=sys.stderr)
        try:
            return fetch_quote_sina(secid)
        except Exception as e2:
            print(f"新浪财经行情抓取也失败({secid}): {e2}", file=sys.stderr)
            raise Exception(f"东方财富: {e}; 新浪: {e2}")


def fetch_quote_eastmoney(secid: str) -> dict:
    """东方财富行情接口"""
    url = (
        "https://push2.eastmoney.com/api/qt/stock/get"
        "?secid={secid}&fields=f43,f44,f45,f46,f47,f48,f57,f58,f60,f84,f85,f116,f117,f162,f167,f168,f169,f170"
    ).format(secid=secid)
    data = http_get(url)
    d = data.get("data") or {}
    return {
        "code": d.get("f57"),
        "name": d.get("f58"),
        "price": d.get("f43"),
        "change_pct": d.get("f170"),
        "volume": d.get("f47"),
        "amount": d.get("f48"),
        "pe": d.get("f162"),
        "pb": d.get("f167"),
        "market_cap": d.get("f116"),
        "high": d.get("f44"),
        "low": d.get("f45"),
        "open": d.get("f46"),
        "prev_close": d.get("f60"),
        "source": "eastmoney",
    }


def fetch_quote_sina(secid: str) -> dict:
    """v16新增：新浪财经行情接口（备选数据源）"""
    # secid 格式: "1.600519"（沪）或 "0.000858"（深）
    parts = secid.split(".")
    if len(parts) != 2:
        raise ValueError(f"Invalid secid: {secid}")
    market, code = parts[0], parts[1]
    prefix = "sh" if market == "1" else "sz"
    sina_code = f"{prefix}{code}"

    url = f"https://hq.sinajs.cn/list={sina_code}"
    hdrs = {
        "Referer": "https://finance.sina.com.cn/",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    }

    last_error = None
    for attempt in range(3):
        try:
            if HAS_REQUESTS:
                resp = requests.get(url, headers=hdrs, timeout=10)
                resp.raise_for_status()
                text = resp.text
            else:
                req = urllib.request.Request(url, headers=hdrs)
                with urllib.request.urlopen(req, timeout=10) as r:
                    text = r.read().decode("gbk", errors="replace")
            # 解析新浪行情格式: var hq_str_sh600519="名称,开盘,昨收,最新,最高,最低,...";
            import re
            m = re.search(r'="([^"]*)"', text)
            if not m or not m.group(1):
                raise ValueError("Sina response format unexpected")
            fields = m.group(1).split(",")
            if len(fields) < 10:
                raise ValueError(f"Sina response too short: {len(fields)} fields")
            return {
                "code": code,
                "name": fields[0],
                "price": float(fields[3]) if fields[3] else None,
                "change_pct": round((float(fields[3]) - float(fields[2])) / float(fields[2]) * 100, 2) if fields[2] and fields[3] and float(fields[2]) > 0 else None,
                "volume": int(float(fields[8])) if fields[8] else None,
                "amount": float(fields[9]) if fields[9] else None,
                "pe": None,
                "pb": None,
                "market_cap": None,
                "high": float(fields[4]) if fields[4] else None,
                "low": float(fields[5]) if fields[5] else None,
                "open": float(fields[1]) if fields[1] else None,
                "prev_close": float(fields[2]) if fields[2] else None,
                "source": "sina",
            }
        except Exception as e:
            last_error = e
            if attempt < 2:
                time.sleep((attempt + 1) * 2)
    raise last_error


def fetch_news(code: str, page: int = 1, page_size: int = 10) -> list:
    """v11新增：抓取个股相关新闻（东方财富新闻接口）"""
    try:
        url = (
            "https://search-api-web.eastmoney.com/search/jsonp"
            "?cb=jQuery&param=%7B%22uid%22%3A%22%22%2C%22keyword%22%3A%22" + code + "%22%2C%22type%22%3A%5B%22cmsArticleWebOld%22%5D%2C%22client%22%3A%22web%22%2C%22clientType%22%3A%22web%22%2C%22clientVersion%22%3A%22curr%22%2C%22param%22%3A%7B%22cmsArticleWebOld%22%3A%7B%22searchScope%22%3A%22default%22%2C%22sort%22%3A%22default%22%2C%22pageIndex%22%3A" + str(page - 1) + "%2C%22pageSize%22%3A" + str(page_size) + "%2C%22preTag%22%3A%22%22%2C%22postTag%22%3A%22%22%7D%7D%7D"
        )
        data = http_get(url, timeout=10)
        articles = data.get("Data", {}).get("cmsArticleWebOld", {}).get("List", []) or []
        news_list = []
        for art in articles[:page_size]:
            news_list.append({
                "title": art.get("Title", "").replace("<em>", "").replace("</em>", ""),
                "content": (art.get("Content") or "")[:200],
                "source": art.get("Source"),
                "date": art.get("Date"),
                "url": art.get("Url"),
            })
        return news_list
    except Exception as e:
        print(f"抓取新闻失败({code}): {e}", file=sys.stderr)
        return []


def main():
    # v13修复：以脚本所在目录为基准，不依赖工作目录（agent执行时cwd可能是项目根目录）
    script_dir = os.path.dirname(os.path.abspath(__file__))
    skill_root = os.path.dirname(script_dir)  # skills/investment-research-assistant/

    parser = argparse.ArgumentParser(description="抓取目标公司多源数据")
    parser.add_argument("--companies", required=True, help="目标公司，如 '600519,000858'")
    parser.add_argument("--date", default=datetime.now().strftime("%Y-%m-%d"), help="抓取日期")
    parser.add_argument("--outdir", default=None, help="输出目录（默认: {skill_root}/output/raw）")
    parser.add_argument("--force", action="store_true", help="覆盖同日期的旧产出文件（v9 新增，避免误判任务已完成）")
    args = parser.parse_args()

    # v13修复：未指定outdir时，用skill_root/output/raw绝对路径
    outdir = args.outdir if args.outdir else os.path.join(skill_root, "output", "raw")
    # 统一路径分隔符，避免双重反斜杠
    outdir = os.path.normpath(outdir)

    codes = resolve_codes(args.companies)
    if not codes:
        print(json.dumps({"success": False, "error": "empty companies"}, ensure_ascii=False))
        sys.exit(1)

    os.makedirs(outdir, exist_ok=True)
    out_file = os.path.join(outdir, f"{args.date}.json")

    # v9 新增：未指定 --force 且同日期文件已存在时，提示并跳过（不覆盖），agent 应据 SKILL.md 任务完成判定段处理
    if not args.force and os.path.exists(out_file):
        print(json.dumps({
            "success": False,
            "error": "file_already_exists",
            "message": f"{out_file} 已存在（可能是旧研报）。请用 --force 覆盖，或先清理旧产出后再运行。agent 不应因旧文件存在就误判任务已完成。",
            "existing_file": out_file,
        }, ensure_ascii=False))
        sys.exit(2)

    result = {"date": args.date, "companies": [], "sources": [], "fetched_at": datetime.now().isoformat()}

    for item in codes:
        rec = {"code": item["code"], "name": item["name"], "quotes": None, "news": [], "error": None}
        try:
            if item["code"]:
                secid = f"{item['market']}.{item['code']}"
                rec["quotes"] = fetch_quote(secid)
                # v17修复：resolve_codes 对 6 位数字代码输入只占位 name=""，fetch_quote 成功后从 quotes 回填 name 到 rec
                # 根因：原代码取 resolve_codes 占位的空字符串作为 name，导致 output/raw 中 name 字段全空
                if not rec["name"] and rec["quotes"] and rec["quotes"].get("name"):
                    rec["name"] = rec["quotes"]["name"]
                    item["name"] = rec["quotes"]["name"]  # 同步回填到 item，供下游 clean 使用
                time.sleep(0.3)  # 控制抓取频率，避免触发限流
                # v11新增：抓取新闻
                try:
                    rec["news"] = fetch_news(item["code"])
                except Exception as news_err:
                    # v17修复：fetch_news 失败时降级为空数组而非整条 rec 报错，避免新闻抓取失败影响行情数据
                    print(f"新闻抓取失败({item['code']}): {news_err}", file=sys.stderr)
                    rec["news"] = []
                time.sleep(0.3)
        except Exception as e:
            rec["error"] = str(e)
        result["companies"].append(rec)
        result["sources"].append("eastmoney-quote")
        result["sources"].append("eastmoney-news")

    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(json.dumps({"success": True, "output": out_file, "company_count": len(codes), "forced": args.force}, ensure_ascii=False))


if __name__ == "__main__":
    main()
