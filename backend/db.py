import sqlite3
from pathlib import Path
import json
import os
from backend import config

_SCHEMA = Path(__file__).parent / "schema.sql"

_DUMMY_ITEMS = [
    {"code": f"dummy:item{i:04d}", "name": n, "catch": c, "cap": cap, "price": p,
     "shop": f"テストショップ{i%5}", "url": f"https://example.com/item/{i}",
     "img": f"https://via.placeholder.com/400?text=Item{i}", "genre": 100000, "tags": t}
    for i, (n, c, cap, p, t) in enumerate([
        ("テスト韓国系Tシャツ",  "韓国系 オーバーサイズ 黒 モノトーン", "韓国系 モノトーン オーバーサイズ コットン", 2800, [("style","韓国系"),("color","モノトーン"),("silhouette","オーバーサイズ"),("material","コットン"),("price_range","低")]),
        ("テストスリムデニム",    "カジュアル スリム デニム インディゴ", "カジュアル スリム デニム アースカラー", 5500, [("style","カジュアル"),("color","アースカラー"),("silhouette","スリム"),("material","デニム"),("price_range","中")]),
        ("テスト韓国フーディ",   "韓国系 ゆったり グレー フード リラックス", "韓国系 モノトーン リラックス コットン", 3200, [("style","韓国系"),("color","モノトーン"),("silhouette","リラックス"),("material","コットン"),("price_range","低")]),
        ("テストきれいめコート", "きれいめ チェスター オフィス ビジカジ", "きれいめ モノトーン スリム ニット", 12000, [("style","きれいめ"),("color","モノトーン"),("silhouette","スリム"),("material","ニット"),("price_range","高")]),
        ("テストモードレザー",   "モード レザー タイト 黒 ビビッド", "モード モノトーン タイト レザー", 18000, [("style","モード"),("color","モノトーン"),("silhouette","タイト"),("material","レザー"),("price_range","高")]),
        ("テストカーゴパンツ",   "ワーク カーゴ アースカラー カーキ", "ワーク アースカラー リラックス コットン", 7800, [("style","ワーク"),("color","アースカラー"),("silhouette","リラックス"),("material","コットン"),("price_range","中")]),
        ("テストビビッドニット", "ストリート ビビッド カラー オーバーサイズ", "ストリート ビビッド オーバーサイズ ニット", 4200, [("style","ストリート"),("color","ビビッド"),("silhouette","オーバーサイズ"),("material","ニット"),("price_range","中")]),
        ("テストシアーブラウス", "きれいめ ペールトーン シアー リラックス", "きれいめ ペールトーン リラックス シアー", 5900, [("style","きれいめ"),("color","ペールトーン"),("silhouette","リラックス"),("material","シアー"),("price_range","中")]),
        ("テストグラフィックT",  "ストリート ビビッド グラフィック オーバーサイズ", "ストリート ビビッド オーバーサイズ コットン", 2500, [("style","ストリート"),("color","ビビッド"),("silhouette","オーバーサイズ"),("material","コットン"),("price_range","低")]),
        ("テストワークシャツ",   "ワーク カーキ アウトドア リラックス", "ワーク アースカラー リラックス コットン", 6500, [("style","ワーク"),("color","アースカラー"),("silhouette","リラックス"),("material","コットン"),("price_range","中")]),
        ("テストスウェット",     "カジュアル モノトーン オーバーサイズ", "カジュアル モノトーン オーバーサイズ コットン", 4800, [("style","カジュアル"),("color","モノトーン"),("silhouette","オーバーサイズ"),("material","コットン"),("price_range","中")]),
        ("テストワイドパンツ",   "韓国系 モノトーン ワイド リラックス", "韓国系 モノトーン リラックス コットン", 4500, [("style","韓国系"),("color","モノトーン"),("silhouette","リラックス"),("material","コットン"),("price_range","中")]),
        ("テストタートルニット", "きれいめ ペール ニット スリム", "きれいめ ペールトーン スリム ニット", 8800, [("style","きれいめ"),("color","ペールトーン"),("silhouette","スリム"),("material","ニット"),("price_range","中")]),
        ("テストリネンシャツ",   "カジュアル アースカラー リネン リラックス", "カジュアル アースカラー リラックス コットン", 5200, [("style","カジュアル"),("color","アースカラー"),("silhouette","リラックス"),("material","コットン"),("price_range","中")]),
        ("テストシースルー",     "モード ペール シアー スリム", "モード ペールトーン スリム シアー", 11000, [("style","モード"),("color","ペールトーン"),("silhouette","スリム"),("material","シアー"),("price_range","高")]),
        ("テストデニムジャケット","カジュアル デニム アースカラー リラックス", "カジュアル アースカラー リラックス デニム", 9800, [("style","カジュアル"),("color","アースカラー"),("silhouette","リラックス"),("material","デニム"),("price_range","中")]),
        ("テストビビッドパーカー","ストリート ビビッド オーバーサイズ フード", "ストリート ビビッド オーバーサイズ コットン", 5500, [("style","ストリート"),("color","ビビッド"),("silhouette","オーバーサイズ"),("material","コットン"),("price_range","中")]),
        ("テストクロップジャケット","韓国系 モノトーン タイト クロップ", "韓国系 モノトーン タイト コットン", 7200, [("style","韓国系"),("color","モノトーン"),("silhouette","タイト"),("material","コットン"),("price_range","中")]),
        ("テストカーゴショーツ", "ワーク カーキ アースカラー ショーツ", "ワーク アースカラー リラックス コットン", 4900, [("style","ワーク"),("color","アースカラー"),("silhouette","リラックス"),("material","コットン"),("price_range","中")]),
        ("テストニットベスト",   "きれいめ ペール ピンク ニットベスト", "きれいめ ペールトーン スリム ニット", 3800, [("style","きれいめ"),("color","ペールトーン"),("silhouette","スリム"),("material","ニット"),("price_range","低")]),
        ("テストスキニー黒",     "モード モノトーン スキニー タイト", "モード モノトーン タイト デニム", 13000, [("style","モード"),("color","モノトーン"),("silhouette","タイト"),("material","デニム"),("price_range","高")]),
        ("テストカーディガン",   "カジュアル アースカラー ニット リラックス", "カジュアル アースカラー リラックス ニット", 6800, [("style","カジュアル"),("color","アースカラー"),("silhouette","リラックス"),("material","ニット"),("price_range","中")]),
        ("テストビッグシャツ",   "韓国系 アースカラー オーバーサイズ ビッグ", "韓国系 アースカラー オーバーサイズ コットン", 3500, [("style","韓国系"),("color","アースカラー"),("silhouette","オーバーサイズ"),("material","コットン"),("price_range","低")]),
        ("テストバギーデニム",   "ストリート モノトーン リラックス バギー", "ストリート モノトーン リラックス デニム", 8200, [("style","ストリート"),("color","モノトーン"),("silhouette","リラックス"),("material","デニム"),("price_range","中")]),
        ("テストワイドトラウザー","きれいめ モノトーン ワイド リラックス", "きれいめ モノトーン リラックス コットン", 9500, [("style","きれいめ"),("color","モノトーン"),("silhouette","リラックス"),("material","コットン"),("price_range","中")]),
        ("テストビビッドコート", "モード ビビッド グリーン オーバーサイズ", "モード ビビッド オーバーサイズ ニット", 16000, [("style","モード"),("color","ビビッド"),("silhouette","オーバーサイズ"),("material","ニット"),("price_range","高")]),
        ("テストシアースカート", "きれいめ ペール シアー ロング", "きれいめ ペールトーン リラックス シアー", 6200, [("style","きれいめ"),("color","ペールトーン"),("silhouette","リラックス"),("material","シアー"),("price_range","中")]),
        ("テストレザーパンツ",   "モード モノトーン タイト レザー バイカー", "モード モノトーン タイト レザー", 22000, [("style","モード"),("color","モノトーン"),("silhouette","タイト"),("material","レザー"),("price_range","高")]),
        ("テストオーバーオール", "ワーク アースカラー コットン リラックス", "ワーク アースカラー リラックス コットン", 11000, [("style","ワーク"),("color","アースカラー"),("silhouette","リラックス"),("material","コットン"),("price_range","高")]),
        ("テストニットT",        "カジュアル ペール イエロー ニット", "カジュアル ペールトーン リラックス ニット", 2900, [("style","カジュアル"),("color","ペールトーン"),("silhouette","リラックス"),("material","ニット"),("price_range","低")]),
    ], start=1)
]


