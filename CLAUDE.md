# CLAUDE.md — FashionSwipe プロジェクト概要

このファイルはClaude Codeがプロジェクトを理解するための参照ドキュメントです。
作業前に必ずこのファイルを読んでください。

---

## プロジェクト名

**FashionSwipe**

---

## アプリ概要

スワイプ型のAIファッションレコメンドiOSアプリ。

- 商品画像をカード形式で表示する
- 右スワイプ（または♡ボタン）→ LIKE
- 左スワイプ（または✕ボタン）→ SKIP
- LIKEした商品をもとに、好みを学習してパーソナライズされたおすすめを表示
- 商品データは楽天市場APIのレスポンスをローカルJSONで保持

---

## 現在の実装状況（2026年6月時点）

| 機能 | 状態 |
|---|---|
| スワイプUI（ドラッグ・ボタン） | 実装済み |
| 商品カード表示 | 実装済み |
| LIKE/SKIP操作 | 実装済み |
| LIKE履歴のUserDefaults永続化 | 実装済み |
| 履歴画面（2列グリッド） | 実装済み |
| 履歴の個別削除（contextMenu） | 実装済み |
| 履歴の一括削除（確認ダイアログ付き） | 実装済み |
| 商品URLをSafariで開く | 実装済み |
| プロフィール設定（表示名・スタイル） | 実装済み |
| カテゴリフィルタ（すべて/レディース/メンズ） | 実装済み |
| 価格フィルタ（〜¥3,000 / ¥3,000〜¥10,000 / ¥10,000〜） | 実装済み |
| スタイル選択（保存のみ） | 実装済み |
| プロフィールのUserDefaults永続化 | 実装済み |
| DataManifest方式のJSON読み込み | 実装済み（Phase 2: 41ファイル） |
| 重複ID除去（id ベースの一意化） | 実装済み |
| 空状態UI改善 + 条件リセットボタン | 実装済み |
| おすすめ画面（ローカル仮実装） | 実装済み |
| スワイプアニメーション改善（.id + 順序調整） | 実装済み |
| AsyncImageのProgressView削除 | 実装済み |
| API連携（バックエンド接続） | 未実装 |
| ユーザー認証（ログイン画面など） | 未実装 |
| バックエンド推薦（GET /api/recommend） | 未実装 |
| SKIP履歴の保存 | 未実装 |
| 嗜好説明文の表示 | 未実装 |
| 画像キャッシュ層 | 未実装 |

### 重要な仕様まとめ

- **LIKE 3件以上**でおすすめが「パーソナライズモード（ジャンル一致+価格類似）」に切り替わる
- **LIKE 2件以下**ではおすすめは「カテゴリベース（現在の設定でランダム20件）」
- **価格帯**は3区分: `〜¥3,000` (≤3,000) / `¥3,000〜¥10,000` (3,001〜10,000) / `¥10,000〜` (>10,000)
- **DataManifest Phase 2** で41ファイル分類済み。残り約400ファイル分類は **後回し**
- **SKIP操作はメモリ上で消えるのみ**で履歴保存はされない（将来対応）
- **本番推薦APIはまだ未実装**で、おすすめ画面はローカル仮実装

---

## ディレクトリ構成

```
FashionSwipe/                        ← iOSアプリ本体（作業対象）
├── FashionSwipeApp.swift            ← アプリのエントリーポイント
├── ContentView.swift                ← ルート画面（4タブのTabView）
├── Models/
│   ├── Item.swift                   ← 商品データモデル（Codable対応済み）
│   └── UserProfile.swift            ← プロフィール・カテゴリ/価格 enum
├── ViewModels/
│   └── SwipeViewModel.swift         ← 状態管理・永続化・おすすめ計算
├── Services/
│   └── MockDataService.swift        ← DataManifest経由のJSON読み込み
├── Data/                            ← 商品JSON + DataManifest
│   ├── DataManifest.json            ← カテゴリ別ファイル名一覧
│   ├── sample_ladies.json
│   ├── sample_mens.json
│   ├── sample_onepiece.json
│   └── sample_*.json (約440ファイル、うち41ファイルがmanifest登録済み)
├── Views/
│   ├── Swipe/
│   │   ├── SwipeView.swift          ← メインのスワイプ画面 + 空状態UI
│   │   └── CardView.swift           ← 商品カードUI（プレースホルダー無感化済み）
│   ├── History/
│   │   └── HistoryView.swift        ← LIKE済み一覧 + 個別削除 + 一括削除
│   ├── Recommendations/
│   │   └── RecommendationsView.swift ← おすすめ画面（ローカル仮実装）
│   ├── Settings/
│   │   └── SettingsView.swift       ← プロフィール/カテゴリ/価格/スタイル
│   └── Safari/
│       └── SafariView.swift         ← SFSafariViewControllerのラッパー

docs/
└── api_spec.md                      ← バックエンドAPI仕様書（参照用）
```

