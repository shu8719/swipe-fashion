import os
import pytest


@pytest.fixture(autouse=True)
def use_temp_db(monkeypatch, tmp_path):
    db_file = str(tmp_path / "test.sqlite3")
    monkeypatch.setenv("DB_PATH", db_file)
    monkeypatch.setenv("LLM_PROVIDER", "mock")

    import backend.config as cfg
    monkeypatch.setattr(cfg, "DB_PATH", db_file)
    monkeypatch.setattr(cfg, "LLM_PROVIDER", "mock")

    from backend.db import init_db, seed_dummy_items
    init_db()
    seed_dummy_items()
    yield


@pytest.fixture
def app():
    from backend.app import create_app
    application = create_app()
    application.config["TESTING"] = True
    return application


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def auth_client(client):
    resp = client.post("/api/auth/register", json={
        "email": "test@example.com", "password": "pass1234",
        "age": 20, "gender": "男性", "region": "大阪",
    })
    token = resp.get_json()["token"]

    class _AuthClient:
        def get(self, url, **kw):
            kw.setdefault("headers", {})["Authorization"] = f"Bearer {token}"
            return client.get(url, **kw)
        def post(self, url, **kw):
            kw.setdefault("headers", {})["Authorization"] = f"Bearer {token}"
            return client.post(url, **kw)

    return _AuthClient()
