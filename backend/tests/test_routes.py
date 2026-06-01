"""Flask ルートの基本動作テスト（楽天スキーマ版）。"""


def test_health(client):
    assert client.get("/health").get_json()["status"] == "ok"


class TestAuth:
    def test_register(self, client):
        resp = client.post("/api/auth/register", json={"email":"new@ex.com","password":"pw123","age":22})
        assert resp.status_code == 201
        assert "token" in resp.get_json()

    def test_register_duplicate(self, client):
        pl = {"email":"dup@ex.com","password":"pw"}
        client.post("/api/auth/register", json=pl)
        assert client.post("/api/auth/register", json=pl).status_code == 409

    def test_login(self, client):
        client.post("/api/auth/register", json={"email":"u@x.com","password":"pw"})
        assert client.post("/api/auth/login", json={"email":"u@x.com","password":"pw"}).status_code == 200

    def test_login_fail(self, client):
        client.post("/api/auth/register", json={"email":"u2@x.com","password":"pw"})
        assert client.post("/api/auth/login", json={"email":"u2@x.com","password":"wrong"}).status_code == 401

    def test_device_auth_creates_user(self, client):
        resp = client.post("/api/auth/device", json={"device_id": "test-uuid-1234"})
        assert resp.status_code == 200
        d = resp.get_json()
        assert "token" in d and "user_id" in d

    def test_device_auth_idempotent(self, client):
        r1 = client.post("/api/auth/device", json={"device_id": "uuid-abc"}).get_json()
        r2 = client.post("/api/auth/device", json={"device_id": "uuid-abc"}).get_json()
        assert r1["user_id"] == r2["user_id"]

    def test_no_token_rejected(self, client):
        assert client.get("/api/items/next").status_code == 401


class TestItems:
    def test_next_items_rakuten_shape(self, auth_client):
        resp = auth_client.get("/api/items/next?limit=5")
        assert resp.status_code == 200
        items = resp.get_json()
        assert isinstance(items, list)
        assert len(items) <= 5
        if items:
            item = items[0]
            assert "itemCode" in item
            assert "itemName" in item
            assert "itemPrice" in item
            assert "mediumImageUrls" in item
            assert isinstance(item["mediumImageUrls"], list)

    def test_item_detail(self, auth_client):
        resp = auth_client.get("/api/items/dummy:item0001")
        assert resp.status_code == 200
        assert resp.get_json()["itemCode"] == "dummy:item0001"

    def test_item_not_found(self, auth_client):
        assert auth_client.get("/api/items/no:such:item").status_code == 404


class TestActions:
    def test_like(self, auth_client):
        resp = auth_client.post("/api/actions", json={"item_code":"dummy:item0001","action":"LIKE"})
        assert resp.status_code == 200
        assert resp.get_json()["ok"] is True

    def test_skip(self, auth_client):
        resp = auth_client.post("/api/actions", json={"item_code":"dummy:item0002","action":"SKIP"})
        assert resp.status_code == 200

    def test_invalid_action(self, auth_client):
        assert auth_client.post("/api/actions", json={"item_code":"dummy:item0001","action":"MAYBE"}).status_code == 400

    def test_liked_excluded_from_next(self, auth_client):
        auth_client.post("/api/actions", json={"item_code":"dummy:item0001","action":"LIKE"})
        codes = [i["itemCode"] for i in auth_client.get("/api/items/next?limit=30").get_json()]
        assert "dummy:item0001" not in codes


class TestRecommend:
    def test_recommend_list(self, auth_client):
        assert isinstance(auth_client.get("/api/recommend").get_json(), list)

    def test_recommend_has_score(self, auth_client):
        items = auth_client.get("/api/recommend").get_json()
        if items:
            assert "score" in items[0]


class TestFavorites:
    def test_empty_at_first(self, auth_client):
        assert auth_client.get("/api/favorites").get_json() == []

    def test_after_like(self, auth_client):
        auth_client.post("/api/actions", json={"item_code":"dummy:item0001","action":"LIKE"})
        codes = [i["itemCode"] for i in auth_client.get("/api/favorites").get_json()]
        assert "dummy:item0001" in codes


class TestTaste:
    def test_taste_shape(self, auth_client):
        d = auth_client.get("/api/taste").get_json()
        assert "description" in d and "updated_at" in d

    def test_taste_after_likes(self, auth_client):
        for i in range(1, 11):
            auth_client.post("/api/actions", json={"item_code": f"dummy:item{i:04d}", "action":"LIKE"})
        d = auth_client.get("/api/taste").get_json()
        assert d["description"] is not None
