# -*- coding: utf-8 -*-
"""Round4b: parse saved bing html -> extract all external result links."""
import re, os, json, html as ihtml, urllib.parse

OUT = os.path.dirname(os.path.abspath(__file__))
SKIP = ("bing.com", "microsoft.com", "msn.com", "go.microsoft", "w3.org", "bing.net")

report = {}
for fn in sorted(f for f in os.listdir(OUT) if re.match(r"r4_bing_\d+\.html$", f)):
    txt = open(os.path.join(OUT, fn), encoding="utf-8", errors="replace").read()
    results = []
    seen = set()
    # b_algo blocks
    for blk in re.findall(r'<li class="b_algo".*?</li>', txt, re.S | re.I):
        a = re.search(r'<a[^>]+href="(http[^"]+)"[^>]*>(.*?)</a>', blk, re.S | re.I)
        if not a:
            continue
        url, title = ihtml.unescape(a.group(1)), re.sub(r"<[^>]+>", "", a.group(2)).strip()
        if any(s in url for s in SKIP) or url in seen:
            continue
        seen.add(url)
        snip = re.sub(r"<[^>]+>", " ", blk)
        snip = re.sub(r"\s+", " ", ihtml.unescape(snip)).strip()[:220]
        results.append({"url": url, "title": title[:120], "snippet": snip})
    if not results:
        # fallback: all outbound anchors
        for m in re.finditer(r'<a[^>]+href="(http[^"]+)"[^>]*>(.*?)</a>', txt, re.S | re.I):
            url, title = ihtml.unescape(m.group(1)), re.sub(r"<[^>]+>", "", m.group(2)).strip()
            if any(s in url for s in SKIP) or url in seen or len(title) < 3:
                continue
            seen.add(url)
            results.append({"url": url, "title": title[:120], "snippet": ""})
    report[fn] = results
    print("==", fn, "->", len(results), "links")
    for r in results[:20]:
        print("   -", r["title"][:80])
        print("     ", r["url"][:150])

json.dump(report, open(os.path.join(OUT, "r4_bing_links.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("\nWROTE r4_bing_links.json")
