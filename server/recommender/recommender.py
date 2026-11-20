"""AI-02/03: コンテンツベースフィルタリング推薦エンジン（本実装）。"""
import json
import math
import numpy as np
from datetime import datetime, timezone
from sklearn.metrics.pairwise import cosine_similarity
from backend.db import get_conn
from recommender.vectorizer import get_vector, vectorize_item, TAG_DIM, TAG_INDEX

_LIKE_WEIGHT = 1.0
_SKIP_WEIGHT = -0.5
_TIME_DECAY  = 0.95   # 1評価古くなるごとに 0.95 倍


def _build_preference_vector(user_id: int) -> np.ndarray | None:
    """AI-02: LIKE/SKIP の加重平均でユーザー好みベクトルを生成する。"""
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT item_code, action, created_at
            FROM user_actions
            WHERE user_id=?
            ORDER BY created_at ASC
            """,
            (user_id,),
        ).fetchall()

    if not rows:
        return None

    n        = len(rows)
    pref     = np.zeros(TAG_DIM, dtype=float)
    total_w  = 0.0

    for i, row in enumerate(rows):
        vec = get_vector(row["item_code"])
        if vec is None:
            vec = vectorize_item(row["item_code"])
        if vec is None:
            continue

        weight = (_LIKE_WEIGHT if row["action"] == "LIKE" else _SKIP_WEIGHT)
        decay  = _TIME_DECAY ** (n - 1 - i)   # 新しい評価ほど decay が小さい（→ 重い）
        w      = weight * decay
        pref  += w * vec
        total_w += abs(w)

    if total_w == 0:
        return None
    return pref / total_w


# おすすめの理由として返すタグの数
_MAX_REASONS = 2
# 価格帯タグ（低 / 中 / 高）は、理由としては「同じ価格帯」と出す
_PRICE_TAGS = {"低", "中", "高"}
_TAG_NAMES  = {i: tag for tag, i in TAG_INDEX.items()}


def _reasons(pref: np.ndarray, vec: np.ndarray) -> list[str]:
    """好みのベクトルを押し上げているタグのうち、この商品も持っているものを、効いている順に返す。"""
    contrib = pref * vec
    reasons: list[str] = []
    for i in np.argsort(-contrib):
        if contrib[i] <= 0 or len(reasons) >= _MAX_REASONS:
            break
        tag = _TAG_NAMES[int(i)]
        reasons.append("同じ価格帯" if tag in _PRICE_TAGS else tag)
    return reasons


def get_recommendations(user_id: int, limit: int = 20, app_only: bool = False) -> list[dict]:
    """AI-03: コサイン類似度で上位 limit 件を返す。

    app_only=True のときは、iOS アプリに載せている商品（app_catalog）だけから選ぶ。
    類似度が同じ商品は、レビューの多い順に並べる（タグが同じ商品は類似度も同じになりやすいため）。
    """
    pref = _build_preference_vector(user_id)

    with get_conn() as conn:
        evaluated = set(
            r["item_code"] for r in conn.execute(
                "SELECT item_code FROM user_actions WHERE user_id=?", (user_id,)
            ).fetchall()
        )
        sql = """
            SELECT v.item_code, v.vector_json, COALESCE(i.review_count, 0) AS review_count
            FROM item_vectors v JOIN items i ON i.item_code = v.item_code
        """
        # app_catalog が空（DataManifest.json なしで起動した）ときは、絞らずに全商品から選ぶ
        if app_only and conn.execute("SELECT 1 FROM app_catalog LIMIT 1").fetchone():
            sql += " WHERE v.item_code IN (SELECT item_code FROM app_catalog)"
        rows = conn.execute(sql).fetchall()

    candidates = [r for r in rows if r["item_code"] not in evaluated]
    if not candidates:
        return []

    if pref is None:
        # LIKEが無い場合はランダムスコア
        import random
        result = [{"item_code": r["item_code"], "score": round(random.uniform(0.1, 0.5), 4), "reasons": []}
                  for r in candidates]
        result.sort(key=lambda x: x["score"], reverse=True)
        return result[:limit]

    matrix = np.array([json.loads(r["vector_json"]) for r in candidates], dtype=float)
    sims   = cosine_similarity(pref.reshape(1, -1), matrix)[0]

    order = sorted(range(len(candidates)),
                   key=lambda k: (round(float(sims[k]), 4), candidates[k]["review_count"]),
                   reverse=True)[:limit]
    return [
        {
            "item_code": candidates[k]["item_code"],
            "score":     round(float(sims[k]), 4),
            "reasons":   _reasons(pref, matrix[k]),
        }
        for k in order
    ]
