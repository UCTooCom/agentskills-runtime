#!/usr/bin/env node
/**
 * pkggraph.ts — 仓颉包级循环依赖检测（Tarjan SCC）
 * 功能与 pkggraph.py 完全一致：解析工程中每个 .cj 的 package / import 声明，
 * 构建包级依赖图，用 Tarjan 强连通分量算法检测循环依赖（仓颉跨包反向
 * import 会直接触发 cyclic dependency 拒绝构建，故改跨包 import 后应先跑一遍）。
 *
 * 用法:
 *   node --experimental-strip-types pkggraph.ts                # 扫描 src/
 *   node --experimental-strip-types pkggraph.ts --root src     # 指定源码根
 *   node --experimental-strip-types pkggraph.ts --json         # 输出 JSON
 *
 * 输出:
 *   文本模式（默认）：
 *     === cyclic dependency (SCC size > 1) ===
 *     NONE                       # 无环
 *     # 或
 *     * magic.x <-> magic.y     # 存在循环依赖的包集合
 *     随后打印 packages=N edges=M cycles=K 汇总
 *   --json：{"cyclic": [...], "packages": N, "edges": M, "cycles": K}
 *
 * 退出码: 0 = 无环；2 = 存在循环依赖；1 = 参数/IO 错误。
 *
 * 依赖: 仅 Node.js 标准库（fs / path），Node ≥ 22.6。
 */

import * as fs from "fs";
import * as path from "path";

type Graph = Map<string, Set<string>>;

function parseArgs(): { root: string; json: boolean } {
  const argv = process.argv.slice(2);
  let root = "src";
  let json = false;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--root") root = argv[++i] ?? "src";
    else if (argv[i] === "--json") json = true;
  }
  return { root, json };
}

function walk(dir: string, cb: (file: string) => void): void {
  let entries: fs.Dirent[];
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return;
  }
  for (const e of entries) {
    // 跳过产物/依赖目录，避免误扫
    if (e.name === "target" || e.name === "node_modules" || e.name === ".git") continue;
    const full = path.join(dir, e.name);
    if (e.isDirectory()) walk(full, cb);
    else if (e.isFile()) cb(full);
  }
}

function buildGraph(root: string): { edges: Graph; pkgFiles: Map<string, string[]>; ok: boolean } {
  const edges: Graph = new Map();
  const pkgFiles = new Map<string, string[]>();

  if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) {
    return { edges, pkgFiles, ok: false };
  }

  walk(root, (p) => {
    if (!p.endsWith(".cj")) return;
    let txt: string;
    try {
      txt = fs.readFileSync(p, "utf-8");
    } catch {
      return;
    }
    const pm = /^\s*package\s+([A-Za-z_][\w.]*)/m.exec(txt);
    if (!pm) return;
    const pkg = pm[1];
    if (!pkgFiles.has(pkg)) pkgFiles.set(pkg, []);
    pkgFiles.get(pkg)!.push(p);

    const importRe = /^\s*import\s+([^\s]+)/gm;
    let im: RegExpExecArray | null;
    while ((im = importRe.exec(txt)) !== null) {
      let tgt = im[1];
      if (tgt.startsWith("std") || tgt.startsWith("ystyle") || tgt.startsWith("f_")) continue;
      if (tgt === "jsonvalue") continue;
      if (!tgt.startsWith("magic.")) continue;
      tgt = tgt.split("::")[0];
      if (tgt.includes(".{")) tgt = tgt.split(".{")[0];
      if (!edges.has(pkg)) edges.set(pkg, new Set());
      edges.get(pkg)!.add(tgt);
    }
  });

  return { edges, pkgFiles, ok: true };
}

function resolve(t: string, known: Set<string>): string | null {
  while (!known.has(t) && t.includes(".")) {
    t = t.substring(0, t.lastIndexOf("."));
  }
  return known.has(t) ? t : null;
}

function tarjanSCC(g2: Graph, nodes: string[]): string[][] {
  const index = new Map<string, number>();
  const low = new Map<string, number>();
  const onStack = new Map<string, boolean>();
  const stack: string[] = [];
  const result: string[][] = [];
  let counter = 0;

  function strongconnect(v: string): void {
    index.set(v, counter);
    low.set(v, counter);
    counter++;
    stack.push(v);
    onStack.set(v, true);
    const neighbors = g2.get(v);
    if (neighbors) {
      for (const w of neighbors) {
        if (!index.has(w)) {
          strongconnect(w);
          low.set(v, Math.min(low.get(v)!, low.get(w)!));
        } else if (onStack.get(w)) {
          low.set(v, Math.min(low.get(v)!, index.get(w)!));
        }
      }
    }
    if (low.get(v) === index.get(v)) {
      const comp: string[] = [];
      while (true) {
        const w = stack.pop()!;
        onStack.set(w, false);
        comp.push(w);
        if (w === v) break;
      }
      if (comp.length > 1) result.push(comp.slice().sort());
    }
  }

  for (const v of nodes) {
    if (!index.has(v)) strongconnect(v);
  }
  return result;
}

function main(): void {
  const { root, json } = parseArgs();
  const { edges, pkgFiles, ok } = buildGraph(root);

  if (!ok) {
    const msg = `[pkggraph] 源码根目录不存在: ${path.resolve(root)}`;
    if (json) {
      console.log(JSON.stringify({ error: msg, cyclic: [], packages: 0, edges: 0, cycles: 0 }));
    } else {
      console.error(msg);
    }
    process.exit(1);
  }

  const known = new Set(pkgFiles.keys());
  const g2: Graph = new Map();
  for (const [p, tgts] of edges) {
    for (const t of tgts) {
      const r = resolve(t, known);
      if (r && r !== p) {
        if (!g2.has(p)) g2.set(p, new Set());
        g2.get(p)!.add(r);
      }
    }
  }

  const nodes = Array.from(g2.keys()).sort();
  const cycles = tarjanSCC(g2, nodes);
  let totalEdges = 0;
  for (const v of g2.values()) totalEdges += v.size;

  if (json) {
    console.log(
      JSON.stringify({ cyclic: cycles, packages: known.size, edges: totalEdges, cycles: cycles.length })
    );
    process.exit(cycles.length > 0 ? 2 : 0);
  }

  console.log("=== cyclic dependency (SCC size > 1) ===");
  if (cycles.length === 0) console.log("NONE");
  for (const c of cycles) console.log(" * " + c.join(" <-> "));
  console.log("");
  console.log(`packages=${known.size} edges=${totalEdges} cycles=${cycles.length}`);
  process.exit(cycles.length > 0 ? 2 : 0);
}

main();
