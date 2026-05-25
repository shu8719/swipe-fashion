"""AI-05: ユーザー嗜好説明文生成。LLM_PROVIDER に応じて切り替え。"""
import json
import requests
from datetime import datetime, timezone
from backend import config
from backend.db import get_conn

_PROMPT_TEMPLATE = """\
あなたはファッションスタイリストAIです。以下のユーザー情報をもとに、
そのユーザーのファッション嗜好を自然で親しみやすい日本語で100〜150字で説明してください。

【好きなスタイルタグ TOP3】：{top_tags}
【最近LIKEした商品】：{liked_items_summary}
【ユーザー属性】：{age}代 {gender} {region}在住

※出力は説明文のみ。箇条書き不可。\
"""

_LIKE_THRESHOLD = 10


def _get_user_context(user_id: int) -> dict:
    with get_conn() as conn:
        user = conn.execute(
            "SELECT age, gender, region FROM users WHERE user_id=?", (user_id,)
        ).fetchone()

        likes = conn.execute(
            """
            SELECT i.name, it.tag_category, it.tag_value
            FROM user_actions ua
            JOIN items i ON i.item_id = ua.item_id
            JOIN item_tags it ON it.item_id = ua.item_id
            WHERE ua.user_id=? AND ua.action='LIKE'
            ORDER BY ua.created_at DESC
            """,
            (user_id,),
        ).fetchall()

        like_count = conn.execute(
            "SELECT COUNT(*) AS cnt FROM user_actions WHERE user_id=? AND action='LIKE'",
            (user_id,),
        ).fetchone()["cnt"]

    tag_freq: dict[str, int] = {}
    liked_names: list[str] = []
    for row in likes:
        key = f"{row['tag_category']}:{row['tag_value']}"
        tag_freq[key] = tag_freq.get(key, 0) + 1
        if row["tag_category"] == "style" and row["tag_value"] not in liked_names:
            liked_names.append(row["tag_value"])

    top_tags = sorted(tag_freq, key=lambda k: tag_freq[k], reverse=True)[:3]

    return {
        "top_tags": "、".join(top_tags) or "まだデータなし",
        "liked_items_summary": "、".join(liked_names[:5]) or "なし",
        "age": str(user["age"] // 10 * 10) if user and user["age"] else "不明",
        "gender": (user["gender"] or "不明") if user else "不明",
        "region": (user["region"] or "不明") if user else "不明",
        "like_count": like_count,
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
        f"gemini-1.5-flash:generateContent?key={config.GOOGLE_API_KEY}"
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
