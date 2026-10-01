#!/usr/bin/env node
/**
 * 股权穿透计算（T5.2） - TypeScript 版本
 * 功能与 penetrate_equity.py 完全一致
 * 运行：node --experimental-strip-types scripts/penetrate_equity.ts [参数]
 */
import * as fs from 'node:fs';
import * as path from 'node:path';

type Dict = Record<string, any>;

const DEFAULT_MAX_DEPTH = 10;

function penetrate(equityData: Dict, maxDepth: number = DEFAULT_MAX_DEPTH): Dict {
  const enterpriseName: string = equityData.enterprise_name ?? '未知企业';
  const shareholders: Dict[] = equityData.shareholders ?? [];

  const directShareholders: Dict[] = [];
  const indirectShareholders: Dict[] = [];
  const beneficialOwners: Dict[] = [];
  const cyclesDetected: Dict[] = [];
  const paths: Dict[] = [];

  const visited = new Set<string>();

  function _penetrate(nodeName: string, node: Dict, currentRatio: number,
                      currentPath: string[], depth: number): void {
    if (depth > maxDepth) return;

    if (visited.has(nodeName)) {
      cyclesDetected.push({
        node: nodeName,
        path: [...currentPath, nodeName].join(' -> ')
      });
      return;
    }

    visited.add(nodeName);

    const shType: string = node.type ?? 'unknown';
    const shRatio: number = node.ratio ?? 0.0;
    const cumulativeRatio = currentRatio * shRatio;

    const pathStr = [...currentPath, nodeName].join(' -> ');
    const entry: Dict = {
      name: nodeName,
      type: shType,
      direct_ratio: shRatio,
      cumulative_ratio: Math.round(cumulativeRatio * 1e6) / 1e6,
      depth,
      path: pathStr
    };

    if (depth === 1) {
      directShareholders.push(entry);
    } else {
      indirectShareholders.push(entry);
    }

    if (shType === 'person') {
      beneficialOwners.push({
        name: nodeName,
        cumulative_ratio: Math.round(cumulativeRatio * 1e6) / 1e6,
        path: pathStr,
        depth
      });
      paths.push({
        path: pathStr,
        cumulative_ratio: Math.round(cumulativeRatio * 1e6) / 1e6,
        ends_at_person: true
      });
    } else {
      const subShareholders: Dict[] = node.shareholders ?? [];
      if (subShareholders.length > 0) {
        for (const subSh of subShareholders) {
          const subName: string = subSh.name ?? '';
          if (subName) {
            _penetrate(subName, subSh, cumulativeRatio, [...currentPath, nodeName], depth + 1);
          }
        }
      } else {
        paths.push({
          path: pathStr,
          cumulative_ratio: Math.round(cumulativeRatio * 1e6) / 1e6,
          ends_at_person: false,
          note: '无进一步股东数据'
        });
      }
    }
  }

  for (const sh of shareholders) {
    const shName: string = sh.name ?? '';
    if (!shName) continue;
    _penetrate(shName, sh, 1.0, [enterpriseName], 1);
  }

  beneficialOwners.sort((a, b) => b.cumulative_ratio - a.cumulative_ratio);

  return {
    enterprise: enterpriseName,
    direct_shareholders: directShareholders,
    indirect_shareholders: indirectShareholders,
    beneficial_owners: beneficialOwners,
    max_depth_reached: visited.size >= maxDepth,
    cycles_detected: cyclesDetected,
    paths
  };
}

function main(): void {
  const args = process.argv.slice(2);
  let input = '', enterprise = '', equityTree = '', outdir = 'output/penetration';
  let maxDepth = DEFAULT_MAX_DEPTH;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--input' && i + 1 < args.length) input = args[++i];
    else if (args[i] === '--enterprise' && i + 1 < args.length) enterprise = args[++i];
    else if (args[i] === '--equity-tree' && i + 1 < args.length) equityTree = args[++i];
    else if (args[i] === '--max-depth' && i + 1 < args.length) { const v = args[++i]; if (!/^-?\d+$/.test(v)) { console.error(`错误: --max-depth 必须为整数: ${v}`); process.exit(2); } maxDepth = parseInt(v, 10); }
    else if (args[i] === '--outdir' && i + 1 < args.length) outdir = args[++i];
  }

  let equityData: Dict;
  if (input) {
    equityData = JSON.parse(fs.readFileSync(input, 'utf-8'));
  } else if (equityTree) {
    equityData = JSON.parse(equityTree);
  } else {
    console.log(JSON.stringify({ error: '请通过 --input 或 --equity-tree 提供股权树数据' }));
    process.exit(1);
  }

  const result = penetrate(equityData, maxDepth);

  const enterpriseName = enterprise || result.enterprise || 'unknown';
  fs.mkdirSync(outdir, { recursive: true });
  const safeName = enterpriseName.replace(/\//g, '_').replace(/\\/g, '_');
  const outputPath = path.join(outdir, `${safeName}.json`);
  fs.writeFileSync(outputPath, JSON.stringify(result, null, 2), 'utf-8');

  result.output_path = outputPath;
  console.log(JSON.stringify(result, null, 2));
}

main();