CREATE TABLE finance_settings (
  institution_id  TEXT PRIMARY KEY REFERENCES institutions(id) ON DELETE CASCADE,
  tuition         INTEGER NOT NULL DEFAULT 2000000 CHECK (tuition >= 0),
  bus_fee         INTEGER NOT NULL DEFAULT 600000 CHECK (bus_fee >= 0),
  due_dates       DATE[] NOT NULL DEFAULT '{}'
);

CREATE TABLE class_tuition (
  class_id  TEXT PRIMARY KEY REFERENCES classes(id) ON DELETE CASCADE,
  tuition   INTEGER NOT NULL CHECK (tuition >= 0)
);

CREATE TABLE student_discounts (
  student_id  TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  percent     INTEGER NOT NULL CHECK (percent BETWEEN 0 AND 100),
  reason      TEXT NOT NULL DEFAULT ''
);

CREATE TABLE payments (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  institution_id  TEXT NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  student_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receipt_number  TEXT NOT NULL,
  amount          INTEGER NOT NULL CHECK (amount > 0),
  method          TEXT NOT NULL CHECK (method IN ('cash', 'bankTransfer', 'card', 'eWallet')),
  note            TEXT NOT NULL DEFAULT '',
  paid_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  recorded_by     TEXT REFERENCES users(id) ON DELETE SET NULL,
  voided_at       TIMESTAMPTZ,
  void_reason     TEXT,
  UNIQUE (institution_id, receipt_number)
);
CREATE INDEX payments_student ON payments (student_id);
