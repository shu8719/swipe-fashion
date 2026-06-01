"""AI-04: K-meansクラスタリングでユーザーをセグメント分類する。"""
import json
import numpy as np
from datetime import datetime, timezone
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import silhouette_score
from backend.db import get_conn

_STYLE_TAGS    = ["韓国系","ストリート","カジュアル","きれいめ","モード","ワーク"]
_COLOR_TAGS    = ["モノトーン","アースカラー","ビビッド","ペールトーン"]
_SILHOUETTE_T  = ["オーバーサイズ","スリム","リラックス","タイト"]
_MATERIAL_TAGS = ["デニム","ニット","コットン","レザー","シアー"]
_PRICE_TAGS    = ["低","中","高"]
_ALL_TAGS      = _STYLE_TAGS + _COLOR_TAGS + _SILHOUETTE_T + _MATERIAL_TAGS + _PRICE_TAGS
_TAG_DIM       = len(_ALL_TAGS)  # 22

_GENDER_MAP = {"男性": [1, 0, 0], "女性": [0, 1, 0], "その他": [0, 0, 1]}
_PRICE_RANGE_MAP = {"低": 0, "中": 1, "高": 2}


def _build_user_vector(user_id: int) -> np.ndarray | None:
    """ユーザーの好みベクトル(22次元) + 属性ベクトルを返す。"""
    with get_conn() as conn:
        user = conn.execute(
            "SELECT age, gender FROM users WHERE user_id=?", (user_id,)
        ).fetchone()

        likes = conn.execute(
            """
            SELECT it.tag_category, it.tag_value, COUNT(*) AS cnt
            FROM user_actions ua
            JOIN item_tags it ON it.item_code = ua.item_code
            WHERE ua.user_id=? AND ua.action='LIKE'
            GROUP BY it.tag_category, it.tag_value
            """,
            (user_id,),
        ).fetchall()

        skips = conn.execute(
            """
            SELECT it.tag_category, it.tag_value, COUNT(*) AS cnt
            FROM user_actions ua
            JOIN item_tags it ON it.item_code = ua.item_code
            WHERE ua.user_id=? AND ua.action='SKIP'
            GROUP BY it.tag_category, it.tag_value
            """,
            (user_id,),
        ).fetchall()

    if not likes and not skips:
        return None

    pref = np.zeros(_TAG_DIM, dtype=float)
    tag_index = {t: i for i, t in enumerate(_ALL_TAGS)}

    for row in likes:
        key = row["tag_value"]
        if key in tag_index:
            pref[tag_index[key]] += row["cnt"]

    for row in skips:
        key = row["tag_value"]
        if key in tag_index:
            pref[tag_index[key]] -= row["cnt"] * 0.5

    # 属性エンコード（性別 3次元 + 年代 1次元）
    gender_vec = _GENDER_MAP.get(user["gender"] if user else None, [0, 0, 0])
    age_norm   = (user["age"] / 10.0) if (user and user["age"]) else 2.5  # 10代=1, 30代=3...

    return np.concatenate([pref, gender_vec, [age_norm]])


def run_clustering(n_clusters: int = 4) -> dict:
    """全ユーザーを K-means でクラスタリングし、結果をDBに保存する。"""
    with get_conn() as conn:
        user_ids = [r["user_id"] for r in conn.execute("SELECT user_id FROM users").fetchall()]

    vectors, valid_ids = [], []
    for uid in user_ids:
        v = _build_user_vector(uid)
        if v is not None:
            vectors.append(v)
            valid_ids.append(uid)

    if len(valid_ids) < n_clusters:
        return {"status": "skipped", "reason": f"ユーザー数({len(valid_ids)})がクラスタ数({n_clusters})より少ないね"}

    X = np.array(vectors)
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    km = KMeans(n_clusters=n_clusters, random_state=42, n_init="auto")
    labels = km.fit_predict(X_scaled)

    sil = silhouette_score(X_scaled, labels) if len(set(labels)) > 1 else 0.0

    now = datetime.now(timezone.utc).isoformat()
    with get_conn() as conn:
        for uid, label in zip(valid_ids, labels):
            conn.execute(
                """
                INSERT INTO user_clusters (user_id, cluster_id, assigned_at)
                VALUES (?,?,?)
                ON CONFLICT(user_id) DO UPDATE SET
                  cluster_id=excluded.cluster_id,
                  assigned_at=excluded.assigned_at
                """,
                (uid, int(label), now),
            )

    return {
        "status":          "ok",
        "n_clusters":      n_clusters,
        "n_users":         len(valid_ids),
        "silhouette_score": round(float(sil), 4),
        "cluster_sizes":  {str(i): int(np.sum(labels == i)) for i in range(n_clusters)},
    }


def get_cluster_summary() -> list[dict]:
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT cluster_id, COUNT(*) AS cnt
            FROM user_clusters
            GROUP BY cluster_id
            ORDER BY cluster_id
            """
        ).fetchall()
    return [{"cluster_id": r["cluster_id"], "user_count": r["cnt"]} for r in rows]
