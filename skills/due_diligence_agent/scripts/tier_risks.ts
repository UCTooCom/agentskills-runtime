#!/usr/bin/env node
/**
 * 风险分级研判（T5.3） - TypeScript 版本
 * 功能与 tier_risks.py 完全一致
 * 运行：node --experimental-strip-types scripts/tier_risks.ts [参数]
 */
import * as fs from 'node:fs';
import * as path from 'node:path';

type Dict = Record<string, any>;

const HIGH_AMOUNT_THRESHOLD = 1_000_000;
const MEDIUM_AMOUNT_THRESHOLD = 100_000;

function tierJudicialCases(cases: Dict[]): Dict[] {
  const risks: Dict[] = [];
  for (const c of cases) {
    const caseType: string = c.case_type ?? '';
    const amount: number = c.amount ?? 0;
    const date: string = c.date ?? '';
    let level: string, basis: string;

    if (['被告', '被执行人'].includes(caseType) && amount >= HIGH_AMOUNT_THRESHOLD) {
      level = '高';
      basis = `作为${caseType}且涉案金额≥${HIGH_AMOUNT_THRESHOLD}元`;
    } else if (['被告', '被执行人'].includes(caseType) && amount >= MEDIUM_AMOUNT_THRESHOLD) {
      level = '中';
      basis = `作为${caseType}且涉案金额≥${MEDIUM_AMOUNT_THRESHOLD}元`;
    } else if (['被告', '被执行人'].includes(caseType)) {
      level = '低';
      basis = `作为${caseType}且涉案金额<${MEDIUM_AMOUNT_THRESHOLD}元`;
    } else if (caseType === '原告') {
      level = '低';
      basis = '作为原告，风险较低';
    } else {
      level = '分级待定';
      basis = `案件类型'${caseType}'无明确分级规则`;
    }

    risks.push({
      risk_type: '司法案件',
      risk_level: level,
      level_basis: basis,
      risk_description: `${caseType}案件，涉案金额${amount}元，日期${date}`,
      source_tool: 'judicial-case',
      source_data: c
    });
  }
  return risks;
}

function tierAdminPenalties(penalties: Dict[]): Dict[] {
  const risks: Dict[] = [];
  for (const pen of penalties) {
    const penaltyType: string = pen.penalty_type ?? '';
    const amount: number = pen.amount ?? 0;
    const date: string = pen.date ?? '';
    let level: string, basis: string;

    if (amount >= HIGH_AMOUNT_THRESHOLD) {
      level = '高';
      basis = `行政处罚金额≥${HIGH_AMOUNT_THRESHOLD}元`;
    } else if (amount >= MEDIUM_AMOUNT_THRESHOLD) {
      level = '中';
      basis = `行政处罚金额≥${MEDIUM_AMOUNT_THRESHOLD}元`;
    } else {
      level = '低';
      basis = `行政处罚金额<${MEDIUM_AMOUNT_THRESHOLD}元`;
    }

    risks.push({
      risk_type: '行政处罚',
      risk_level: level,
      level_basis: basis,
      risk_description: `${penaltyType}，处罚金额${amount}元，日期${date}`,
      source_tool: 'administrative-penalty',
      source_data: pen
    });
  }
  return risks;
}

function tierOperationAnomalies(anomalies: Dict[]): Dict[] {
  const risks: Dict[] = [];
  for (const anom of anomalies) {
    const anomalyType: string = anom.anomaly_type ?? '经营异常';
    const date: string = anom.date ?? '';
    risks.push({
      risk_type: '经营异常',
      risk_level: '中',
      level_basis: '存在经营异常记录',
      risk_description: `${anomalyType}，日期${date}`,
      source_tool: 'operation-anomaly',
      source_data: anom
    });
  }
  return risks;
}

function tierDishonestRecords(records: Dict[]): Dict[] {
  const risks: Dict[] = [];
  for (const rec of records) {
    risks.push({
      risk_type: '失信记录',
      risk_level: '高',
      level_basis: '存在失信被执行人记录',
      risk_description: `失信记录：${rec.description ?? '无描述'}`,
      source_tool: 'dishonest-record',
      source_data: rec
    });
  }
  return risks;
}

function tierTaxAnomalies(records: Dict[]): Dict[] {
  const risks: Dict[] = [];
  for (const rec of records) {
    risks.push({
      risk_type: '税务异常',
      risk_level: '高',
      level_basis: '存在税务异常记录',
      risk_description: `税务异常：${rec.description ?? '无描述'}`,
      source_tool: 'tax-anomaly',
      source_data: rec
    });
  }
  return risks;
}

function tierRisks(riskData: Dict, enterprise: string = ''): Dict {
  const allRisks: Dict[] = [];
  allRisks.push(...tierJudicialCases(riskData.judicial_cases ?? []));
  allRisks.push(...tierAdminPenalties(riskData.admin_penalties ?? []));
  allRisks.push(...tierOperationAnomalies(riskData.operation_anomalies ?? []));
  allRisks.push(...tierDishonestRecords(riskData.dishonest_records ?? []));
  allRisks.push(...tierTaxAnomalies(riskData.tax_anomalies ?? []));

  const summary = { high: 0, medium: 0, low: 0, pending: 0 };
  for (const r of allRisks) {
    const level: string = r.risk_level;
    if (level === '高') summary.high++;
    else if (level === '中') summary.medium++;
    else if (level === '低') summary.low++;
    else summary.pending++;
  }

  return { enterprise, risks: allRisks, summary };
}

function main(): void {
  const args = process.argv.slice(2);
  let input = '', riskDataStr = '', enterprise = '', outdir = 'output/risks';
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--input' && i + 1 < args.length) input = args[++i];
    else if (args[i] === '--risk-data' && i + 1 < args.length) riskDataStr = args[++i];
    else if (args[i] === '--enterprise' && i + 1 < args.length) enterprise = args[++i];
    else if (args[i] === '--outdir' && i + 1 < args.length) outdir = args[++i];
  }

  let data: Dict;
  if (input) {
    data = JSON.parse(fs.readFileSync(input, 'utf-8'));
  } else if (riskDataStr) {
    data = JSON.parse(riskDataStr);
  } else {
    console.log(JSON.stringify({ error: '请通过 --input 或 --risk-data 提供风险数据' }));
    process.exit(1);
  }

  const result = tierRisks(data, enterprise);
  const enterpriseName = enterprise || result.enterprise || 'unknown';
  fs.mkdirSync(outdir, { recursive: true });
  const safeName = enterpriseName.replace(/\//g, '_').replace(/\\/g, '_');
  const outputPath = path.join(outdir, `${safeName}.json`);
  fs.writeFileSync(outputPath, JSON.stringify(result, null, 2), 'utf-8');

  result.output_path = outputPath;
  console.log(JSON.stringify(result, null, 2));
}

main();