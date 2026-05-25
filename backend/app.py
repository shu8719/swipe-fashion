import os
from dotenv import load_dotenv
load_dotenv()

from flask import Flask
from backend.db import init_db, seed_dummy_items
from backend.routes.auth_routes import bp as auth_bp
from backend.routes.items import bp as items_bp
from backend.routes.actions import bp as actions_bp
from backend.routes.recommend import bp as recommend_bp
from backend.routes.taste import bp as taste_bp
from backend.routes.favorites import bp as favorites_bp


def create_app() -> Flask:
    app = Flask(__name__)
    app.config["SECRET_KEY"] = os.getenv("SECRET_KEY", "dev_secret_key")

    for bp in [auth_bp, items_bp, actions_bp, recommend_bp, taste_bp, favorites_bp]:
        app.register_blueprint(bp)

    @app.get("/health")
    def health():
        return {"status": "ok"}

    return app


if __name__ == "__main__":
    init_db()
    seed_dummy_items()
    print("DB初期化・ダミーデータ投入 完了やね")
    app = create_app()
    app.run(host="0.0.0.0", port=5000, debug=True)
