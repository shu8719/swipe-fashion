"""AI-01: 楽天商品テキスト → 22次元タグベクトル変換。"""
import json
import re
import numpy as np
from backend.db import get_conn

# ---- タグ定義（企画書3-1準拠 22次元）----
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


def extract_tags(text: str, item_price: int = 0) -> dict[str, str]:
    """テキストから 22次元タグ辞書 {category: value} を生成する。"""
    matched: dict[str, str] = {}
    cat_map = {
        "韓国系":"style","ストリート":"style","カジュアル":"style",
        "きれいめ":"style","モード":"style","ワーク":"style",
        "モノトーン":"color","アースカラー":"color","ビビッド":"color","ペールトーン":"color",
        "オーバーサイズ":"silhouette","スリム":"silhouette",
        "リラックス":"silhouette","タイト":"silhouette",
        "デニム":"material","ニット":"material","コットン":"material",
        "レザー":"material","シアー":"material",
    }
    for keywords, tag in _KEYWORD_MAP:
        if any(kw in text for kw in keywords):
            cat = cat_map.get(tag)
            if cat and cat not in matched:
                matched[cat] = tag

    # 価格帯（item_price が 0 のとき style フォールバック）
    if item_price > 0:
        if item_price < 3000:
            matched["price_range"] = "低"
        elif item_price <= 10000:
            matched["price_range"] = "中"
        else:
            matched["price_range"] = "高"
    else:
        matched["price_range"] = "中"

    # style がマッチしない場合のフォールバック
    if "style" not in matched:
        matched["style"] = "カジュアル"

    return matched


def tags_to_vector(tags: dict[str, str]) -> np.ndarray:
    """タグ辞書 → 22次元 0/1 ベクトル。"""
    vec = np.zeros(TAG_DIM, dtype=float)
    for val in tags.values():
        if val in TAG_INDEX:
            vec[TAG_INDEX[val]] = 1.0
    return vec


def vectorize_item(item_code: str) -> np.ndarray | None:
    """DB の商品を vectorize して item_vectors に保存し、ベクトルを返す。"""
    with get_conn() as conn:
        row = conn.execute(
            "SELECT item_name, catchcopy, item_caption, item_price FROM items WHERE item_code=?",
            (item_code,),
        ).fetchone()
    if not row:
        return None

    text = " ".join(filter(None, [row["item_name"], row["catchcopy"], row["item_caption"]]))
    tags = extract_tags(text, row["item_price"] or 0)
    vec  = tags_to_vector(tags)

    with get_conn() as conn:
        conn.execute(
            "INSERT OR REPLACE INTO item_vectors (item_code, vector_json) VALUES (?,?)",
            (item_code, json.dumps(vec.tolist())),
        )
        for cat, val in tags.items():
            conn.execute(
                "INSERT OR IGNORE INTO item_tags VALUES (?,?,?)",
                (item_code, cat, val),
            )
    return vec


def get_vector(item_code: str) -> np.ndarray | None:
    """キャッシュ済みベクトルを取得する（無ければ None）。"""
    with get_conn() as conn:
        row = conn.execute(
            "SELECT vector_json FROM item_vectors WHERE item_code=?", (item_code,)
        ).fetchone()
    return np.array(json.loads(row["vector_json"]), dtype=float) if row else None


def vectorize_all() -> int:
    """全商品をベクトル化して保存し、処理件数を返す。"""
    with get_conn() as conn:
        codes = [r["item_code"] for r in conn.execute("SELECT item_code FROM items").fetchall()]
    count = 0
    for code in codes:
        if vectorize_item(code) is not None:
            count += 1
    return count
