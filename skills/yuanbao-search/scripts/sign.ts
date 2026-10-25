#!/usr/bin/env node
/**
 * sign.ts — 元宝搜索（腾讯云 wsa · SearchPro）TC3-HMAC-SHA256 签名模块
 *
 * 职责：读取云 API 凭据 → 生成签名请求头。只做签名，不做请求（请求复用 http_client.ts）。
 *
 * 运行方式（供 yuanbao_search.ts 调用，不单独使用）:
 *   import { loadCredential, buildSignedRequest } from "./sign.ts";
 *
 * 安全约束（对应 spec §4.3 第 1/2 条、design G7）：
 *   - 密钥只从 .env 读取，禁止硬编码、禁止写入任何产物 / 日志 / 异常；
 *   - 五步派生的中间值仅存在于函数栈内，不返回、不打印。
 */
import * as crypto from "node:crypto";
import * as fs from "node:fs";
import * as path from "node:path";

const __dirname = import.meta.dirname;

export const WSA_HOST = "wsa.tencentcloudapi.com";
export const WSA_SERVICE = "wsa";
export const WSA_ACTION = "SearchPro";
export const WSA_VERSION = "2025-05-08";
export const WSA_ALGORITHM = "TC3-HMAC-SHA256";
export const WSA_ENDPOINT = `https://${WSA_HOST}/`;

/** 凭据缺失：独立错误类型，便于调用方区分"配置问题"与"服务问题" */
export class CredentialError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CredentialError";
  }
}

export interface CloudCredential {
  secretId: string;
  secretKey: string;
  envPath: string;
}

export interface SignedRequest {
  url: string;
  body: string;
  headers: Record<string, string>;
  timestamp: number;
  date: string;
}

/** 默认 .env 路径：<runtime>/.env（scripts → 技能目录 → skills → runtime） */
export function defaultEnvPath(): string {
  return path.resolve(__dirname, "../../../.env");
}

/**
 * 逐行解析 .env（与既有脚本约定一致）
 * 行格式：KEY=VALUE，忽略注释行与空行，值两侧引号会被去掉。
 */
export function readEnvFile(envPath?: string): Record<string, string> {
  const target = envPath && envPath.length > 0 ? envPath : defaultEnvPath();
  const out: Record<string, string> = {};
  let text = "";
  try {
    if (!fs.existsSync(target)) return out;
    text = fs.readFileSync(target, "utf8");
  } catch {
    return out;
  }
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (!m) continue;
    out[m[1]] = m[2].trim().replace(/^["']|["']$/g, "");
  }
  return out;
}

/** 加载凭据；缺失时抛 CredentialError（错误信息不含任何密钥片段） */
export function loadCredential(envPath?: string): CloudCredential {
  const target = envPath && envPath.length > 0 ? envPath : defaultEnvPath();
  const env = readEnvFile(target);
  const secretId = env.QCLOUD_COS_SECRET_ID || "";
  const secretKey = env.QCLOUD_COS_SECRET_KEY || "";
  if (!secretId || !secretKey) {
    throw new CredentialError(
      `未配置云 API 密钥：请在 ${target} 中设置 QCLOUD_COS_SECRET_ID / QCLOUD_COS_SECRET_KEY`
    );
  }
  return { secretId, secretKey, envPath: target };
}

function sha256Hex(s: string): string {
  return crypto.createHash("sha256").update(s, "utf8").digest("hex");
}

function hmac(key: crypto.BinaryLike, s: string): Buffer {
  return crypto.createHmac("sha256", key).update(s, "utf8").digest();
}

/**
 * 构造签名请求（TC3-HMAC-SHA256 五步派生）
 *
 * 实测通过的规范请求（26 次真实调用）：
 *   canonicalHeaders = "content-type:application/json\nhost:{host}\n"
 *   signedHeaders    = "content-type;host"
 *   canonicalRequest = POST \n / \n (空 query) \n canonicalHeaders \n signedHeaders \n sha256(body)
 */
export function buildSignedRequest(
  payload: unknown,
  cred: CloudCredential,
  timestamp?: number
): SignedRequest {
  const body = JSON.stringify(payload);
  const ts = typeof timestamp === "number" ? timestamp : Math.floor(Date.now() / 1000);
  const date = new Date(ts * 1000).toISOString().slice(0, 10);

  const canonicalHeaders = `content-type:application/json\nhost:${WSA_HOST}\n`;
  const signedHeaders = "content-type;host";
  const canonicalRequest = [
    "POST",
    "/",
    "",
    canonicalHeaders,
    signedHeaders,
    sha256Hex(body),
  ].join("\n");

  const credentialScope = `${date}/${WSA_SERVICE}/tc3_request`;
  const stringToSign = [
    WSA_ALGORITHM,
    String(ts),
    credentialScope,
    sha256Hex(canonicalRequest),
  ].join("\n");

  const secretDate = hmac(Buffer.from("TC3" + cred.secretKey, "utf8"), date);
  const secretService = hmac(secretDate, WSA_SERVICE);
  const secretSigning = hmac(secretService, "tc3_request");
  const signature = crypto
    .createHmac("sha256", secretSigning)
    .update(stringToSign, "utf8")
    .digest("hex");

  const authorization =
    `${WSA_ALGORITHM} Credential=${cred.secretId}/${credentialScope}, ` +
    `SignedHeaders=${signedHeaders}, Signature=${signature}`;

  return {
    url: WSA_ENDPOINT,
    body,
    headers: {
      Authorization: authorization,
      "Content-Type": "application/json",
      Host: WSA_HOST,
      "X-TC-Action": WSA_ACTION,
      "X-TC-Version": WSA_VERSION,
      "X-TC-Timestamp": String(ts),
    },
    timestamp: ts,
    date,
  };
}
