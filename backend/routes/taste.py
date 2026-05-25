from flask import Blueprint, jsonify, g
from backend.auth import login_required
from backend.ai.taste_gen import get_taste, maybe_update_taste

bp = Blueprint("taste", __name__, url_prefix="/api/taste")


@bp.get("")
@login_required
def taste():
    # LIKEが閾値に達した時だけ非同期的に更新（PoC版は同期で呼ぶ）
    maybe_update_taste(g.user_id)
    return jsonify(get_taste(g.user_id))
