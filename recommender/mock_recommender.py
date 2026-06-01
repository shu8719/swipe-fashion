"""推薦エンジン本実装が来るまでのスタブ。ランダムスコアで返す。"""
import random
from backend.db import get_conn


def get_recommendations(user_id: int, limit: int = 20) -> list[dict]:
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT item_code FROM items WHERE item_code NOT IN "
            "(SELECT item_code FROM user_actions WHERE user_id=?)",
            (user_id,),
        ).fetchall()
    items = [{"item_code": r["item_code"], "score": round(random.uniform(0.1, 1.0), 4)} for r in rows]
    items.sort(key=lambda x: x["score"], reverse=True)
    return items[:limit]
