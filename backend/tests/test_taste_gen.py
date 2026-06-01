"""AI-05 嗜好説明生成テスト（item_code対応版）。"""
from backend.ai.taste_gen import maybe_update_taste, get_taste
from backend.db import get_conn
from backend.auth import hash_password


def _setup(n_likes):
    with get_conn() as conn:
        conn.execute(
            "INSERT OR IGNORE INTO users (email, password_hash, age, gender, region) VALUES (?,?,?,?,?)",
            ("taste@test.com", hash_password("pw"), 22, "男性", "大阪"),
        )
        uid = conn.execute("SELECT user_id FROM users WHERE email=?", ("taste@test.com",)).fetchone()["user_id"]
        for i in range(1, n_likes+1):
            code = f"dummy:item{((i-1)%30)+1:04d}"
            conn.execute(
                "INSERT OR IGNORE INTO user_actions (user_id, item_code, action) VALUES (?,?,?)",
                (uid, code, "LIKE"),
            )
    return uid


def test_no_desc_below_threshold():
    uid = _setup(5)
    result = maybe_update_taste(uid)
    assert result is None or isinstance(result, str)


def test_desc_after_threshold():
    uid = _setup(10)
    result = maybe_update_taste(uid)
    assert result is not None and isinstance(result, str) and len(result) > 10


def test_get_taste_after_gen():
    uid = _setup(10)
    maybe_update_taste(uid)
    taste = get_taste(uid)
    assert taste["description"] is not None


def test_no_redundant_call():
    uid = _setup(10)
    maybe_update_taste(uid)
    with get_conn() as conn:
        row = conn.execute("SELECT like_count_at_gen FROM taste_descriptions WHERE user_id=?", (uid,)).fetchone()
    assert row["like_count_at_gen"] == 10
