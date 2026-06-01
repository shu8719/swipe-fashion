from flask import Blueprint, jsonify, g
from backend.auth import login_required
from backend.db import get_conn
from backend.routes.items import _row_to_rakuten

bp = Blueprint("recommend", __name__, url_prefix="/api/recommend")


def _get_recommender():
    try:
        from recommender.recommender import get_recommendations
    except ImportError:
        from recommender.mock_recommender import get_recommendations
    return get_recommendations


@bp.get("")
@login_required
def recommend():
    results = _get_recommender()(g.user_id, limit=20)
    if not results:
        return jsonify([])

    item_codes = [r["item_code"] for r in results]
    scores     = {r["item_code"]: r["score"] for r in results}

    with get_conn() as conn:
        placeholders = ",".join("?" * len(item_codes))
        rows = conn.execute(
            f"SELECT * FROM items WHERE item_code IN ({placeholders})", item_codes
        ).fetchall()

    items_map = {r["item_code"]: r for r in rows}
    ordered = []
    for code in item_codes:
        if code in items_map:
            entry = _row_to_rakuten(items_map[code])
            entry["score"] = scores[code]
            ordered.append(entry)
    return jsonify(ordered)
