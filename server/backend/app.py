import os
from dotenv import load_dotenv
load_dotenv()

from flask import Flask
from backend.db import init_db, seed_dummy_items, load_rakuten_json_dir
from recommender.vectorizer import vectorize_all
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
    
    rakuten_json_dir = os.getenv("RAKUTEN_JSON_DIR", "")
    if rakuten_json_dir:
        loaded = load_rakuten_json_dir(rakuten_json_dir)
        if loaded > 0:
            print(f"ベクトル化開始...")
            vec_count = vectorize_all()
            print(f"ベクトル化完了: {vec_count}件")
    else:
        seed_dummy_items()
        print("DB初期化・ダミーデータ投入 完了やね")
    
    app = create_app()
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "5001"))
    print(f"Flask API 起動: http://{host}:{port}")
    app.run(host=host, port=port, debug=True)