---

## アーキテクチャ

**MVVM（Model-View-ViewModel）パターン**を採用。

```
Model        Item.swift / UserProfile.swift     データ構造
ViewModel    SwipeViewModel.swift               状態・永続化・推薦計算
View         Views/ 配下すべて                  画面表示
Service      MockDataService.swift              データ取得（DataManifest経由）
```

- `SwipeViewModel` は `@MainActor` + `ObservableObject`
- `FashionSwipeApp` でインスタンス化し、`@EnvironmentObject` で全画面に注入
- 状態は `@Published private(set)` で管理し、Viewは自動更新
- データ更新は ViewModel メソッド経由でのみ可能

---

## 主要ファイルの役割

### `Models/Item.swift`
楽天APIのレスポンス形式に対応した商品モデル。`Codable` 準拠で UserDefaults / JSON 保存・読み込みに対応。

| プロパティ | 内容 |
|---|---|
| `itemCode` | 一意ID（`id` プロパティとして公開） |
| `itemName` / `cleanName` | 商品名（cleanNameは【】タグ除去版） |
| `itemPrice` | 価格 |
| `genreId` | ジャンルID（おすすめ計算で使用） |
| `largeImageUrl` | 600x600 にリサイズした画像URL |
| `productUrl` | 商品ページURL |

### `Models/UserProfile.swift`
プロフィール設定のデータ構造。`Codable` + `Equatable` 準拠。

| 要素 | 内容 |
|---|---|
| `displayName: String` | 表示名（自由入力） |
| `category: Category` | `.all` / `.ladies` / `.mens` |
| `priceRange: PriceRange` | `.all` / `.under3000` / `.from3000to10000` / `.over10000` |
| `favoriteStyles: [String]` | 選択中のスタイル（保存のみ・フィルタ非適用） |

`PriceRange.matches(price:)` で価格判定を集約。

### `ViewModels/SwipeViewModel.swift`
アプリ全体の状態を管理する中心ファイル。

| プロパティ | 役割 |
|---|---|
| `cards: [Item]` | スワイプ候補リスト |
| `likedItems: [Item]` | LIKE済み（UserDefaults永続化） |
| `profile: UserProfile` | プロフィール設定（UserDefaults永続化） |
| `recommendedItems: [Item]` | おすすめ商品リスト |
| `displayCards: [Item]` | 表示用（先頭3枚） |

| 関数 | 役割 |
|---|---|
| `like()` / `dislike()` | スワイプ処理 |
| `unlike(item:)` / `clearAllLikes()` | LIKE削除 |
| `updateProfile(_:)` / `resetFilters()` | プロフィール更新 |
| `refreshRecommendations()` | おすすめ再計算（init/like/profile変更時に発火） |
| `replenishIfNeeded()` | カード補充（既存IDとの重複を排除） |

UserDefaultsキー: `"likedItems"` / `"userProfile"`

### `Services/MockDataService.swift`
DataManifest を読み込み、カテゴリに応じたJSONファイル群から商品データを返す。

| 機能 | 内容 |
|---|---|
| `loadItems(for:)` | カテゴリ対応の商品読み込み（id重複排除＋shuffle） |
| `loadManifest()` | DataManifest.jsonを読み込んでキャッシュ |
| `filesForCategory(_:)` | カテゴリ→ファイル名リスト変換 |
| `legacyFiles(for:)` | manifest不在時のフォールバック（旧3ファイル方式） |

`Data/` サブディレクトリを優先的に探し、見つからなければBundleルートを探すフォールバック付き。

### `Data/DataManifest.json`
カテゴリ別のJSONファイル一覧。Phase 2 で 41ファイル分類済み。

```json
{
  "version": 1,
  "categories": {
    "mens":   [ メンズ専用ファイル名 ],
    "ladies": [ レディース専用ファイル名 ],
    "unisex": [ 両カテゴリに含めるファイル名 ]
  }
}
```

カテゴリ判定ロジック:
- `.all` → mens + ladies + unisex
- `.ladies` → ladies + unisex
- `.mens` → mens + unisex

### `Views/Swipe/SwipeView.swift`
メインのスワイプ画面。3枚重ねカードスタック + スワイプジェスチャー + アクションボタン。

- しきい値: `120pt`
- 飛び出しアニメーション: `0.28秒 easeOut`
- トップカードに `.id(top.id)` を付与してアニメーション破綻を防止
- `performFlyOut` 内では `viewModel.like()/dislike()` → `offset = .zero` の順
- 空状態UI: フィルタ有無で文言を切り替え、フィルタ有なら「条件をリセット」ボタンを表示

### `Views/Swipe/CardView.swift`
個別の商品カードUI。AsyncImageの読み込み中は `Color.gray.opacity(0.1)` のみ（ProgressView非表示）。

