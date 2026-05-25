from flask import Blueprint, jsonify, g
from backend.auth import login_required
from backend.db import get_conn

bp = Blueprint("recommend", __name__, url_prefix="/api/recommend")


def _get_recommender():
    try:
        from recommender.recommender import get_recommendations  # 担当A実装
    except ImportError:
        from recommender.mock_recommender import get_recommendations
    return get_recommendations


@bp.get("")
@login_required
def recommend():
    get_recommendations = _get_recommender()
    results = get_recommendations(g.user_id, limit=20)

    if not results:
        return jsonify([])

    item_ids = [r["item_id"] for r in results]
    scores   = {r["item_id"]: r["score"] for r in results}

    with get_conn() as conn:
        placeholders = ",".join("?" * len(item_ids))
        rows = conn.execute(
            f"SELECT * FROM items WHERE item_id IN ({placeholders})", item_ids
        ).fetchall()

    items = {r["item_id"]: dict(r) for r in rows}
    ordered = []
    for item_id in item_ids:
        if item_id in items:
            entry = items[item_id]
            entry["score"] = scores[item_id]
            ordered.append(entry)

    return jsonify(ordered)
