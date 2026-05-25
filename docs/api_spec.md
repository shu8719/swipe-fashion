# API仕様書 — スワイプ型AIファッションレコメンド（PoC）

担当C（Swift）向けのエンドポイント一覧です。

## ベースURL

```
http://localhost:5000
```

> **iOS ATS注意**: Swiftで `http://localhost` を叩く場合、`Info.plist` に以下を追加してください。
>
> ```xml
> <key>NSAppTransportSecurity</key>
> <dict>
>   <key>NSAllowsLocalNetworking</key>
>   <true/>
> </dict>
> ```

## 認証

全エンドポイント（認証系を除く）は `Authorization: Bearer <token>` ヘッダが必要です。

---

## 1. ユーザー登録

**POST** `/api/auth/register`

### リクエスト (JSON)

| フィールド | 型 | 必須 | 説明 |
|---|---|---|---|
| email | string | ✓ | メールアドレス |
| password | string | ✓ | パスワード |
| age | int | - | 年齢 |
| gender | string | - | 性別（例: "男性", "女性", "その他"） |
| region | string | - | 居住地域（例: "大阪"） |

### レスポンス `201`

```json
{ "user_id": 1, "token": "abc123..." }
```

### エラー

| コード | 内容 |
|---|---|
| 400 | email / password が未入力 |
| 409 | 既に登録済みのメール |

---

## 2. ログイン

**POST** `/api/auth/login`

### リクエスト (JSON)

```json
{ "email": "user@example.com", "password": "pass1234" }
```

### レスポンス `200`

```json
{ "user_id": 1, "token": "abc123..." }
```

---

## 3. スワイプ用商品取得

**GET** `/api/items/next?limit=10`

未評価の商品をランダムで返します。

### レスポンス `200`

```json
[
  {
    "item_id": 1,
    "name": "オーバーサイズTシャツ(黒)",
    "brand": "ストリートブランドA",
    "price": 2800,
    "image_url": "https://...",
    "external_url": "https://...",
    "tags": [
      { "category": "style", "value": "ストリート" },
      { "category": "color", "value": "モノトーン" }
    ]
  }
]
```

---

## 4. LIKE / SKIP 送信

**POST** `/api/actions`

```json
{ "item_id": 1, "action": "LIKE" }
```

`action` は `"LIKE"` または `"SKIP"`。

### レスポンス `200`

```json
{ "ok": true }
```

---

## 5. AIおすすめ商品取得

**GET** `/api/recommend`

コンテンツベースフィルタリングで上位20件を返します。

### レスポンス `200`

```json
[
  {
    "item_id": 3,
    "name": "韓国系フーディ(グレー)",
    "brand": "韓国ブランドC",
    "price": 3200,
    "image_url": "https://...",
    "external_url": "https://...",
    "score": 0.8742
  }
]
```

---

## 6. 嗜好説明文取得

**GET** `/api/taste`

LIKE 10件ごとに更新。LIKE未満は `description: null`。

### レスポンス `200`

```json
{
  "description": "あなたはモノトーンを基調としたコーデが好きで...",
  "updated_at": "2026-05-25T10:00:00+00:00"
}
```

---

## 7. お気に入り一覧

**GET** `/api/favorites`

LIKEした商品を新しい順で返します。

---

## 8. 商品詳細

**GET** `/api/items/{item_id}`

```json
{
  "item_id": 1,
  "name": "オーバーサイズTシャツ(黒)",
  "brand": "ストリートブランドA",
  "price": 2800,
  "image_url": "https://...",
  "external_url": "https://...",
  "tags": [...]
}
```

---

## curl サンプル（疎通確認用）

```bash
# 登録
curl -s -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@ex.com","password":"pass1234","age":22,"gender":"男性","region":"大阪"}'

# ログイン → TOKEN取得
TOKEN=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@ex.com","password":"pass1234"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

# 次商品取得
curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:5000/api/items/next?limit=5"

# LIKE
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"item_id":1,"action":"LIKE"}' \
  http://localhost:5000/api/actions

# おすすめ
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:5000/api/recommend

# 嗜好説明（LIKE 10件後に説明文が入る）
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:5000/api/taste
```