### `Views/History/HistoryView.swift`
LIKE済み2列グリッド。

- セル長押しでcontextMenu表示 → 「削除」で `unlike(item:)`
- ツールバー右上の「すべて削除」ボタン → confirmationDialog → `clearAllLikes()`
- `ItemGridCell` は同ファイル内に定義（RecommendationsViewからも参照）

### `Views/Recommendations/RecommendationsView.swift`
おすすめ画面。LIKE件数に応じた2モード（パーソナライズ/カテゴリベース）の上位20件を表示。`HistoryView.ItemGridCell` を再利用。

### `Views/Settings/SettingsView.swift`
プロフィール / カテゴリ / 価格帯 / 好きなスタイル のフォーム。`onChange(of: draft)` で `viewModel.updateProfile(_:)` 即時呼び出し。

---

## DataManifest 拡張ロードマップ

DataManifest方式は段階的に分類を拡張する設計です。

| フェーズ | 内容 | 状態 |
|---|---|---|
| Phase 1 | 11ファイル（mens=3, ladies=4, unisex=4） | 完了 |
| **Phase 2** | **41ファイル（mens=13, ladies=14, unisex=14）** | **完了（現状）** |
| Phase 3 | 約100ファイル（各カテゴリ +20件程度） | 後回し |
| Phase 4 | 約250ファイル | 後回し |
| Phase 5 | 全440ファイル分類完了 | 後回し |

### Phase 3以降を後回しにする理由

- Phase 2 で母集団が大幅に増え、当面のスワイプ枯渇は解消
- 残り約400ファイルの分類は手作業で時間がかかる
- Swift コードを変更せず `DataManifest.json` の編集だけで拡張できるため、いつでも段階的に進められる

### 拡張時の作業

1. `FashionSwipe/Data/` 内の未分類JSONファイル名を選ぶ
2. `DataManifest.json` の `mens` / `ladies` / `unisex` のいずれかに追記
3. 重複なし・実在ファイルであることを確認
4. アプリを再起動して動作確認

**重要:** 迷ったら `unisex` に入れる方針（両カテゴリの母集団に含まれるため安全）。

---

## 開発時の注意点

1. **作業対象は `FashionSwipe/` ディレクトリ配下のみ**。`backend/` や `recommender/` は触らない。
2. **`../` で親ディレクトリに出ない**。backend・api・database等のフォルダにはアクセスしない。
3. `Item` / `UserProfile` は `Codable` 対応済み。永続化は `JSONEncoder` / `JSONDecoder` を使用。
4. `SwipeViewModel` は `@MainActor` なので、非同期処理を追加する際は `async/await` に注意。
5. `MockDataService.loadItems(for:)` は内部で id 重複排除済み。呼び出し側で追加排除は不要。
6. 状態は `@Published private(set)` で公開し、変更は必ず ViewModel 内のメソッド経由で行う。
7. UserDefaults キー: `"likedItems"` / `"userProfile"`。変更すると既存データが読めなくなる。
8. DataManifest.json の編集後は Xcode 再ビルドが必要。
9. CardView の AsyncImage はキャッシュ層なし。同じ画像URLでも View 再生成のたびに再取得される（実装上のトレードオフ）。
10. SKIP（dislike）はメモリ上で消えるだけで永続化されない。

---

## Claude Codeに守ってほしいルール

1. **コード変更前に必ず対象ファイルを `Read` で確認する。**
2. **変更は指示されたファイル・機能の範囲に留める。** 大きなリファクタリングや関係ないファイルへの変更はしない。
3. **`backend/` ディレクトリは読み込まない・変更しない。**
4. **UIの見た目（アニメーション・レイアウト・色）は明示的な指示なしに変えない。**
5. **新しいファイルを作る前に、既存ファイルへの追加で対応できないか確認する。**
6. **作業前に `pwd` で作業ディレクトリを確認する。**
7. **変更後は変更箇所・追加関数・影響範囲を日本語で説明する。**
8. **DataManifest.json の編集は Swift コード変更を伴わない。** Phase 3 拡張時は manifest のみ更新する。

---

## 次に実装する予定の機能

| 優先度 | 機能 | 想定される変更ファイル |
|---|---|---|
| 1 | バックエンドAPI連携（認証・商品取得・LIKE/SKIP送信・推薦取得） | 新規 APIClient、`SwipeViewModel`、`MockDataService` 置換 |
| 2 | DataManifest Phase 3（残り約400ファイル分類） | `DataManifest.json` のみ |
| 3 | SKIP履歴の保存 | `SwipeViewModel`（skippedItems追加） |
| 4 | 画像キャッシュ層の導入 | 新規 ImageCache または CachedAsyncImage |
| 5 | ログイン・会員登録画面 | 新規 LoginView、`FashionSwipeApp` |
| 後回し | 嗜好説明文表示（`/api/taste`） | API連携導入後に検討 |
