# API 仕様

Swipe Fashion のサーバー（Flask）の API です。

## ベース URL

```
http://localhost:5001
```

ポートは `.env` の `PORT` で変えられます。

## 認証

`/api/auth/*` と `/health` 以外は、`Authorization: Bearer <token>` ヘッダが必要です。
トークンがない・正しくないときは `401` を返します。

```json
{ "error": "Unauthorized" }
```

エラーのときは、どのエンドポイントも `{ "error": "<理由>" }` の形で返します。

## 商品の形

商品は、楽天市場 商品検索 API のレスポンスと同じ項目名で返します（iOS アプリの `Item` がそのまま読める形）。

```json
{
  "itemCode": "shop:10000123",
  "itemName": "オーバーサイズ Tシャツ メンズ 半袖 ...",
  "catchcopy": "送料無料 ...",
  "itemPrice": 2980,
  "shopName": "〇〇ストア",
  "reviewAverage": 4.5,
  "reviewCount": 120,
  "itemUrl": "https://item.rakuten.co.jp/...",
  "mediumImageUrls": [{ "imageUrl": "https://thumbnail.image.rakuten.co.jp/...?_ex=128x128" }],
  "genreId": 555086
}
```

---

## 認証

### POST `/api/auth/device`

端末ごとの ID でログインします。初めての ID ならユーザーを作ります（アプリはこれを使い、ログイン画面はありません）。

```json
{ "device_id": "8F3C...-UUID" }
```

レスポンス `200`

```json
{ "user_id": 1, "token": "abc123..." }
```

| コード | 内容 |
| --- | --- |
| 400 | `device_id` がない |

### POST `/api/auth/register`

メールアドレスで登録します（現在のアプリでは使っていません）。

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| email | string | ✓ | メールアドレス |
| password | string | ✓ | パスワード |
| age | int | - | 年齢 |
| gender | string | - | 性別（例: "男性", "女性", "その他"） |
| region | string | - | 住んでいる地域（例: "大阪"） |

レスポンス `201`: `{ "user_id": 1, "token": "abc123..." }`

| コード | 内容 |
| --- | --- |
| 400 | email / password がない |
| 409 | 登録済みのメールアドレス |

### POST `/api/auth/login`

```json
{ "email": "user@example.com", "password": "pass1234" }
```

レスポンス `200`: `{ "user_id": 1, "token": "abc123..." }`

| コード | 内容 |
| --- | --- |
| 400 | email / password がない |
| 401 | メールアドレスかパスワードが違う |

---

## 商品

### GET `/api/items/next?limit=10`

まだ LIKE / SKIP していない商品を、ランダムに返します（`limit` は最大50）。

レスポンス `200`: 商品の配列

### GET `/api/items/{item_code}`

商品1件を返します。

| コード | 内容 |
| --- | --- |
| 404 | 商品がない |

---

## LIKE / SKIP

### POST `/api/actions`

```json
{ "item_code": "shop:10000123", "action": "LIKE" }
```

`action` は `"LIKE"` か `"SKIP"`。同じ商品に同じ操作をもう一度送っても、二重には記録しません。
LIKE が10件たまるごとに、このリクエストの中で AI スタイル診断の説明文を作り直します。

レスポンス `200`

```json
{ "ok": true, "already_recorded": false, "taste_available": false }
```

| フィールド | 内容 |
| --- | --- |
| already_recorded | すでに記録済みだったか |
| taste_available | 説明文ができているか |

| コード | 内容 |
| --- | --- |
| 400 | `item_code` か `action` が正しくない |
| 404 | 商品がない |

---

## おすすめ

### GET `/api/recommend?limit=20&scope=app`

LIKE / SKIP から作った好みのベクトルと、各商品の22次元タグベクトルのコサイン類似度で、近い順に返します。
LIKE / SKIP 済みの商品は含めません。類似度が同じ商品は、レビューの多い順に並べます。

| クエリ | 既定 | 内容 |
| --- | --- | --- |
| limit | 20 | 件数（1〜100） |
| scope | all | `app` にすると、iOS アプリに載せている商品（`DataManifest.json` に登録したファイルの商品）だけから選ぶ |

アプリは `scope=app&limit=100` で取り、種別（トップス / ボトムス など）の絞り込みは端末側で行います。

レスポンス `200`: 商品の項目に `score` と `reasons` を足した配列

```json
[
  {
    "itemCode": "shop:10000123",
    "itemName": "...",
    "...": "（商品の形と同じ）",
    "score": 0.8652,
    "reasons": ["モノトーン", "きれいめ"]
  }
]
```

| フィールド | 内容 |
| --- | --- |
| score | 好みとのコサイン類似度 |
| reasons | 好みを押し上げているタグのうち、この商品も持っているもの（効いている順に最大2つ）。価格帯は「同じ価格帯」 |

LIKE / SKIP がまだないときは、ランダムな順で返します（`reasons` は空）。

| コード | 内容 |
| --- | --- |
| 400 | `limit` が整数でない |

### GET `/api/favorites`

LIKE した商品を、新しい順に返します。

レスポンス `200`: 商品の配列

---

## AI スタイル診断

### GET `/api/taste`

LLM が作った好みの説明文を返します。LIKE が10件に届くまでは `description` が `null` です。
LLM につながらないときも `500` にはせず、保存済みの説明文（なければ `null`）を返します。

レスポンス `200`

```json
{
  "description": "きれいめなモノトーンのアイテムを中心に…",
  "updated_at": "2026-11-04T09:00:00+00:00"
}
```

---

## その他

### GET `/health`

レスポンス `200`: `{ "status": "ok" }`

---

## curl で試す

```bash
BASE=http://localhost:5001

# 端末 ID でログインしてトークンを取る
TOKEN=$(curl -s -X POST $BASE/api/auth/device \
  -H "Content-Type: application/json" \
  -d '{"device_id":"curl-test"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

# まだ評価していない商品
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/api/items/next?limit=5"

# LIKE（item_code は上で返ってきた itemCode）
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"item_code":"<itemCode>","action":"LIKE"}' \
  $BASE/api/actions

# おすすめ（アプリに載せている商品から）
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/api/recommend?scope=app&limit=5"

# AI スタイル診断（LIKE 10件で説明文が入る）
curl -s -H "Authorization: Bearer $TOKEN" $BASE/api/taste
```
