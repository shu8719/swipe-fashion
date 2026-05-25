from flask import Blueprint, jsonify, request, g
from backend.db import get_conn
from backend.auth import login_required

bp = Blueprint("items", __name__, url_prefix="/api/items")


def _item_row_to_dict(row) -> dict:
    item = dict(row)
    with get_conn() as conn:
        tags = conn.execute(
            "SELECT tag_category, tag_value FROM item_tags WHERE item_id=?",
            (item["item_id"],),
        ).fetchall()
    item["tags"] = [{"category": t["tag_category"], "value": t["tag_value"]} for t in tags]
    return item


@bp.get("/next")
@login_required
def next_items():
    limit = min(int(request.args.get("limit", 10)), 50)
    with get_conn() as conn:
        # 未評価商品を返す
        rows = conn.execute(
            """
            SELECT i.* FROM items i
            WHERE i.item_id NOT IN (
                SELECT item_id FROM user_actions WHERE user_id=?
            )
            ORDER BY RANDOM()
            LIMIT ?
            """,
            (g.user_id, limit),
        ).fetchall()
    return jsonify([_item_row_to_dict(r) for r in rows])


@bp.get("/<int:item_id>")
@login_required
def item_detail(item_id: int):
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM items WHERE item_id=?", (item_id,)).fetchone()
    if not row:
        return jsonify({"error": "商品が見つからへんね"}), 404
    return jsonify(_item_row_to_dict(row))
