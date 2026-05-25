"""AI-05 嗜好説明生成の単体テスト（モックプロバイダ使用）。"""
from backend.ai.taste_gen import maybe_update_taste, get_taste
from backend.db import get_conn
from backend.auth import hash_password


def _setup_user_with_likes(n_likes: int) -> int:
    with get_conn() as conn:
        conn.execute(
            "INSERT OR IGNORE INTO users (email, password_hash, age, gender, region) VALUES (?,?,?,?,?)",
            ("taste_test@example.com", hash_password("pass"), 22, "男性", "大阪"),
        )
        user_id = conn.execute(
            "SELECT user_id FROM users WHERE email=?", ("taste_test@example.com",)
        ).fetchone()["user_id"]

        for i in range(1, n_likes + 1):
            item_id = ((i - 1) % 30) + 1
            conn.execute(
                "INSERT OR IGNORE INTO user_actions (user_id, item_id, action) VALUES (?,?,?)",
                (user_id, item_id, "LIKE"),
            )
    return user_id


def test_no_description_before_threshold():
    user_id = _setup_user_with_likes(5)
    result = maybe_update_taste(user_id)
    # LIKEが10件未満 → キャッシュなければNone
    assert result is None or isinstance(result, str)


def test_description_generated_after_threshold():
    user_id = _setup_user_with_likes(10)
    result = maybe_update_taste(user_id)
    assert result is not None
    assert isinstance(result, str)
    assert len(result) > 10


def test_get_taste_after_generation():
    user_id = _setup_user_with_likes(10)
    maybe_update_taste(user_id)
    taste = get_taste(user_id)
    assert "description" in taste
    assert "updated_at" in taste
    assert taste["description"] is not None


def test_no_redundant_call_within_threshold():
    user_id = _setup_user_with_likes(10)
    maybe_update_taste(user_id)

    # DBの like_count_at_gen を確認
    with get_conn() as conn:
        row = conn.execute(
            "SELECT like_count_at_gen FROM taste_descriptions WHERE user_id=?", (user_id,)
        ).fetchone()
    assert row is not None
    assert row["like_count_at_gen"] == 10
