# FashionSwipe — スワイプ型AIファッションレコメンドPoC

IPUT「AI社会応用 事例2」のPoC実装。商品画像をスワイプして好みを学習し、パーソナライズされた推薦を返すiOSアプリ + バックエンドAPI + 推薦エンジンの3層構成です。

このREADMEは **`frontend` ブランチ視点** で書かれています。`backend` ブランチを見る場合はそちらのREADMEを参照してください。

> **フロントエンドの実装を確認する場合は主に `FashionSwipe/` 配下を参照してください。**
> `backend/` と `recommender/` は同一リポジトリ内の別担当領域です。

---

## プロジェクト概要

- iOSフロント（SwiftUI）でスワイプUIを提供
- 商品データはローカルJSONをマニフェスト方式で管理（将来的にAPI連携へ移行）
- LIKE/SKIPの好み学習を経て、おすすめ商品を提示
- 3人体制で開発（フロント / バックエンド / 推薦エンジン）

---

## ブランチ構成

| ブランチ | 用途 |
|---|---|
| `backend` | Flask API + 推薦エンジン（デフォルトブランチ） |
| `frontend` | SwiftUI iOS アプリ（本READMEの対象） |
| `rakuten-api` | 楽天API連携の作業ブランチ |
| `integration` | 統合用ブランチ |
| `backup/frontend-before-replace` | 旧 frontend のバックアップ（参照のみ） |

---

## ディレクトリ構成

```
.
├── FashionSwipe/             # SwiftUI iOSアプリ本体
│   ├── FashionSwipeApp.swift # エントリーポイント
│   ├── ContentView.swift     # ルートTabView
│   ├── Models/
│   │   ├── Item.swift        # 商品データモデル
│   │   └── UserProfile.swift # プロフィール・カテゴリ/価格設定
│   ├── ViewModels/
│   │   └── SwipeViewModel.swift  # 状態管理・永続化・推薦計算
│   ├── Services/
│   │   └── MockDataService.swift # ローカルJSON読み込み
│   ├── Data/
│   │   ├── DataManifest.json     # カテゴリ別ファイル一覧
│   │   └── sample_*.json         # 商品データ（約440ファイル）
│   └── Views/
│       ├── Swipe/                # スワイプ画面 + 商品カード
│       ├── History/              # LIKE済み一覧 + 削除機能
│       ├── Recommendations/      # おすすめ画面（ローカル仮実装）
│       ├── Settings/             # プロフィール/フィルタ設定
│       └── Safari/               # 商品ページ表示
├── backend/                  # Flask API（担当B）
├── recommender/              # 推薦エンジン（担当A）
├── docs/api_spec.md          # API仕様書
└── CLAUDE.md                 # Claude Code向け開発ガイド
```

---

## frontend ブランチで実装済みの機能

| カテゴリ | 機能 |
|---|---|
| スワイプ | カードスタックUI / ドラッグ + ボタン操作 / アニメーション最適化 |
| データ永続化 | LIKE履歴をUserDefaultsに保存（アプリ再起動後も維持） |
| プロフィール | 表示名 / 好きなスタイル選択 / UserDefaults永続化 |
| フィルタ | カテゴリ（全て/レディース/メンズ）+ 価格帯（3区分） |
| データ管理 | DataManifest.json方式のJSON読み込み（Phase 2: 41ファイル分類済み） |
| おすすめ | LIKE件数別ローカル仮実装（パーソナライズ/カテゴリベースの2モード） |
| 履歴管理 | LIKE個別削除（contextMenu）+ 全削除（確認ダイアログ付き） |
| UX | 空状態UI改善 + 条件リセットボタン / 画像ロード感の軽減 |

詳細は `CLAUDE.md` を参照してください。

---

## 現在の状態（バックエンド接続前）

**現状はバックエンドAPIに接続していません。** ローカル完結のPoCとして動作する状態です。

| 項目 | 現状 |
|---|---|
| 商品データ取得 | `FashionSwipe/Data/` のローカルJSON |
| LIKE履歴 | UserDefaults（端末ローカル） |
| おすすめ計算 | ローカル仮実装（`SwipeViewModel.computeRecommendations`） |
| SKIP履歴 | 未保存（メモリ上のみ消費） |
| ユーザー認証 | 未実装 |

---

## 将来接続予定のAPI

`docs/api_spec.md` に準拠して接続する予定です。主要なエンドポイント:

