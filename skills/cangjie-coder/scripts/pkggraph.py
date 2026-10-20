#!/usr/bin/env python3
"""仓颉包依赖循环检测脚本

解析工程中每个 .cj 文件的 `package` 与 `import` 声明，构建「包级依赖图」，
用 Tarjan 强连通分量（SCC）算法检测**循环依赖**——仓颉跨包反向 import 会直接
触发 `cyclic dependency` 拒绝构建，故在改动跨包 import（尤其是引入新的 package
边界、把工具类下沉到公共包、插件进程拆包）后，应先跑本脚本再编译。

依赖规则（与仓颉构建一致）：
- 只统计 `magic.*` 开头的 import（跨包边界）；`std* / ystyle / f_ / jsonvalue`
  等外部或同包引用一律忽略。
- import 形如 `magic.a.b::{c, d}` 取 `magic.a.b`；`magic.a.b::c` 取 `magic.a.b`；
  其余 `magic.a.b.c` 逐级向上归并到已知包（SCC 只看包粒度，不看子目录文件）。

用法:
    # 在项目根目录（含 src/）下执行，扫描 src/
    python pkggraph.py

    # 指定源码根（相对或绝对路径均可）
    python pkggraph.py --root src
    python pkggraph.py --root apps/foo/src

    # 输出 JSON（便于脚本化判断是否无环）
    python pkggraph.py --json

输出:
    默认（文本）：
      === cyclic dependency (SCC size > 1) ===
      NONE                      # 无环
      # 或
      * magic.x <-> magic.y    # 存在循环依赖的包集合
      随后打印包总数、边总数、环数量等汇总。
    --json：{"cyclic": [...], "packages": N, "edges": M, "cycles": K}

退出码:
    0 = 无循环依赖；2 = 存在循环依赖；1 = 参数/IO 错误。

依赖: 仅 Python 标准库（os/re/sys/collections/argparse），无需 pip 安装。
"""

import argparse
import json
import os
import re
import sys
from collections import defaultdict


def build_graph(root: str):
    """扫描 root 下所有 .cj，返回 (包→文件列表, 包→依赖包集合)。"""
    edges = defaultdict(set)
    pkg_files = defaultdict(list)

    if not os.path.isdir(root):
        return edges, pkg_files, False

    for dirpath, dirnames, filenames in os.walk(root):
        # 跳过产物/依赖目录
        if "target" in dirnames:
            dirnames.remove("target")
        for fn in filenames:
            if not fn.endswith(".cj"):
                continue
            p = os.path.join(dirpath, fn)
            try:
                txt = open(p, encoding="utf-8", errors="ignore").read()
            except Exception:
                continue
            m = re.search(r"^\s*package\s+([A-Za-z_][\w.]*)", txt, re.M)
            if not m:
                continue
            pkg = m.group(1)
            pkg_files[pkg].append(p)
            for im in re.finditer(r"^\s*import\s+([^\s]+)", txt, re.M):
                tgt = im.group(1)
                if tgt.startswith("std") or tgt.startswith("ystyle") or tgt.startswith("f_"):
                    continue
                if tgt == "jsonvalue":
                    continue
                if not tgt.startswith("magic."):
                    continue
                tgt = tgt.split("::")[0]
                if ".{" in tgt:
                    tgt = re.split(r"\.\{", tgt)[0]
                edges[pkg].add(tgt)

    return edges, pkg_files, True


def resolve(t, known):
    while t not in known and "." in t:
        t = t.rsplit(".", 1)[0]
    return t if t in known else None


def tarjan_scc(g2, nodes):
    """返回所有 size>1 的强连通分量（循环依赖包集合）。"""
    index = {}
    low = {}
    stack = []
    onstack = {}
    result = []
    counter = [0]
    sys.setrecursionlimit(100000)

    def strongconnect(v):
        index[v] = low[v] = counter[0]
        counter[0] += 1
        stack.append(v)
        onstack[v] = True
        for w in g2.get(v, ()):
            if w not in index:
                strongconnect(w)
                low[v] = min(low[v], low[w])
            elif onstack.get(w):
                low[v] = min(low[v], index[w])
        if low[v] == index[v]:
            comp = []
            while True:
                w = stack.pop()
                onstack[w] = False
                comp.append(w)
                if w == v:
                    break
            if len(comp) > 1:
                result.append(sorted(comp))

    for v in sorted(g2.keys()):
        if v not in index:
            strongconnect(v)
    return result


def main():
    ap = argparse.ArgumentParser(description="仓颉包级循环依赖检测（Tarjan SCC）")
    ap.add_argument("--root", default="src", help="源码根目录（默认 src，相对当前工作目录）")
    ap.add_argument("--json", action="store_true", help="输出 JSON 而非文本")
    args = ap.parse_args()

    root = args.root
    edges, pkg_files, ok = build_graph(root)
    if not ok:
        msg = f"[pkggraph] 源码根目录不存在: {os.path.abspath(root)}"
        if args.json:
            print(json.dumps({"error": msg, "cyclic": [], "packages": 0, "edges": 0, "cycles": 0},
                             ensure_ascii=False))
        else:
            print(msg, file=sys.stderr)
        return 1

    known = set(pkg_files.keys())
    g2 = defaultdict(set)
    for p, tgts in edges.items():
        for t in tgts:
            r = resolve(t, known)
            if r and r != p:
                g2[p].add(r)

    cycles = tarjan_scc(g2, sorted(g2.keys()))

    total_edges = sum(len(v) for v in g2.values())

    if args.json:
        out = {
            "cyclic": cycles,
            "packages": len(known),
            "edges": total_edges,
            "cycles": len(cycles),
        }
        print(json.dumps(out, ensure_ascii=False))
        return 2 if cycles else 0

    print("=== cyclic dependency (SCC size > 1) ===")
    if not cycles:
        print("NONE")
    for c in cycles:
        print(" * " + " <-> ".join(c))
    print("")
    print(f"packages={len(known)} edges={total_edges} cycles={len(cycles)}")
    return 2 if cycles else 0


if __name__ == "__main__":
    sys.exit(main())
