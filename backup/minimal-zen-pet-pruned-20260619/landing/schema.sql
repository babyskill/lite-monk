-- D1 schema for the community pet gallery + creator portal (fresh databases).
-- For an existing prod DB use migrate-prod.sql (adds the new columns/tables).
CREATE TABLE IF NOT EXISTS pets (
  slug        TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  author      TEXT NOT NULL DEFAULT 'community',
  kind        TEXT NOT NULL DEFAULT 'character',   -- character | creature | object
  sheet_key   TEXT NOT NULL,                       -- R2 key of the spritesheet
  json_key    TEXT NOT NULL,                       -- R2 key of the generated pet.json
  width       INTEGER,
  height      INTEGER,
  status      TEXT NOT NULL DEFAULT 'public',       -- public | hidden
  reports     INTEGER NOT NULL DEFAULT 0,
  description TEXT,
  user_id     INTEGER,                              -- owner (NULL for legacy anon pets)
  downloads   INTEGER NOT NULL DEFAULT 0,
  likes       INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL                      -- unix ms
);
CREATE INDEX IF NOT EXISTS idx_pets_status_created ON pets(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pets_user ON pets(user_id);

-- Per-IP upload log for simple rate limiting.
CREATE TABLE IF NOT EXISTS uploads (
  ip          TEXT NOT NULL,
  created_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_uploads_ip_time ON uploads(ip, created_at);

-- OAuth accounts (GitHub / Google / dev).
CREATE TABLE IF NOT EXISTS users (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  provider    TEXT NOT NULL,                        -- github | google | dev
  provider_id TEXT NOT NULL,
  name        TEXT NOT NULL,
  avatar_url  TEXT,
  created_at  INTEGER NOT NULL,
  UNIQUE(provider, provider_id)
);

-- Opaque server-side sessions; the cookie holds only the id.
CREATE TABLE IF NOT EXISTS sessions (
  id          TEXT PRIMARY KEY,
  user_id     INTEGER NOT NULL,
  created_at  INTEGER NOT NULL,
  expires_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);

-- One like per user per pet.
CREATE TABLE IF NOT EXISTS pet_likes (
  pet_slug    TEXT NOT NULL,
  user_id     INTEGER NOT NULL,
  created_at  INTEGER NOT NULL,
  PRIMARY KEY (pet_slug, user_id)
);

-- Per-IP download log to throttle counter inflation.
CREATE TABLE IF NOT EXISTS downloads_log (
  ip          TEXT NOT NULL,
  pet_slug    TEXT NOT NULL,
  created_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_dl_ip_slug_time ON downloads_log(ip, pet_slug, created_at);
