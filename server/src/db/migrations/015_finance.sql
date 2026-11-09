-- School fees in Iraqi dinars: the school's tuition and bus fee, installment
-- dates, discounts, and the payments families make at the office.
-- A student's yearly total = tuition (of their class, or the school's)
-- − discount % of tuition + bus fee (only when they ride a bus line).

CREATE TABLE finance_settings (
  institution_id  TEXT PRIMARY KEY REFERENCES institutions(id) ON DELETE CASCADE,
  tuition         INTEGER NOT NULL DEFAULT 2000000 CHECK (tuition >= 0),
  bus_fee         INTEGER NOT NULL DEFAULT 600000 CHECK (bus_fee >= 0),
  -- When each installment is due; the total is split evenly between them.
  due_dates       DATE[] NOT NULL DEFAULT '{}'
);

-- A class whose tuition differs from the school's (e.g. 6th grade).
CREATE TABLE class_tuition (
  class_id  TEXT PRIMARY KEY REFERENCES classes(id) ON DELETE CASCADE,
  tuition   INTEGER NOT NULL CHECK (tuition >= 0)
);

CREATE TABLE student_discounts (
  student_id  TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  percent     INTEGER NOT NULL CHECK (percent BETWEEN 0 AND 100),
  reason      TEXT NOT NULL DEFAULT ''
);

-- Money received. A wrong payment is voided (kept, with a reason), never deleted.
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
