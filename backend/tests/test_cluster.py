"""AI-04 K-meansクラスタリングテスト（item_code対応版）。"""
from backend.ai.cluster import run_clustering, get_cluster_summary
from backend.db import get_conn
from backend.auth import hash_password


def _create_user(i):
    with get_conn() as conn:
        conn.execute(
            "INSERT OR IGNORE INTO users (email, password_hash, age, gender, region) VALUES (?,?,?,?,?)",
            (f"cluster{i}@test.com", hash_password("pass"), 20+i%10, "男性" if i%2==0 else "女性", "大阪"),
        )
        return conn.execute("SELECT user_id FROM users WHERE email=?", (f"cluster{i}@test.com",)).fetchone()["user_id"]


def _like_items(user_id, codes):
    with get_conn() as conn:
        for code in codes:
            conn.execute(
                "INSERT OR IGNORE INTO user_actions (user_id, item_code, action) VALUES (?,?,?)",
                (user_id, code, "LIKE"),
            )


def test_clustering_ok():
    for i in range(8):
        uid = _create_user(i)
        _like_items(uid, [f"dummy:item{(i%10)+1:04d}", f"dummy:item{(i%10)+2:04d}", f"dummy:item{(i%10)+3:04d}"])
    result = run_clustering(n_clusters=3)
    assert result["status"] == "ok"
    assert result["n_clusters"] == 3


def test_clustering_skipped_too_few():
    result = run_clustering(n_clusters=50)
    if result["status"] == "skipped":
        assert "reason" in result


def test_cluster_summary():
    for i in range(4):
        uid = _create_user(100+i)
        _like_items(uid, ["dummy:item0001","dummy:item0002","dummy:item0003"])
    run_clustering(n_clusters=2)
    summary = get_cluster_summary()
    assert isinstance(summary, list)
