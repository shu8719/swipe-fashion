-- PoC用 SQLiteスキーマ（楽天APIスキーマ準拠・統合版 v2）

CREATE TABLE IF NOT EXISTS users (
  user_id    INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id  TEXT    UNIQUE,
  email      TEXT    UNIQUE,
  password_hash TEXT,
  age        INTEGER,
  gender     TEXT,
  region     TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tokens (
  token      TEXT    PRIMARY KEY,
  user_id    INTEGER NOT NULL,
  created_at TEXT    DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS items (
  item_code      TEXT PRIMARY KEY,
  item_name      TEXT,
  catchcopy      TEXT,
  item_caption   TEXT,
  item_price     INTEGER,
  shop_name      TEXT,
  review_average REAL    DEFAULT 0.0,
  review_count   INTEGER DEFAULT 0,
  item_url       TEXT,
  image_url      TEXT,
  genre_id       INTEGER
);

CREATE TABLE IF NOT EXISTS item_tags (
  item_code    TEXT NOT NULL,
  tag_category TEXT NOT NULL,
  tag_value    TEXT NOT NULL,
  PRIMARY KEY (item_code, tag_category, tag_value)
);

CREATE TABLE IF NOT EXISTS item_vectors (
  item_code   TEXT PRIMARY KEY,
  vector_json TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS user_actions (
  action_id  INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL,
  item_code  TEXT    NOT NULL,
  action     TEXT    NOT NULL CHECK(action IN ('LIKE','SKIP')),
  created_at TEXT    DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS taste_descriptions (
  user_id           INTEGER PRIMARY KEY,
  description       TEXT,
  updated_at        TEXT,
  like_count_at_gen INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS user_clusters (
  user_id     INTEGER PRIMARY KEY,
  cluster_id  INTEGER,
  assigned_at TEXT DEFAULT CURRENT_TIMESTAMP
);
