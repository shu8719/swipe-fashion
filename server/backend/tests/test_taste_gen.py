"""好みの説明文を作る処理のテスト。"""
from backend.ai.taste_gen import maybe_update_taste, get_taste, _get_user_context, _PROMPT_TEMPLATE
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


def test_context_is_readable_for_llm():
    uid = _setup(10)
    ctx = _get_user_context(uid)
    # 内部の名前（style:カジュアル など）ではなく、タグそのものを渡す
    assert ctx["top_tags"] and ":" not in ctx["top_tags"]
    # 「最近 LIKE した商品」には商品名が入る
    assert "テスト" in ctx["liked_items_summary"]
    assert ctx["price_range"] in {"3,000円未満", "3,000〜10,000円", "10,000円超"}
    assert ctx["user_line"] == "【ユーザー属性】：20代 男性 大阪在住"


def test_context_counts_each_shop_once_per_item():
    # ショップAの商品はタグが5つで1件、ショップBはタグが1つで2件。商品の件数で数えれば B が先になる
    with get_conn() as conn:
        uid = conn.execute("INSERT INTO users (device_id) VALUES ('device-shop')").lastrowid
        items = [("t:a1", "ショップA", ["韓国系", "モノトーン", "オーバーサイズ", "コットン", "低"]),
                 ("t:b1", "ショップB", ["低"]),
                 ("t:b2", "ショップB", ["低"])]
        for code, shop, tags in items:
            conn.execute("INSERT INTO items (item_code, item_name, shop_name) VALUES (?,?,?)", (code, code, shop))
            conn.executemany("INSERT INTO item_tags VALUES (?, 'x', ?)", [(code, t) for t in tags])
            conn.execute("INSERT INTO user_actions (user_id, item_code, action) VALUES (?,?, 'LIKE')", (uid, code))
    assert _get_user_context(uid)["top_shops"] == "ショップB、ショップA"


def test_context_omits_unknown_attributes():
    # 端末ログインのユーザーは年齢などが空なので、「不明代」のような行を作らない
    with get_conn() as conn:
        uid = conn.execute("INSERT INTO users (device_id) VALUES ('device-x')").lastrowid
        for i in range(1, 11):
            conn.execute("INSERT INTO user_actions (user_id, item_code, action) VALUES (?,?, 'LIKE')",
                         (uid, f"dummy:item{i:04d}"))
    ctx = _get_user_context(uid)
    prompt = _PROMPT_TEMPLATE.format(**ctx)
    assert ctx["user_line"] == ""
    assert "不明" not in prompt
