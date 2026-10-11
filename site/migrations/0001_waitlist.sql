-- Praxmodoro beta waitlist. One row per email address.
-- Raw IP addresses are never stored: ip_hash is a salted SHA-256 (see src/lib/hash.js).
CREATE TABLE IF NOT EXISTS waitlist (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  product TEXT NOT NULL DEFAULT 'praxmodoro',
  fields TEXT NOT NULL DEFAULT '{}',   -- JSON: optional answers ({"mac": "...", "hardest": "..."})
  source TEXT,                          -- which form on the site ("hero", "join", ...)
  utm TEXT NOT NULL DEFAULT '{}',       -- JSON: utm_source, utm_medium, utm_campaign, referrer
  consent_at TEXT NOT NULL,             -- ISO 8601 time the consent box was ticked
  created_at TEXT NOT NULL,             -- ISO 8601
  ip_hash TEXT
);

CREATE INDEX IF NOT EXISTS waitlist_created_at ON waitlist (created_at);

-- Fixed-window rate limit: one row per hashed IP per 10-minute window.
CREATE TABLE IF NOT EXISTS rate_limits (
  ip_hash TEXT NOT NULL,
  window_start INTEGER NOT NULL,        -- epoch milliseconds, aligned to the window size
  count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (ip_hash, window_start)
);

CREATE INDEX IF NOT EXISTS rate_limits_window_start ON rate_limits (window_start);
