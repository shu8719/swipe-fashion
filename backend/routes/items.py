from flask import Blueprint, jsonify, request, g
from backend.db import get_conn
from backend.auth import login_required

bp = Blueprint("items", __name__, url_prefix="/api/items")


def _row_to_rakuten(row) -> dict:
    """DBRow → Swift APIItem が JSONDecoder できる楽天互換形式に変換。"""
    d = dict(row)
    image_url = d.get("image_url") or ""
    return {
        "itemCode":      d.get("item_code", ""),
        "itemName":      d.get("item_name", ""),
        "catchcopy":     d.get("catchcopy", ""),
        "itemPrice":     d.get("item_price", 0),
        "shopName":      d.get("shop_name", ""),
        "reviewAverage": d.get("review_average", 0.0),
        "reviewCount":   d.get("review_count", 0),
        "itemUrl":       d.get("item_url", ""),
        "mediumImageUrls": [{"imageUrl": image_url}],
        "genreId":       d.get("genre_id", 0),
    }


@bp.get("/next")
@login_required
def next_items():
    limit = min(int(request.args.get("limit", 10)), 50)
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT i.* FROM items i
            WHERE i.item_code NOT IN (
                SELECT item_code FROM user_actions WHERE user_id=?
            )
            ORDER BY RANDOM()
            LIMIT ?
            """,
            (g.user_id, limit),
        ).fetchall()
    return jsonify([_row_to_rakuten(r) for r in rows])


@bp.get("/<path:item_code>")
@login_required
def item_detail(item_code: str):
    with get_conn() as conn:
        row = conn.execute(
            "SELECT * FROM items WHERE item_code=?", (item_code,)
        ).fetchone()
    if not row:
        return jsonify({"error": "商品が見つからへんね"}), 404
    return jsonify(_row_to_rakuten(row))
