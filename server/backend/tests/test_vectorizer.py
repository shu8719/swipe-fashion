"""商品テキスト → タグ・ベクトルのテスト。"""
from recommender.vectorizer import extract_tags, tags_to_vector, vectorize_all, TAG_DIM


def test_extract_style_korean():
    tags = extract_tags("韓国系 オーバーサイズ 黒 コットン", 2800)
    assert tags.get("style") == "韓国系"
    assert tags.get("silhouette") == "オーバーサイズ"
    assert tags.get("color") == "モノトーン"
    assert tags.get("material") == "コットン"
    assert tags.get("price_range") == "低"


def test_no_style_when_no_keyword():
    # スタイルのキーワードがなければ、初期値で埋めずに空のままにする（価格帯は必ず付く）
    tags = extract_tags("シャツ 5000円", 5000)
    assert "style" not in tags
    assert tags.get("price_range") == "中"


def test_most_hits_wins():
    # 先に書いたタグではなく、当たった回数が多いタグを選ぶ
    tags = extract_tags("カジュアル きれいめ オフィス 上品", 4000)
    assert tags.get("style") == "きれいめ"


def test_title_outweighs_caption():
    # 商品名の1回は、説明文の2回より重い
    tags = extract_tags("ワーク シャツ", 4000, caption="カジュアル デイリー")
    assert tags.get("style") == "ワーク"


def test_vectorize_all_replaces_stale_tags():
    # 辞書を変えたあとに入れ直しても、前の判定のタグが残らない
    from backend.db import get_conn
    with get_conn() as conn:
        conn.execute("INSERT OR IGNORE INTO item_tags VALUES ('dummy:item0001', 'style', 'ワーク')")
    vectorize_all()
    with get_conn() as conn:
        styles = [r["tag_value"] for r in conn.execute(
            "SELECT tag_value FROM item_tags WHERE item_code='dummy:item0001' AND tag_category='style'"
        )]
    assert styles == ["韓国系"]


def test_vector_dim():
    tags = extract_tags("ストリート ビビッド コットン オーバーサイズ", 3000)
    vec = tags_to_vector(tags)
    assert vec.shape == (TAG_DIM,)


def test_vectorize_all():
    count = vectorize_all()
    assert count == 30  # ダミー30件全部ベクトル化できる


def test_recommend_after_vectorize():
    vectorize_all()
    from recommender.recommender import get_recommendations
    # ユーザー0でもランダムスコアで返る（LIKEなし）
    result = get_recommendations(999, limit=5)
    assert isinstance(result, list)
