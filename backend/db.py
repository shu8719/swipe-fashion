import sqlite3
import os
from pathlib import Path
from backend import config

_SCHEMA = Path(__file__).parent / "schema.sql"


def get_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_db():
    sql = _SCHEMA.read_text()
    with get_conn() as conn:
        conn.executescript(sql)


def seed_dummy_items():
    """PoC用ダミー商品30件を投入する（累乗等でも再投入しても安全）。"""
    items = [
        (1,  "オーバーサイズTシャツ(黒)",  "ストリートブランドA", 2800, "https://via.placeholder.com/400?text=Item1",  "https://example.com/item/1",  [("style","ストリート"),("color","モノトーン"),("silhouette","オーバーサイズ"),("material","コットン"),("price_range","低")]),
        (2,  "スキニーデニム(インディゴ)",  "カジュアルブランドB", 5500, "https://via.placeholder.com/400?text=Item2",  "https://example.com/item/2",  [("style","カジュアル"),("color","アースカラー"),("silhouette","スリム"),("material","デニム"),("price_range","中")]),
        (3,  "韓国系フーディ(グレー)",      "韓国ブランドC",       3200, "https://via.placeholder.com/400?text=Item3",  "https://example.com/item/3",  [("style","韓国系"),("color","モノトーン"),("silhouette","リラックス"),("material","コットン"),("price_range","低")]),
        (4,  "きれいめチェスターコート",    "オフィスブランドD",  12000, "https://via.placeholder.com/400?text=Item4",  "https://example.com/item/4",  [("style","きれいめ"),("color","モノトーン"),("silhouette","スリム"),("material","ニット"),("price_range","高")]),
        (5,  "モードレザージャケット",      "セレクトショップE",  18000, "https://via.placeholder.com/400?text=Item5",  "https://example.com/item/5",  [("style","モード"),("color","モノトーン"),("silhouette","タイト"),("material","レザー"),("price_range","高")]),
        (6,  "アースカラーカーゴパンツ",    "アウトドアブランドF", 7800, "https://via.placeholder.com/400?text=Item6",  "https://example.com/item/6",  [("style","カジュアル"),("color","アースカラー"),("silhouette","リラックス"),("material","コットン"),("price_range","中")]),
        (7,  "ビビッドカラーニット",        "ポップブランドG",     4200, "https://via.placeholder.com/400?text=Item7",  "https://example.com/item/7",  [("style","ストリート"),("color","ビビッド"),("silhouette","オーバーサイズ"),("material","ニット"),("price_range","中")]),
        (8,  "ペールトーンシアーブラウス",  "ガーリーブランドH",   5900, "https://via.placeholder.com/400?text=Item8",  "https://example.com/item/8",  [("style","きれいめ"),("color","ペールトーン"),("silhouette","リラックス"),("material","シアー"),("price_range","中")]),
        (9,  "ストリートグラフィックT",    "ストリートブランドA", 2500, "https://via.placeholder.com/400?text=Item9",  "https://example.com/item/9",  [("style","ストリート"),("color","ビビッド"),("silhouette","オーバーサイズ"),("material","コットン"),("price_range","低")]),
        (10, "ワークシャツ(カーキ)",        "ワークブランドI",     6500, "https://via.placeholder.com/400?text=Item10", "https://example.com/item/10", [("style","ワーク"),("color","アースカラー"),("silhouette","リラックス"),("material","コットン"),("price_range","中")]),
        (11, "モノトーンスウェット",        "ミニマルブランドJ",   4800, "https://via.placeholder.com/400?text=Item11", "https://example.com/item/11", [("style","カジュアル"),("color","モノトーン"),("silhouette","オーバーサイズ"),("material","コットン"),("price_range","中")]),
        (12, "韓国系ワイドパンツ",          "韓国ブランドC",       4500, "https://via.placeholder.com/400?text=Item12", "https://example.com/item/12", [("style","韓国系"),("color","モノトーン"),("silhouette","リラックス"),("material","コットン"),("price_range","中")]),
        (13, "きれいめタートルニット",      "オフィスブランドD",   8800, "https://via.placeholder.com/400?text=Item13", "https://example.com/item/13", [("style","きれいめ"),("color","ペールトーン"),("silhouette","スリム"),("material","ニット"),("price_range","中")]),
        (14, "アースカラーリネンシャツ",    "ナチュラルブランドK", 5200, "https://via.placeholder.com/400?text=Item14", "https://example.com/item/14", [("style","カジュアル"),("color","アースカラー"),("silhouette","リラックス"),("material","コットン"),("price_range","中")]),
        (15, "モードシースルーブラウス",    "セレクトショップE",  11000, "https://via.placeholder.com/400?text=Item15", "https://example.com/item/15", [("style","モード"),("color","ペールトーン"),("silhouette","スリム"),("material","シアー"),("price_range","高")]),
        (16, "デニムジャケット(ライト)",    "カジュアルブランドB", 9800, "https://via.placeholder.com/400?text=Item16", "https://example.com/item/16", [("style","カジュアル"),("color","アースカラー"),("silhouette","リラックス"),("material","デニム"),("price_range","中")]),
        (17, "ビビッドカラーパーカー",      "ストリートブランドA", 5500, "https://via.placeholder.com/400?text=Item17", "https://example.com/item/17", [("style","ストリート"),("color","ビビッド"),("silhouette","オーバーサイズ"),("material","コットン"),("price_range","中")]),
        (18, "韓国系クロップドジャケット",  "韓国ブランドC",       7200, "https://via.placeholder.com/400?text=Item18", "https://example.com/item/18", [("style","韓国系"),("color","モノトーン"),("silhouette","タイト"),("material","コットン"),("price_range","中")]),
        (19, "ワークカーゴショーツ",        "ワークブランドI",     4900, "https://via.placeholder.com/400?text=Item19", "https://example.com/item/19", [("style","ワーク"),("color","アースカラー"),("silhouette","リラックス"),("material","コットン"),("price_range","中")]),
        (20, "ペールピンクニットベスト",    "ガーリーブランドH",   3800, "https://via.placeholder.com/400?text=Item20", "https://example.com/item/20", [("style","きれいめ"),("color","ペールトーン"),("silhouette","スリム"),("material","ニット"),("price_range","低")]),
        (21, "モードブラックスキニー",      "セレクトショップE",  13000, "https://via.placeholder.com/400?text=Item21", "https://example.com/item/21", [("style","モード"),("color","モノトーン"),("silhouette","タイト"),("material","デニム"),("price_range","高")]),
        (22, "アースカラーニットカーディガン","ナチュラルブランドK",6800, "https://via.placeholder.com/400?text=Item22", "https://example.com/item/22", [("style","カジュアル"),("color","アースカラー"),("silhouette","リラックス"),("material","ニット"),("price_range","中")]),
        (23, "韓国系ビッグシルエットシャツ","韓国ブランドC",       3500, "https://via.placeholder.com/400?text=Item23", "https://example.com/item/23", [("style","韓国系"),("color","アースカラー"),("silhouette","オーバーサイズ"),("material","コットン"),("price_range","低")]),
        (24, "ストリートバギーデニム",      "ストリートブランドA", 8200, "https://via.placeholder.com/400?text=Item24", "https://example.com/item/24", [("style","ストリート"),("color","モノトーン"),("silhouette","リラックス"),("material","デニム"),("price_range","中")]),
        (25, "きれいめワイドトラウザー",    "オフィスブランドD",   9500, "https://via.placeholder.com/400?text=Item25", "https://example.com/item/25", [("style","きれいめ"),("color","モノトーン"),("silhouette","リラックス"),("material","コットン"),("price_range","中")]),
        (26, "ビビッドグリーンコート",      "ポップブランドG",    16000, "https://via.placeholder.com/400?text=Item26", "https://example.com/item/26", [("style","モード"),("color","ビビッド"),("silhouette","オーバーサイズ"),("material","ニット"),("price_range","高")]),
        (27, "シアーロングスカート",        "ガーリーブランドH",   6200, "https://via.placeholder.com/400?text=Item27", "https://example.com/item/27", [("style","きれいめ"),("color","ペールトーン"),("silhouette","リラックス"),("material","シアー"),("price_range","中")]),
        (28, "レザーバイカーパンツ",        "セレクトショップE",  22000, "https://via.placeholder.com/400?text=Item28", "https://example.com/item/28", [("style","モード"),("color","モノトーン"),("silhouette","タイト"),("material","レザー"),("price_range","高")]),
        (29, "コットンワークオーバーオール","ワークブランドI",    11000, "https://via.placeholder.com/400?text=Item29", "https://example.com/item/29", [("style","ワーク"),("color","アースカラー"),("silhouette","リラックス"),("material","コットン"),("price_range","高")]),
        (30, "ペールイエローニットT",       "ナチュラルブランドK", 2900, "https://via.placeholder.com/400?text=Item30", "https://example.com/item/30", [("style","カジュアル"),("color","ペールトーン"),("silhouette","リラックス"),("material","ニット"),("price_range","低")]),
    ]
    with get_conn() as conn:
        for item in items:
            item_id, name, brand, price, image_url, external_url, tags = item
            conn.execute(
                "INSERT OR IGNORE INTO items VALUES (?,?,?,?,?,?)",
                (item_id, name, brand, price, image_url, external_url),
            )
            for cat, val in tags:
                conn.execute(
                    "INSERT OR IGNORE INTO item_tags VALUES (?,?,?)",
                    (item_id, cat, val),
                )
