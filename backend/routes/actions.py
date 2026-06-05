from flask import Blueprint, request, jsonify, g, current_app
from backend.db import get_conn
from backend.auth import login_required

bp = Blueprint("actions", __name__, url_prefix="/api/actions")

_VALID_ACTIONS = {"LIKE", "SKIP"}


@bp.post("")
@login_required
def post_action():
    data      = request.get_json(force=True) or {}
    item_code = str(data.get("item_code") or data.get("item_id") or "").strip()
    action    = str(data.get("action", "")).upper()

    if not item_code or action not in _VALID_ACTIONS:
        return jsonify({"error": "item_code と action(LIKE/SKIP) が必要やよ"}), 400

    already_recorded = False
    with get_conn() as conn:
        if not conn.execute("SELECT 1 FROM items WHERE item_code=?", (item_code,)).fetchone():
            return jsonify({"error": "その商品は存在しないね"}), 404
        already_recorded = conn.execute(
            """
            SELECT 1 FROM user_actions
            WHERE user_id=? AND item_code=? AND action=?
            """,
            (g.user_id, item_code, action),
        ).fetchone() is not None

        if not already_recorded:
            conn.execute(
                "INSERT INTO user_actions (user_id, item_code, action) VALUES (?,?,?)",
                (g.user_id, item_code, action),
            )

    taste_available = False
    if action == "LIKE":
        try:
            from backend.ai.taste_gen import maybe_update_taste
            taste_available = maybe_update_taste(g.user_id) is not None
        except Exception:
            current_app.logger.exception("taste description update failed")

    return jsonify({
        "ok": True,
        "already_recorded": already_recorded,
        "taste_available": taste_available,
    })
