"""ユーザーの好みの説明文を作る。LLM_PROVIDER に応じて LLM を切り替える。"""
import json
import re
from collections import Counter
import requests
from datetime import datetime, timezone
from backend import config
from backend.db import get_conn

_PROMPT_TEMPLATE = """\
あなたはファッションスタイリストです。以下は、あるユーザーが LIKE した服の集計です。
このユーザーのファッションの好みを、自然で親しみやすい日本語で80〜120字で説明してください。

【よく LIKE するタグ（多い順）】：{top_tags}
【よく選ぶ価格帯】：{price_range}
【よく LIKE するショップ】：{top_shops}
【最近 LIKE した商品】：{liked_items_summary}
{user_line}
※出力は説明文のみ。箇条書きは使わない。タグ・ショップ・アイテムの傾向を1〜2個具体的に入れること。\
"""

_LIKE_THRESHOLD = 10

# 価格帯タグ（低 / 中 / 高）を、LLM に渡すときの言い方に直す
_PRICE_LABELS = {"低": "3,000円未満", "中": "3,000〜10,000円", "高": "10,000円超"}


def _short_name(name: str, limit: int = 30) -> str:
    """商品名から【送料無料】などの括弧書きを外し、長すぎる部分を切る。"""
    name = re.sub(r"【[^】]*】|［[^］]*］|\[[^\]]*\]", "", name or "").strip()
    return name[:limit]


def _user_line(user) -> str:
    """分かっている属性だけを並べる（端末ログインのユーザーは属性が空なので、その行ごと省く）。"""
    if not user:
        return ""
    parts = []
    if user["age"]:
        parts.append(f"{user['age'] // 10 * 10}代")
    if user["gender"]:
        parts.append(user["gender"])
    if user["region"]:
        parts.append(f"{user['region']}在住")
    return f"【ユーザー属性】：{' '.join(parts)}" if parts else ""


def _get_user_context(user_id: int) -> dict:
    with get_conn() as conn:
        user = conn.execute(
            "SELECT age, gender, region FROM users WHERE user_id=?", (user_id,)
        ).fetchone()

        # 商品ごとに1行（タグと JOIN するとショップがタグの数だけ数えられてしまうため、分けて取る）
        liked = conn.execute(
            """
            SELECT i.item_name, i.shop_name
            FROM user_actions ua
            JOIN items i ON i.item_code = ua.item_code
            WHERE ua.user_id=? AND ua.action='LIKE'
            ORDER BY ua.created_at DESC, ua.action_id DESC
            """,
            (user_id,),
        ).fetchall()

        tag_rows = conn.execute(
            """
            SELECT it.tag_category, it.tag_value, COUNT(*) AS cnt
            FROM user_actions ua
            JOIN item_tags it ON it.item_code = ua.item_code
            WHERE ua.user_id=? AND ua.action='LIKE'
            GROUP BY it.tag_category, it.tag_value
            ORDER BY cnt DESC, it.tag_value
            """,
            (user_id,),
        ).fetchall()

    top_tags = [r["tag_value"] for r in tag_rows if r["tag_category"] != "price_range"][:3]
    price = next((r["tag_value"] for r in tag_rows if r["tag_category"] == "price_range"), None)
    shops = Counter(r["shop_name"] for r in liked if r["shop_name"])
    names = [_short_name(r["item_name"]) for r in liked[:5]]

    return {
        "top_tags":            "、".join(top_tags) or "まだ特徴なし",
        "price_range":         _PRICE_LABELS.get(price, "不明"),
        "top_shops":           "、".join(shop for shop, _ in shops.most_common(3)) or "なし",
        "liked_items_summary": "、".join(n for n in names if n) or "なし",
        "user_line":           _user_line(user),
        "like_count":          len(liked),
    }


def _call_ollama(prompt: str) -> str:
    url = f"{config.OLLAMA_BASE_URL}/v1/chat/completions"
    payload = {
        "model": config.OLLAMA_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.7,
        "max_tokens": 300,
    }
    resp = requests.post(url, json=payload, timeout=60)
    resp.raise_for_status()
    return resp.json()["choices"][0]["message"]["content"].strip()


def _call_gemini(prompt: str) -> str:
    import urllib.request
    url = (
        f"https://generativelanguage.googleapis.com/v1beta/models/"
        f"{config.GEMINI_MODEL}:generateContent?key={config.GOOGLE_API_KEY}"
    )
    body = json.dumps({"contents": [{"parts": [{"text": prompt}]}]}).encode()
    req  = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.loads(r.read())
    return data["candidates"][0]["content"]["parts"][0]["text"].strip()


def _call_mock(_prompt: str) -> str:
    return "あなたはシンプルなモノトーンコーデが好きで、オーバーサイズなシルエットを好む傾向があります。韓国ストリート系のアイテムに反応が高く、着回しやすいプチプラアイテムを中心にご提案します。"


def _generate(prompt: str) -> str:
    if config.LLM_PROVIDER == "gemini":
        return _call_gemini(prompt)
    if config.LLM_PROVIDER == "mock":
        return _call_mock(prompt)
    return _call_ollama(prompt)


def maybe_update_taste(user_id: int) -> str | None:
    """LIKE数が閾値の倍数になった時だけ更新し、説明文を返す。それ以外はNoneを返す。"""
    ctx = _get_user_context(user_id)
    like_count = ctx["like_count"]

    with get_conn() as conn:
        cached = conn.execute(
            "SELECT description, like_count_at_gen FROM taste_descriptions WHERE user_id=?",
            (user_id,),
        ).fetchone()

    if like_count < _LIKE_THRESHOLD:
        return cached["description"] if cached else None

    if cached and (like_count - cached["like_count_at_gen"]) < _LIKE_THRESHOLD:
        return cached["description"]

    prompt = _PROMPT_TEMPLATE.format(**ctx)
    description = _generate(prompt)

    now = datetime.now(timezone.utc).isoformat()
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO taste_descriptions (user_id, description, updated_at, like_count_at_gen)
            VALUES (?,?,?,?)
            ON CONFLICT(user_id) DO UPDATE SET
              description=excluded.description,
              updated_at=excluded.updated_at,
              like_count_at_gen=excluded.like_count_at_gen
            """,
            (user_id, description, now, like_count),
        )

    return description


def get_taste(user_id: int) -> dict:
    with get_conn() as conn:
        row = conn.execute(
            "SELECT description, updated_at FROM taste_descriptions WHERE user_id=?",
            (user_id,),
        ).fetchone()
    if row:
        return {"description": row["description"], "updated_at": row["updated_at"]}
    return {"description": None, "updated_at": None}
