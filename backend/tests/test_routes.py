"""Flask ルートの基本動作テスト。"""


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "ok"


class TestAuth:
    def test_register_success(self, client):
        resp = client.post("/api/auth/register", json={
            "email": "new@example.com",
            "password": "password123",
            "age": 22,
        })
        assert resp.status_code == 201
        data = resp.get_json()
        assert "token" in data
        assert "user_id" in data

    def test_register_duplicate(self, client):
        payload = {"email": "dup@example.com", "password": "pass"}
        client.post("/api/auth/register", json=payload)
        resp = client.post("/api/auth/register", json=payload)
        assert resp.status_code == 409

    def test_login_success(self, client):
        client.post("/api/auth/register", json={"email": "u@x.com", "password": "pw"})
        resp = client.post("/api/auth/login", json={"email": "u@x.com", "password": "pw"})
        assert resp.status_code == 200
        assert "token" in resp.get_json()

    def test_login_wrong_password(self, client):
        client.post("/api/auth/register", json={"email": "u2@x.com", "password": "pw"})
        resp = client.post("/api/auth/login", json={"email": "u2@x.com", "password": "wrong"})
        assert resp.status_code == 401

    def test_no_token_rejected(self, client):
        resp = client.get("/api/items/next")
        assert resp.status_code == 401


class TestItems:
    def test_next_items(self, auth_client):
        resp = auth_client.get("/api/items/next?limit=5")
        assert resp.status_code == 200
        data = resp.get_json()
        assert isinstance(data, list)
        assert len(data) <= 5
        assert all("item_id" in i for i in data)

    def test_item_detail(self, auth_client):
        resp = auth_client.get("/api/items/1")
        assert resp.status_code == 200
        assert resp.get_json()["item_id"] == 1

    def test_item_not_found(self, auth_client):
        resp = auth_client.get("/api/items/99999")
        assert resp.status_code == 404


class TestActions:
    def test_like(self, auth_client):
        resp = auth_client.post("/api/actions", json={"item_id": 1, "action": "LIKE"})
        assert resp.status_code == 200
        assert resp.get_json()["ok"] is True

    def test_skip(self, auth_client):
        resp = auth_client.post("/api/actions", json={"item_id": 2, "action": "SKIP"})
        assert resp.status_code == 200

    def test_invalid_action(self, auth_client):
        resp = auth_client.post("/api/actions", json={"item_id": 1, "action": "INVALID"})
        assert resp.status_code == 400

    def test_liked_item_excluded_from_next(self, auth_client):
        auth_client.post("/api/actions", json={"item_id": 1, "action": "LIKE"})
        resp = auth_client.get("/api/items/next?limit=30")
        item_ids = [i["item_id"] for i in resp.get_json()]
        assert 1 not in item_ids


class TestRecommend:
    def test_recommend_returns_list(self, auth_client):
        resp = auth_client.get("/api/recommend")
        assert resp.status_code == 200
        assert isinstance(resp.get_json(), list)

    def test_recommend_has_score(self, auth_client):
        resp = auth_client.get("/api/recommend")
        items = resp.get_json()
        if items:
            assert "score" in items[0]


class TestFavorites:
    def test_favorites_empty_at_first(self, auth_client):
        resp = auth_client.get("/api/favorites")
        assert resp.status_code == 200
        assert resp.get_json() == []

    def test_favorites_after_like(self, auth_client):
        auth_client.post("/api/actions", json={"item_id": 1, "action": "LIKE"})
        resp = auth_client.get("/api/favorites")
        ids = [i["item_id"] for i in resp.get_json()]
        assert 1 in ids


class TestTaste:
    def test_taste_returns_dict(self, auth_client):
        resp = auth_client.get("/api/taste")
        assert resp.status_code == 200
        data = resp.get_json()
        assert "description" in data
        assert "updated_at" in data

    def test_taste_description_after_enough_likes(self, auth_client):
        for item_id in range(1, 11):
            auth_client.post("/api/actions", json={"item_id": item_id, "action": "LIKE"})
        resp = auth_client.get("/api/taste")
        data = resp.get_json()
        assert data["description"] is not None
