# スワイプ型AIファッションレコメンド PoC

IPUT「AI社会応用 事例2」の PoC 実装。3人体制で技術分担しています。

## 担当分け

| 担当 | 内容 |
|---|---|
| 担当A | DB設計 + 推薦エンジン（ベクトル変換・コサイン類似度） |
| **担当B（このブランチ）** | K-meansクラスタリング + Gemma嗜好説明生成 + Flask API |
| 担当C | Swift iOSフロントエンド（スワイプUI） |

## 構成

```
backend/      # 担当B主担当: Flask API + AI
recommender/  # 担当A主担当: 推薦エンジン（B は import のみ）
docs/         # API仕様書（担当C向け）
```

## セットアップ

```bash
git clone https://github.com/Hayasaka0402/swipe-fashion-ai.git
cd swipe-fashion-ai
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

cp .env.example .env  # 必要に応じて編集
```

## 起動

```bash
# DB初期化 + ダミーデータ投入 + サーバ起動（全部まとめて）
python backend/app.py
```

サーバは `http://localhost:5000` で起動します。

## テスト

```bash
pytest backend/tests/ -v
```

## K-meansバッチ（手動）

```bash
python -m backend.jobs.weekly_cluster --clusters 4
```

## LLMプロバイダ切替（.env）

```
LLM_PROVIDER=ollama   # ローカルOllamaを使う（デフォルト）
LLM_PROVIDER=mock     # テスト用モック返答
LLM_PROVIDER=gemini   # 本番Gemini API
```

Ollama使用時は `ollama serve` を先に起動してください。

## API仕様

`docs/api_spec.md` を参照してください。
