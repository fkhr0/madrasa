ALTER TABLE finance_settings ADD COLUMN configured BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE finance_settings ALTER COLUMN tuition SET DEFAULT 0;
ALTER TABLE finance_settings ALTER COLUMN bus_fee SET DEFAULT 0;
UPDATE finance_settings SET configured = true WHERE due_dates <> '{}';
UPDATE finance_settings SET tuition = 0, bus_fee = 0 WHERE NOT configured;
