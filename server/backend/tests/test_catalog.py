"""楽天 JSON の読み込みと、アプリに載せている商品（app_catalog）のテスト。"""
import json
from backend.db import get_conn, load_rakuten_json_dir


def _write(path, codes):
    items = [{"Item": {"itemCode": c, "itemName": c, "itemPrice": 1000,
                       "mediumImageUrls": [{"imageUrl": "https://example.com/a.jpg"}]}} for c in codes]
    path.write_text(json.dumps({"Items": items}), encoding="utf-8")


def test_app_catalog_follows_manifest(tmp_path):
    _write(tmp_path / "sample_in_app.json", ["shop:a", "shop:b"])
    _write(tmp_path / "sample_server_only.json", ["shop:c"])
    (tmp_path / "DataManifest.json").write_text(
        json.dumps({"version": 1, "categories": {"ladies": ["sample_in_app"]}}), encoding="utf-8")

    assert load_rakuten_json_dir(str(tmp_path)) == 3
    with get_conn() as conn:
        codes = {r["item_code"] for r in conn.execute("SELECT item_code FROM app_catalog")}
    assert codes == {"shop:a", "shop:b"}


def test_app_catalog_empty_without_manifest(tmp_path):
    _write(tmp_path / "sample_x.json", ["shop:x"])
    load_rakuten_json_dir(str(tmp_path))
    with get_conn() as conn:
        assert conn.execute("SELECT COUNT(*) FROM app_catalog").fetchone()[0] == 0
