from flask import Blueprint, jsonify, g, current_app
from backend.auth import login_required
from backend.ai.taste_gen import get_taste, maybe_update_taste

bp = Blueprint("taste", __name__, url_prefix="/api/taste")


@bp.get("")
@login_required
def taste():
    # LIKEが閾値に達した時だけ非同期的に更新（PoC版は同期で呼ぶ）
    # LLMに繋がらなくても500にせず、保存済みの説明文（無ければ None）を返す
    try:
        maybe_update_taste(g.user_id)
    except Exception:
        current_app.logger.exception("taste description update failed")
    return jsonify(get_taste(g.user_id))
