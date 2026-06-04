#!/usr/bin/env python3
"""Gemini API レート制限テストスクリプト。
使い方: python scripts/test_gemini_rate.py [--model MODEL] [--n N] [--interval SEC]
"""
import argparse
import json
import os
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv
load_dotenv()

API_KEY = os.getenv("GOOGLE_API_KEY", "")
BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"

SIMPLE_PROMPT = "「好き」という言葉を使って10字以内の短い文を1つだけ答えてください。"


def call_once(model: str) -> tuple[bool, dict]:
    url = f"{BASE_URL}/{model}:generateContent?key={API_KEY}"
    body = json.dumps({"contents": [{"parts": [{"text": SIMPLE_PROMPT}]}]}).encode()
    req  = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            data   = json.loads(r.read())
            text   = data["candidates"][0]["content"]["parts"][0]["text"].strip()
            limits = dict(r.headers)
            return True, {"text": text, "headers": limits}
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        return False, {"status": e.code, "reason": e.reason, "body": body}
    except Exception as e:
        return False, {"error": str(e)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model",    default="gemini-2.5-flash-preview-05-20")
    parser.add_argument("--n",        type=int, default=15, help="呼び出し回数")
    parser.add_argument("--interval", type=float, default=0.5, help="呼び出し間隔(秒)")
    args = parser.parse_args()

    if not API_KEY:
        print("ERROR: GOOGLE_API_KEY が未設定やよ。.env を確認してね。")
        sys.exit(1)

    print(f"モデル  : {args.model}")
    print(f"回数    : {args.n}")
    print(f"間隔    : {args.interval}秒")
    print(f"開始時刻: {datetime.now().strftime('%H:%M:%S')}")
    print("=" * 60)

    success = 0
    rate_limited_at = None

    for i in range(1, args.n + 1):
        ok, result = call_once(args.model)
        ts = datetime.now().strftime("%H:%M:%S")

        if ok:
            success += 1
            # レート制限ヘッダーがあれば表示
            hdrs = result.get("headers", {})
            rpm_limit = hdrs.get("x-ratelimit-limit-requests") or hdrs.get("X-RateLimit-Limit-Requests", "?")
            rpm_remain = hdrs.get("x-ratelimit-remaining-requests") or hdrs.get("X-RateLimit-Remaining-Requests", "?")
            print(f"[{i:02d}] {ts} OK   応答:{result['text'][:20]}  残RPM:{rpm_remain}/{rpm_limit}")
        else:
            status = result.get("status", "?")
            if status == 429:
                rate_limited_at = i
                print(f"[{i:02d}] {ts} 429  レート制限に達したね！ {result.get('body','')[:80]}")
            else:
                print(f"[{i:02d}] {ts} ERR  status={status} {result.get('body','')[:80]}")

        if i < args.n:
            time.sleep(args.interval)

    print("=" * 60)
    print(f"完了: 成功 {success}/{args.n} 回")
    if rate_limited_at:
        print(f"→ {rate_limited_at}回目で 429 (レート制限) が発生したよ")
    else:
        print(f"→ {args.n}回すべて成功。レート制限には達せへんかったわ")
    print()
    print("【無料枠の公式制限】")
    print("  gemini-2.5-flash : RPM=10, TPD=250K, RPD=500")
    print("  gemini-2.0-flash : RPM=15, TPD=1M,   RPD=1500")
    print("  gemini-1.5-flash : RPM=15, TPD=1M,   RPD=1500")
    print()
    print("【本アプリの消費ペース】")
    print("  味覚説明: LIKEが10件ごとに1回 → 1ユーザー1日最大数回")
    print("  → 500 RPD でも十分なPoC規模やね")


if __name__ == "__main__":
    main()
