import secrets
import bcrypt
from functools import wraps
from flask import request, jsonify, g
from backend.db import get_conn


def hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()


def check_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode(), hashed.encode())


def create_token(user_id: int) -> str:
    token = secrets.token_hex(32)
    with get_conn() as conn:
        conn.execute("INSERT INTO tokens (token, user_id) VALUES (?,?)", (token, user_id))
    return token


def resolve_token(token: str):
    with get_conn() as conn:
        row = conn.execute(
            "SELECT user_id FROM tokens WHERE token=?", (token,)
        ).fetchone()
    return row["user_id"] if row else None


def login_required(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        auth = request.headers.get("Authorization", "")
        token = auth.removeprefix("Bearer ").strip()
        user_id = resolve_token(token) if token else None
        if user_id is None:
            return jsonify({"error": "Unauthorized"}), 401
        g.user_id = user_id
        return f(*args, **kwargs)
    return wrapper
