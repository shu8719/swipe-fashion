"""楽天API or sample_json フォールバックで商品DBを投入するスクリプト。
使い方: python -m backend.ingest.seed [--limit 30]
"""
import json
import os
import sys
import time
import argparse
from pathlib import Path

# プロジェクトルートをパスに追加
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from dotenv import load_dotenv
load_dotenv()

from backend.db import init_db, get_conn
from backend import config
from recommender.vectorizer import vectorize_item

_SAMPLE_FILES = [
    Path(__file__).parent.parent.parent / "FashionSwipe" / "sample_ladies.json",
    Path(__file__).parent.parent.parent / "FashionSwipe" / "sample_mens.json",
    Path(__file__).parent.parent.parent / "FashionSwipe" / "sample_onepiece.json",
]

_RAKUTEN_APP_ID    = os.getenv("RAKUTEN_APP_ID")
_RAKUTEN_ACCESS_KEY = os.getenv("RAKUTEN_ACCESS_KEY")
_RAKUTEN_AFFILIATE = os.getenv("RAKUTEN_AFFILIATE_ID", "")
_RAKUTEN_BASE_URL  = "https://openapi.rakuten.co.jp/ichibams/api/IchibaItem/Search/20260401"

_FASHION_KEYWORDS  = ["レディース トップス", "メンズ ジャケット", "ワンピース", "韓国系 ファッション"]


def _insert_item(item: dict):
    """楽天形式 dict を DB に投入し、ベクトル化する。"""
    item_code    = item.get("itemCode") or item.get("item_code", "")
    image_url    = ""
    urls         = item.get("mediumImageUrls") or []
    if urls:
        image_url = urls[0].get("imageUrl", "") if isinstance(urls[0], dict) else ""

    with get_conn() as conn:
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
    vectorize_item(item_code)


def seed_from_sample_json(limit: int = 200) -> int:
    """sample_*.json（frontend ブランチから取り込んだ楽天サンプルデータ）を投入する。"""
    count = 0
    for path in _SAMPLE_FILES:
        if not path.exists():
            print(f"  スキップ（ファイルなし）: {path}")
            continue
        data = json.loads(path.read_text())
        for wrapper in data.get("Items", []):
            item = wrapper.get("Item", wrapper)
            _insert_item(item)
            count += 1
            if count >= limit:
                return count
    return count


def seed_from_rakuten(hits_per_keyword: int = 30) -> int:
    """楽天APIから商品を取得して投入する（APIキー必要）。"""
    import requests
    count = 0
    for keyword in _FASHION_KEYWORDS:
        params = {
            "format": "json", "keyword": keyword, "genreId": 0,
            "applicationId": _RAKUTEN_APP_ID, "accessKey": _RAKUTEN_ACCESS_KEY,
            "hits": hits_per_keyword, "page": 1,
        }
        if _RAKUTEN_AFFILIATE:
            params["affiliateId"] = _RAKUTEN_AFFILIATE
        try:
            resp = requests.get(_RAKUTEN_BASE_URL, params=params,
                                headers={"User-Agent": "Mozilla/5.0"}, timeout=30)
            resp.raise_for_status()
            data = resp.json()
            for wrapper in data.get("Items", []):
                item = wrapper.get("Item", wrapper)
                _insert_item(item)
                count += 1
            print(f"  [{keyword}] {len(data.get('Items',[]))} 件取得")
        except Exception as e:
            print(f"  [{keyword}] エラー: {e}")
        time.sleep(1)
    return count


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=200)
    args = parser.parse_args()

    init_db()
    print("DB初期化完了")

    if _RAKUTEN_APP_ID and _RAKUTEN_ACCESS_KEY:
        print("楽天APIから取得中...")
        count = seed_from_rakuten(hits_per_keyword=30)
    else:
        print("APIキー未設定 → sample_json フォールバック")
        count = seed_from_sample_json(limit=args.limit)

    print(f"投入完了: {count} 件")
    with get_conn() as conn:
        n = conn.execute("SELECT COUNT(*) FROM items").fetchone()[0]
        nv = conn.execute("SELECT COUNT(*) FROM item_vectors").fetchone()[0]
    print(f"DB: items={n}, item_vectors={nv}")


if __name__ == "__main__":
    main()
