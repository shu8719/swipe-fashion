-- PoC用 SQLiteスキーマ（担当A・B合議の叩き台）

CREATE TABLE IF NOT EXISTS users (
  user_id   INTEGER PRIMARY KEY AUTOINCREMENT,
  email     TEXT    UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  age       INTEGER,
  gender    TEXT,
  region    TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tokens (
  token     TEXT PRIMARY KEY,
  user_id   INTEGER NOT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS items (
  item_id      INTEGER PRIMARY KEY,
  name         TEXT,
  brand        TEXT,
  price        INTEGER,
  image_url    TEXT,
  external_url TEXT
);

-- 商品タグ（カテゴリ + 値で多対多）
CREATE TABLE IF NOT EXISTS item_tags (
  item_id      INTEGER NOT NULL,
  tag_category TEXT    NOT NULL,
  tag_value    TEXT    NOT NULL,
  PRIMARY KEY (item_id, tag_category, tag_value)
);

-- 担当A が AI-01 で生成する 22次元ベクトル（JSON配列）
CREATE TABLE IF NOT EXISTS item_vectors (
  item_id     INTEGER PRIMARY KEY,
  vector_json TEXT    NOT NULL
);

CREATE TABLE IF NOT EXISTS user_actions (
  action_id  INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL,
  item_id    INTEGER NOT NULL,
  action     TEXT    NOT NULL CHECK(action IN ('LIKE','SKIP')),
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- AI-05 嗜好説明文キャッシュ
CREATE TABLE IF NOT EXISTS taste_descriptions (
  user_id          INTEGER PRIMARY KEY,
  description      TEXT,
  updated_at       TEXT,
  like_count_at_gen INTEGER DEFAULT 0
);

-- AI-04 K-meansクラスタ割当
CREATE TABLE IF NOT EXISTS user_clusters (
  user_id    INTEGER PRIMARY KEY,
  cluster_id INTEGER,
  assigned_at TEXT DEFAULT CURRENT_TIMESTAMP
);
