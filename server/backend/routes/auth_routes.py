from flask import Blueprint, request, jsonify
from backend.db import get_conn
from backend.auth import hash_password, check_password, create_token

bp = Blueprint("auth", __name__, url_prefix="/api/auth")


@bp.post("/register")
def register():
    data = request.get_json(force=True) or {}
    email, password = data.get("email","").strip(), data.get("password","")
    if not email or not password:
        return jsonify({"error": "email と password は必須やよ"}), 400
    with get_conn() as conn:
        if conn.execute("SELECT 1 FROM users WHERE email=?", (email,)).fetchone():
            return jsonify({"error": "そのメールは既に登録済みやね"}), 409
        cur = conn.execute(
            "INSERT INTO users (email, password_hash, age, gender, region) VALUES (?,?,?,?,?)",
            (email, hash_password(password), data.get("age"), data.get("gender",""), data.get("region","")),
        )
    token = create_token(cur.lastrowid)
    return jsonify({"user_id": cur.lastrowid, "token": token}), 201


@bp.post("/login")
def login():
    data = request.get_json(force=True) or {}
    email, password = data.get("email","").strip(), data.get("password","")
    if not email or not password:
        return jsonify({"error": "email と password は必須やよ"}), 400
    with get_conn() as conn:
        row = conn.execute("SELECT user_id, password_hash FROM users WHERE email=?", (email,)).fetchone()
    if not row or not check_password(password, row["password_hash"]):
        return jsonify({"error": "メールかパスワードが違うね"}), 401
    return jsonify({"user_id": row["user_id"], "token": create_token(row["user_id"])})


@bp.post("/device")
def device_auth():
    """Swift デバイスUUID 匿名認証。"""
    data      = request.get_json(force=True) or {}
    device_id = data.get("device_id", "").strip()
    if not device_id:
        return jsonify({"error": "device_id は必須やよ"}), 400
    with get_conn() as conn:
        row = conn.execute("SELECT user_id FROM users WHERE device_id=?", (device_id,)).fetchone()
        if row:
            user_id = row["user_id"]
        else:
            cur = conn.execute("INSERT INTO users (device_id) VALUES (?)", (device_id,))
            user_id = cur.lastrowid
    return jsonify({"user_id": user_id, "token": create_token(user_id)})
