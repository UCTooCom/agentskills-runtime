#!/usr/bin/env python3
"""
股权穿透计算（T5.2）

功能：
  - 沿股权关系逐层穿透，输出直接/间接股东、持股比例与路径
  - 识别最终受益人（beneficial owners）
  - 防循环（命中已访问节点终止）
  - 层级上限约束（--max-depth）

用法：
  python penetrate_equity.py --input equity_data.json --max-depth 10
  python penetrate_equity.py --enterprise "腾讯科技" --equity-tree-file tree.json

输入 equity_data.json 格式（dd-fetch 返回的股权树原始 JSON）：
  {
    "enterprise_name": "腾讯科技",
    "shareholders": [
      {"name": "马化腾", "ratio": 0.55, "type": "person"},
      {"name": "某投资公司", "ratio": 0.30, "type": "company"},
      ...
    ]
  }
  或多层级：
  {
    "enterprise_name": "腾讯科技",
    "shareholders": [
      {"name": "马化腾", "ratio": 0.55, "type": "person"},
      {"name": "某投资公司", "ratio": 0.30, "type": "company",
       "shareholders": [{"name": "张三", "ratio": 0.80, "type": "person"}, ...]}
    ]
  }

输出 output/penetration/{name}.json：
  {
    "enterprise": "腾讯科技",
    "direct_shareholders": [...],
    "indirect_shareholders": [...],
    "beneficial_owners": [...],
    "max_depth_reached": false,
    "cycles_detected": [],
    "paths": [...]
  }
"""
import argparse
import json
import os
import sys
from typing import Dict, List, Any, Optional, Set


DEFAULT_MAX_DEPTH = 10


def penetrate(equity_data: Dict[str, Any], max_depth: int = DEFAULT_MAX_DEPTH) -> Dict[str, Any]:
    enterprise_name = equity_data.get("enterprise_name", "未知企业")
    shareholders = equity_data.get("shareholders", [])

    direct_shareholders = []
    indirect_shareholders = []
    beneficial_owners = []
    cycles_detected = []
    paths = []

    visited: Set[str] = set()

    def _penetrate(node_name: str, node: Dict[str, Any], current_ratio: float,
                   current_path: List[str], depth: int):
        if depth > max_depth:
            return

        if node_name in visited:
            cycles_detected.append({
                "node": node_name,
                "path": " -> ".join(current_path + [node_name])
            })
            return

        visited.add(node_name)

        sh_type = node.get("type", "unknown")
        sh_ratio = node.get("ratio", 0.0)
        cumulative_ratio = current_ratio * sh_ratio

        path_str = " -> ".join(current_path + [node_name])
        entry = {
            "name": node_name,
            "type": sh_type,
            "direct_ratio": sh_ratio,
            "cumulative_ratio": round(cumulative_ratio, 6),
            "depth": depth,
            "path": path_str
        }

        if depth == 1:
            direct_shareholders.append(entry)
        else:
            indirect_shareholders.append(entry)

        if sh_type == "person":
            beneficial_owners.append({
                "name": node_name,
                "cumulative_ratio": round(cumulative_ratio, 6),
                "path": path_str,
                "depth": depth
            })
            paths.append({
                "path": path_str,
                "cumulative_ratio": round(cumulative_ratio, 6),
                "ends_at_person": True
            })
        else:
            sub_shareholders = node.get("shareholders", [])
            if sub_shareholders:
                for sub_sh in sub_shareholders:
                    sub_name = sub_sh.get("name", "")
                    if sub_name:
                        _penetrate(sub_name, sub_sh, cumulative_ratio,
                                   current_path + [node_name], depth + 1)
            else:
                paths.append({
                    "path": path_str,
                    "cumulative_ratio": round(cumulative_ratio, 6),
                    "ends_at_person": False,
                    "note": "无进一步股东数据"
                })

    for sh in shareholders:
        sh_name = sh.get("name", "")
        if not sh_name:
            continue
        _penetrate(sh_name, sh, 1.0, [enterprise_name], 1)

    beneficial_owners.sort(key=lambda x: x["cumulative_ratio"], reverse=True)

    return {
        "enterprise": enterprise_name,
        "direct_shareholders": direct_shareholders,
        "indirect_shareholders": indirect_shareholders,
        "beneficial_owners": beneficial_owners,
        "max_depth_reached": len(visited) >= max_depth,
        "cycles_detected": cycles_detected,
        "paths": paths
    }


def main():
    parser = argparse.ArgumentParser(description="股权穿透计算")
    parser.add_argument("--input", type=str, default="", help="股权树 JSON 文件路径")
    parser.add_argument("--enterprise", type=str, default="", help="企业名称（用于输出文件命名）")
    parser.add_argument("--equity-tree", type=str, default="", help="股权树 JSON 字符串（直接传入）")
    parser.add_argument("--max-depth", type=int, default=DEFAULT_MAX_DEPTH, help="穿透层级上限")
    parser.add_argument("--outdir", type=str, default="output/penetration", help="输出目录")
    args = parser.parse_args()

    if args.input:
        with open(args.input, "r", encoding="utf-8") as f:
            equity_data = json.load(f)
    elif args.equity_tree:
        equity_data = json.loads(args.equity_tree)
    else:
        print(json.dumps({"error": "请通过 --input 或 --equity-tree 提供股权树数据"},
                         ensure_ascii=False))
        sys.exit(1)

    result = penetrate(equity_data, args.max_depth)

    enterprise_name = args.enterprise or result.get("enterprise", "unknown")
    os.makedirs(args.outdir, exist_ok=True)
    safe_name = enterprise_name.replace("/", "_").replace("\\", "_")
    output_path = os.path.join(args.outdir, f"{safe_name}.json")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    result["output_path"] = output_path
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()