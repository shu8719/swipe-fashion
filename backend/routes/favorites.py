from flask import Blueprint, jsonify, g
from backend.db import get_conn
from backend.auth import login_required

bp = Blueprint("favorites", __name__, url_prefix="/api/favorites")


@bp.get("")
@login_required
def list_favorites():
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT i.* FROM items i
            JOIN user_actions ua ON ua.item_id = i.item_id
            WHERE ua.user_id=? AND ua.action='LIKE'
            ORDER BY ua.created_at DESC
            """,
            (g.user_id,),
        ).fetchall()
    return jsonify([dict(r) for r in rows])
