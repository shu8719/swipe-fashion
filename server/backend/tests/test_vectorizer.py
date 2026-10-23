"""AI-01 vectorizer テスト。"""
from recommender.vectorizer import extract_tags, tags_to_vector, vectorize_all, TAG_DIM


def test_extract_style_korean():
    tags = extract_tags("韓国系 オーバーサイズ 黒 コットン", 2800)
    assert tags.get("style") == "韓国系"
    assert tags.get("silhouette") == "オーバーサイズ"
    assert tags.get("color") == "モノトーン"
    assert tags.get("material") == "コットン"
    assert tags.get("price_range") == "低"


def test_extract_style_casual_fallback():
    # スタイルキーワードなし → カジュアルにフォールバック
    tags = extract_tags("シャツ 5000円", 5000)
    assert tags.get("style") == "カジュアル"
    assert tags.get("price_range") == "中"


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
