"""楽天の商品テキスト → 22次元のタグベクトル。"""
import json
import re
import numpy as np
from backend.db import get_conn

# ---- タグ定義（22次元）----
_ALL_TAGS = [
    # style (6)
    "韓国系", "ストリート", "カジュアル", "きれいめ", "モード", "ワーク",
    # color (4)
    "モノトーン", "アースカラー", "ビビッド", "ペールトーン",
    # silhouette (4)
    "オーバーサイズ", "スリム", "リラックス", "タイト",
    # material (5)
    "デニム", "ニット", "コットン", "レザー", "シアー",
    # price_range (3)
    "低", "中", "高",
]
TAG_INDEX = {t: i for i, t in enumerate(_ALL_TAGS)}
TAG_DIM   = len(_ALL_TAGS)  # 22

# ---- キーワード辞書（テキスト → タグ）----
_KEYWORD_MAP: list[tuple[list[str], str]] = [
    # style
    (["韓国", "オルチャン", "韓国系", "韓国風"],             "韓国系"),
    (["ストリート", "ビッグシルエット", "スケート", "グラフィック"], "ストリート"),
    (["カジュアル", "デイリー", "ナチュラル", "リネン"],     "カジュアル"),
    (["きれいめ", "オフィス", "ビジカジ", "フォーマル", "上品", "きちんと"], "きれいめ"),
    (["モード", "アバンギャルド", "エッジ"],                 "モード"),
    (["ワーク", "カーゴ", "アウトドア", "ミリタリー", "ワークウェア"], "ワーク"),
    # color
    (["モノトーン", "黒", "ブラック", "白", "ホワイト", "グレー", "チャコール"], "モノトーン"),
    (["アースカラー", "ベージュ", "カーキ", "オリーブ", "ブラウン", "テラコッタ", "アース"], "アースカラー"),
    (["ビビッド", "カラフル", "鮮やか", "派手", "蛍光", "ネオン", "レッド", "ブルー", "グリーン", "イエロー"], "ビビッド"),
    (["ペール", "ペールトーン", "パステル", "淡い", "ライト", "くすみ", "ピンク", "ラベンダー", "ミント"], "ペールトーン"),
    # silhouette
    (["オーバーサイズ", "ビッグ", "ゆったり", "ルーズ", "ダボ", "ビッグT", "ワイド"], "オーバーサイズ"),
    (["スリム", "細身", "スキニー", "タイトシルエット"],     "スリム"),
    (["リラックス", "ゆるい", "ゆるっと", "ラフ", "ルーズ", "ゆとり"], "リラックス"),
    (["タイト", "フィット", "ぴったり", "ボディコン"],       "タイト"),
    # material
    (["デニム", "ジーンズ", "ジーパン", "ジーン"],          "デニム"),
    (["ニット", "セーター", "ウール", "カーディガン", "ニットベスト"], "ニット"),
    (["コットン", "綿", "天竺", "Tシャツ", "スウェット", "パーカー"], "コットン"),
    (["レザー", "革", "フェイクレザー", "PU"],              "レザー"),
    (["シアー", "透け", "シースルー", "レース", "チュール"], "シアー"),
]


# タグ → カテゴリ（style / color / silhouette / material）
_TAG_CATEGORY: dict[str, str] = {
    **{t: "style"      for t in _ALL_TAGS[0:6]},
    **{t: "color"      for t in _ALL_TAGS[6:10]},
    **{t: "silhouette" for t in _ALL_TAGS[10:14]},
    **{t: "material"   for t in _ALL_TAGS[14:19]},
}

# 商品名・キャッチコピーでの一致は、長い商品説明での一致より重く数える
_TITLE_WEIGHT = 3