| Method | Endpoint | 用途 | フロント側の差し替えポイント |
|---|---|---|---|
| GET | `/api/items/next` | スワイプ用商品一覧の取得 | `MockDataService.loadItems(for:)` |
| POST | `/api/actions` | LIKE / SKIP を送信 | `SwipeViewModel.like()` / `dislike()` |
| GET | `/api/recommend` | おすすめ商品の取得 | `SwipeViewModel.refreshRecommendations()` |
| POST | `/api/auth/login` | ログイン認証 | 新規 LoginView を追加予定 |
| GET | `/api/favorites` | LIKE一覧（サーバ側） | `HistoryView` のデータソース置換 |
| GET | `/api/taste` | 嗜好説明文 | `RecommendationsView` ヘッダーに表示 |

---

## フロント側のデータ構造

### `Item`（商品モデル）

| フィールド | 型 | 説明 |
|---|---|---|
| `itemCode` (= `id`) | String | 商品の一意ID |
| `itemName` | String | 商品名 |
| `itemPrice` | Int | 価格（円） |
| `mediumImageUrls[].imageUrl` | String | 画像URL |
| `itemUrl` | String | 商品ページURL |
| `shopName` | String | ショップ名 |
| `reviewAverage` | Double | レビュー平均 |
| `reviewCount` | Int | レビュー数 |
| `genreId` | Int | ジャンルID（推薦計算で使用） |

ソースは `FashionSwipe/Models/Item.swift`。

### `UserProfile`（ユーザー設定）

| フィールド | 型 | 値 |
|---|---|---|
| `displayName` | String | 自由入力 |
| `category` | enum | `all` / `ladies` / `mens` |
| `priceRange` | enum | `all` / `under3000` (≤3,000) / `from3000to10000` (3,001〜10,000) / `over10000` (>10,000) |
| `favoriteStyles` | [String] | スタイル名の配列（保存のみ） |

ソースは `FashionSwipe/Models/UserProfile.swift`。

---

## バックエンド担当へのお願い

### データ形式

- **`Item` のフィールド名は、できるだけフロントのモデルに合わせていただきたい**
  - 特に `itemCode` / `itemName` / `itemPrice` / `genreId` / `itemUrl`
  - 異なる場合は `MockDataService` 側でマッピング層を追加予定
- **画像URLは必須**（カードに画像が出ないと体験が成立しない）
- **商品ページURL（外部リンク）は必須**（SafariViewで開く）
- **`genreId` は推薦ロジックで活用したい**（同ジャンル一致で高スコア）

### アクションAPI

- LIKE / SKIP の両方を送信できるようにしたい
- `POST /api/actions` で `{ "item_id": ..., "action": "LIKE" | "SKIP" }` の形式を想定

### 推薦API

- 現在のおすすめ画面はローカル仮実装（LIKE済み商品の `genreId` と平均価格でスコアリング）
- **将来的に `GET /api/recommend` に置き換える前提**
- レスポンス形式は `Item[]` を想定（API仕様書通り）

---

## 主要ファイル早見表

| 役割 | ファイル |
|---|---|
| アプリ起動 | `FashionSwipe/FashionSwipeApp.swift` |
| タブ構成 | `FashionSwipe/ContentView.swift` |
| 状態管理（全画面共通） | `FashionSwipe/ViewModels/SwipeViewModel.swift` |
| 商品データ取得 | `FashionSwipe/Services/MockDataService.swift` |
| 商品分類マニフェスト | `FashionSwipe/Data/DataManifest.json` |
| スワイプ画面 | `FashionSwipe/Views/Swipe/` |
| 履歴・おすすめ・設定 | `FashionSwipe/Views/{History,Recommendations,Settings}/` |
| API仕様参照 | `docs/api_spec.md` |
| 開発ガイド | `CLAUDE.md` |

---

## 今後の予定

| 優先度 | 項目 |
|---|---|
| 高 | バックエンドAPI連携（認証 / 商品取得 / LIKE-SKIP送信 / 推薦取得） |
| 高 | ログイン・会員登録画面の追加 |
| 中 | SKIP履歴の保存（現在はメモリ上のみ） |
| 中 | DataManifest Phase 3（残り約400ファイルの分類） |
| 低 | 画像キャッシュ層の導入（AsyncImageの再取得を抑制） |
| 後回し | 嗜好説明文表示（`/api/taste`連携） |

---

## バックエンド側の起動方法（参考）

`backend` ブランチでの作業内容なので、本ブランチでは詳細を省きます。`backend` ブランチに切り替えてREADMEを参照してください。

```bash
git checkout backend
# 以下は backend ブランチの README に従う
```

API仕様の確認だけであれば `docs/api_spec.md` を参照してください。
