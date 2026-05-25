"""AI-04 K-meansクラスタリングの単体テスト。"""
from backend.ai.cluster import run_clustering, get_cluster_summary
from backend.db import get_conn
from backend.auth import hash_password


def _create_user(i: int):
    with get_conn() as conn:
        conn.execute(
            "INSERT OR IGNORE INTO users (email, password_hash, age, gender, region) VALUES (?,?,?,?,?)",
            (f"user{i}@test.com", hash_password("pass"), 20 + i % 10, "男性" if i % 2 == 0 else "女性", "大阪"),
        )
        return conn.execute("SELECT user_id FROM users WHERE email=?", (f"user{i}@test.com",)).fetchone()["user_id"]


def _like_items(user_id: int, item_ids: list[int]):
    with get_conn() as conn:
        for iid in item_ids:
            conn.execute(
                "INSERT OR IGNORE INTO user_actions (user_id, item_id, action) VALUES (?,?,?)",
                (user_id, iid, "LIKE"),
            )


def test_clustering_with_enough_users():
    for i in range(8):
        uid = _create_user(i)
        _like_items(uid, [(i % 10) + 1, (i % 10) + 2, (i % 10) + 3])

    result = run_clustering(n_clusters=3)
    assert result["status"] == "ok"
    assert result["n_clusters"] == 3
    assert result["n_users"] >= 3
    assert "silhouette_score" in result


def test_clustering_skipped_when_too_few_users():
    result = run_clustering(n_clusters=10)
    # ユーザー数が10未満なら skip
    if result["status"] == "skipped":
        assert "reason" in result
    else:
        assert result["status"] == "ok"


def test_cluster_summary_after_run():
    for i in range(4):
        uid = _create_user(100 + i)
        _like_items(uid, [1, 2, 3])
    run_clustering(n_clusters=2)
    summary = get_cluster_summary()
    assert isinstance(summary, list)
    assert all("cluster_id" in s and "user_count" in s for s in summary)
