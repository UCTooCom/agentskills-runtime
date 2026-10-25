#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
sign.py — 元宝搜索（腾讯云 wsa · SearchPro）TC3-HMAC-SHA256 签名模块（Python 降级版）

功能与 sign.ts 完全一致：读取云 API 凭据 → 生成签名请求头。只做签名，不做请求。

安全约束（spec §4.3 第 1/2 条、design G7）：
  - 密钥只从 .env 读取，禁止硬编码、禁止写入任何产物 / 日志 / 异常；
  - 五步派生的中间值仅存在于函数栈内，不返回、不打印。
"""

import hashlib
import hmac
import os
import re
import time

WSA_HOST = "wsa.tencentcloudapi.com"
WSA_SERVICE = "wsa"
WSA_ACTION = "SearchPro"
WSA_VERSION = "2025-05-08"
WSA_ALGORITHM = "TC3-HMAC-SHA256"
WSA_ENDPOINT = "https://%s/" % WSA_HOST


class CredentialError(Exception):
    """凭据缺失：便于调用方区分"配置问题"与"服务问题" """


def default_env_path():
    """默认 .env 路径：<runtime>/.env（scripts → 技能目录 → skills → runtime）"""
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.abspath(os.path.join(here, "..", "..", "..", ".env"))


def read_env_file(env_path=None):
    """逐行解析 .env（与既有脚本约定一致）"""
    target = env_path if env_path else default_env_path()
    out = {}
    if not os.path.exists(target):
        return out
    try:
        with open(target, "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
    except Exception:
        return out
    pattern = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$")
    for line in text.splitlines():
        m = pattern.match(line)
        if not m:
            continue
        value = m.group(2).strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
            value = value[1:-1]
        out[m.group(1)] = value
    return out


def load_credential(env_path=None):
    """加载凭据；缺失时抛 CredentialError（错误信息不含任何密钥片段）"""
    target = env_path if env_path else default_env_path()
    env = read_env_file(target)
    secret_id = env.get("QCLOUD_COS_SECRET_ID", "")
    secret_key = env.get("QCLOUD_COS_SECRET_KEY", "")
    if not secret_id or not secret_key:
        raise CredentialError(
            "未配置云 API 密钥：请在 %s 中设置 QCLOUD_COS_SECRET_ID / QCLOUD_COS_SECRET_KEY" % target
        )
    return {"secretId": secret_id, "secretKey": secret_key, "envPath": target}


def _sha256_hex(s):
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def _hmac(key, s):
    return hmac.new(key, s.encode("utf-8"), hashlib.sha256).digest()


def build_signed_request(payload, cred, timestamp=None):
    """
    构造签名请求（TC3-HMAC-SHA256 五步派生）

    实测通过的规范请求（26 次真实调用）：
      canonicalHeaders = "content-type:application/json\\nhost:{host}\\n"
      signedHeaders    = "content-type;host"
      canonicalRequest = POST \\n / \\n (空 query) \\n canonicalHeaders \\n signedHeaders \\n sha256(body)
    """
    import json

    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    ts = int(timestamp) if timestamp else int(time.time())
    date = time.strftime("%Y-%m-%d", time.gmtime(ts))

    canonical_headers = "content-type:application/json\nhost:%s\n" % WSA_HOST
    signed_headers = "content-type;host"
    canonical_request = "\n".join(
        ["POST", "/", "", canonical_headers, signed_headers, _sha256_hex(body)]
    )

    credential_scope = "%s/%s/tc3_request" % (date, WSA_SERVICE)
    string_to_sign = "\n".join(
        [WSA_ALGORITHM, str(ts), credential_scope, _sha256_hex(canonical_request)]
    )

    secret_date = _hmac(("TC3" + cred["secretKey"]).encode("utf-8"), date)
    secret_service = _hmac(secret_date, WSA_SERVICE)
    secret_signing = _hmac(secret_service, "tc3_request")
    signature = hmac.new(secret_signing, string_to_sign.encode("utf-8"), hashlib.sha256).hexdigest()

    authorization = "%s Credential=%s/%s, SignedHeaders=%s, Signature=%s" % (
        WSA_ALGORITHM,
        cred["secretId"],
        credential_scope,
        signed_headers,
        signature,
    )

    return {
        "url": WSA_ENDPOINT,
        "body": body,
        "headers": {
            "Authorization": authorization,
            "Content-Type": "application/json",
            "Host": WSA_HOST,
            "X-TC-Action": WSA_ACTION,
            "X-TC-Version": WSA_VERSION,
            "X-TC-Timestamp": str(ts),
        },
        "timestamp": ts,
        "date": date,
    }