from contextlib import contextmanager

@contextmanager
def get_conn():
    """sqlite3接続を返すコンテキストマネージャ（退出時に自動コミット＋クローズ）。"""
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db():
    sql = _SCHEMA.read_text()
    with get_conn() as conn:
        conn.executescript(sql)


def seed_dummy_items():
    """テスト用ダミー商品30件を投入する（pytest conftest から呼ばれる）。"""
    with get_conn() as conn:
        for item in _DUMMY_ITEMS:
            conn.execute(
                """INSERT OR IGNORE INTO items
                   (item_code, item_name, catchcopy, item_caption, item_price,
                    shop_name, review_average, review_count, item_url, image_url, genre_id)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
                (item["code"], item["name"], item["catch"], item["cap"],
                 item["price"], item["shop"], 4.0, 10,
                 item["url"], item["img"], item["genre"]),
            )
            for cat, val in item["tags"]:
                conn.execute(
                    "INSERT OR IGNORE INTO item_tags VALUES (?,?,?)",
                    (item["code"], cat, val),
                )


def load_rakuten_json_dir(json_dir: str) -> int:
    """楽天API形式のJSONディレクトリから商品をDBに投入する。
    
    Args:
        json_dir: JSONファイルが格納されたディレクトリパス
    
    Returns:
        投入件数
    """
    json_path = Path(json_dir)
    if not json_path.exists():
        print(f"ディレクトリが見つかりません: {json_dir}")
        return 0
    
    json_files = sorted(json_path.glob("*.json"))
    if not json_files:
        print(f"JSONファイルが見つかりません: {json_dir}")
        return 0
    
    count = 0
    with get_conn() as conn:
        for jf in json_files:
            try:
                with open(jf, encoding="utf-8") as f:
                    data = json.load(f)
            except Exception as e:
                print(f"読み込みエラー {jf.name}: {e}")
                continue
            
            items = data.get("Items", [])
            for wrapper in items:
                item = wrapper.get("Item", {})
                item_code = item.get("itemCode", "")
                if not item_code:
                    continue
                
                # mediumImageUrls から最初の画像URLを取得
                image_url = ""
                medium_urls = item.get("mediumImageUrls", [])
                if medium_urls and isinstance(medium_urls[0], dict):
                    image_url = medium_urls[0].get("imageUrl", "")
                
                conn.execute(
                    """INSERT OR IGNORE INTO items
                       (item_code, item_name, catchcopy, item_caption, item_price,
                        shop_name, review_average, review_count, item_url, image_url, genre_id)
                       VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
                    (
                        item_code,
                        item.get("itemName", ""),
                        item.get("catchcopy", ""),
                        item.get("itemCaption", ""),
                        item.get("itemPrice", 0),
                        item.get("shopName", ""),
                        item.get("reviewAverage", 0.0),
                        item.get("reviewCount", 0),
                        item.get("itemUrl", ""),
                        image_url,
                        item.get("genreId", 0),
                    ),
                )
                count += 1
    
    print(f"楽天JSON投入完了: {count}件 ({len(json_files)}ファイル)")
    return count
