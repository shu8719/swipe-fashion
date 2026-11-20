from flask import Blueprint, jsonify, g, request
from backend.auth import login_required
from backend.db import get_conn
from backend.routes.items import _row_to_rakuten
from recommender.recommender import get_recommendations

bp = Blueprint("recommend", __name__, url_prefix="/api/recommend")


_MAX_LIMIT = 100


@bp.get("")
@login_required
def recommend():
    """好みに近い順のおすすめ。

    クエリ:
      limit: 件数（1〜100、既定 20）。アプリは多めに取り、種別の絞り込みを端末側で行う
      scope: app にすると、iOS アプリに載せている商品だけから選ぶ（既定は全商品）
    """
    try:
        limit = int(request.args.get("limit", 20))
    except ValueError:
        return jsonify({"error": "limit は整数で指定してください"}), 400
    limit = max(1, min(limit, _MAX_LIMIT))
    app_only = request.args.get("scope", "all") == "app"

    results = get_recommendations(g.user_id, limit=limit, app_only=app_only)
    if not results:
        return jsonify([])

    item_codes = [r["item_code"] for r in results]
    by_code    = {r["item_code"]: r for r in results}

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
            entry["score"]   = by_code[code]["score"]
            entry["reasons"] = by_code[code]["reasons"]
            ordered.append(entry)
    return jsonify(ordered)