def extract_tags(title: str, item_price: int = 0, caption: str = "") -> dict[str, str]:
    """商品名・キャッチコピー（title）と商品説明（caption）から、カテゴリごとにタグを1つ選ぶ。

    カテゴリごとに、キーワードが当たった回数（title は _TITLE_WEIGHT 倍）が一番多いタグを選ぶ。
    どのキーワードにも当たらないカテゴリは空のままにする。
    以前は style が空のとき「カジュアル」で埋めていたが、そのせいで商品の72%がカジュアルになり、
    好みの違いが出なかった。価格帯だけは価格から必ず決める。
    """
    scores: dict[str, dict[str, int]] = {}
    for keywords, tag in _KEYWORD_MAP:
        hits = (sum(title.count(kw) for kw in keywords) * _TITLE_WEIGHT
                + sum(caption.count(kw) for kw in keywords))
        if hits:
            scores.setdefault(_TAG_CATEGORY[tag], {})[tag] = hits

    # 同点のときは _KEYWORD_MAP で先に書いたタグを選ぶ（max は最初の最大値を返す）
    matched = {cat: max(tags, key=tags.get) for cat, tags in scores.items()}

    if item_price <= 0:
        matched["price_range"] = "中"
    elif item_price < 3000:
        matched["price_range"] = "低"
    elif item_price <= 10000:
        matched["price_range"] = "中"
    else:
        matched["price_range"] = "高"
    return matched


def tags_to_vector(tags: dict[str, str]) -> np.ndarray:
    """タグ辞書 → 22次元 0/1 ベクトル。"""
    vec = np.zeros(TAG_DIM, dtype=float)
    for val in tags.values():
        if val in TAG_INDEX:
            vec[TAG_INDEX[val]] = 1.0
    return vec


_ITEM_TEXT_SQL = "SELECT item_code, item_name, catchcopy, item_caption, item_price FROM items"


def _tags_for_row(row) -> dict[str, str]:
    title = " ".join(filter(None, [row["item_name"], row["catchcopy"]]))
    return extract_tags(title, row["item_price"] or 0, row["item_caption"] or "")


def _save_vector(conn, item_code: str, tags: dict[str, str]) -> np.ndarray:
    """ベクトルとタグを保存する。辞書を変えたときに古いタグが残らないよう、タグは入れ替える。"""
    vec = tags_to_vector(tags)
    conn.execute(
        "INSERT OR REPLACE INTO item_vectors (item_code, vector_json) VALUES (?,?)",
        (item_code, json.dumps(vec.tolist())),
    )
    conn.execute("DELETE FROM item_tags WHERE item_code=?", (item_code,))
    conn.executemany(
        "INSERT INTO item_tags (item_code, tag_category, tag_value) VALUES (?,?,?)",
        [(item_code, cat, val) for cat, val in tags.items()],
    )
    return vec


def vectorize_item(item_code: str) -> np.ndarray | None:
    """DB の商品1件をベクトル化して保存し、ベクトルを返す。"""
    with get_conn() as conn:
        row = conn.execute(_ITEM_TEXT_SQL + " WHERE item_code=?", (item_code,)).fetchone()
        if not row:
            return None
        return _save_vector(conn, item_code, _tags_for_row(row))


def get_vector(item_code: str) -> np.ndarray | None:
    """キャッシュ済みベクトルを取得する（無ければ None）。"""
    with get_conn() as conn:
        row = conn.execute(
            "SELECT vector_json FROM item_vectors WHERE item_code=?", (item_code,)
        ).fetchone()
    return np.array(json.loads(row["vector_json"]), dtype=float) if row else None


def vectorize_all() -> int:
    """全商品をベクトル化して保存し、処理件数を返す。

    1つの接続・1回のコミットでまとめて処理する（商品ごとに接続を開いていたときは、1万2千件で約10秒かかっていた）。
    """
    with get_conn() as conn:
        rows = conn.execute(_ITEM_TEXT_SQL).fetchall()
        for row in rows:
            _save_vector(conn, row["item_code"], _tags_for_row(row))
    return len(rows)
