"""AI-02/03: コンテンツベースフィルタリング推薦エンジン（本実装）。"""
import json
import math
import numpy as np
from datetime import datetime, timezone
from sklearn.metrics.pairwise import cosine_similarity
from backend.db import get_conn
from recommender.vectorizer import get_vector, vectorize_item, TAG_DIM

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


def get_recommendations(user_id: int, limit: int = 20) -> list[dict]:
    """AI-03: コサイン類似度で上位 limit 件を返す。"""
    pref = _build_preference_vector(user_id)

    with get_conn() as conn:
        evaluated = set(
            r["item_code"] for r in conn.execute(
                "SELECT item_code FROM user_actions WHERE user_id=?", (user_id,)
            ).fetchall()
        )
        all_vecs = conn.execute(
            "SELECT item_code, vector_json FROM item_vectors"
        ).fetchall()

    candidates = [
        (r["item_code"], np.array(json.loads(r["vector_json"]), dtype=float))
        for r in all_vecs
        if r["item_code"] not in evaluated
    ]

    if not candidates:
        return []

    if pref is None:
        # LIKEが無い場合はランダムスコア
        import random
        result = [{"item_code": c, "score": round(random.uniform(0.1, 0.5), 4)} for c, _ in candidates]
        result.sort(key=lambda x: x["score"], reverse=True)
        return result[:limit]

    codes  = [c for c, _ in candidates]
    matrix = np.array([v for _, v in candidates])
    sims   = cosine_similarity(pref.reshape(1, -1), matrix)[0]

    ranked = sorted(zip(codes, sims), key=lambda x: x[1], reverse=True)
    return [{"item_code": c, "score": round(float(s), 4)} for c, s in ranked[:limit]]
