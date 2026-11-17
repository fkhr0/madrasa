CREATE TABLE conversations (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id  TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  kind            TEXT NOT NULL CHECK (kind IN ('direct', 'class')),
  class_id        TEXT UNIQUE REFERENCES classes(id) ON DELETE CASCADE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK ((kind = 'class') = (class_id IS NOT NULL))
);

CREATE TABLE conversation_members (
  conversation_id  TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  PRIMARY KEY (conversation_id, user_id)
);
CREATE INDEX conversation_members_user ON conversation_members (user_id);

CREATE TABLE messages (
  id               TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  conversation_id  TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id        TEXT REFERENCES users(id) ON DELETE SET NULL,
  text             TEXT NOT NULL,
  sent_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX messages_conversation ON messages (conversation_id, sent_at);

CREATE TABLE conversation_reads (
  conversation_id  TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  read_at          TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (conversation_id, user_id)
);
