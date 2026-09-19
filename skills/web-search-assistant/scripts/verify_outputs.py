#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verify report artifacts exist and are non-empty (ASCII-safe output only)."""

import os
import sys

BASE = os.path.dirname(os.path.abspath(__file__))
TARGETS = [
    os.path.join(BASE, "..", "output", "reports", "global-ai-market-2021-2025.html"),
    os.path.join(BASE, "..", "output", "data", "ai_market_5y_normalized.json"),
    os.path.join(BASE, "..", "output", "raw", "ai_market_raw_5y.json"),
    os.path.join(BASE, "..", "output", "raw", "ai_market_extra.json"),
]

ok = True
for t in TARGETS:
    t = os.path.abspath(t)
    if os.path.isfile(t) and os.path.getsize(t) > 0:
        print("[PASS] %d bytes  %s" % (os.path.getsize(t), os.path.basename(t)))
    else:
        print("[FAIL] missing or empty: %s" % t)
        ok = False

print("[RESULT] %s" % ("ALL_ARTIFACTS_OK" if ok else "ARTIFACTS_MISSING"))
sys.exit(0 if ok else 1)
