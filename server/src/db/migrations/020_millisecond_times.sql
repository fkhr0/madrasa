-- Times kept to the millisecond, like JavaScript and the app. PostgreSQL keeps
-- microseconds, so "messages after 10:20:34.876" (the app's last message)
-- would find that same message again (it is really .876588).
-- Columns added later: write them as TIMESTAMPTZ(3).
DO $$
DECLARE
  col record;
BEGIN
  FOR col IN
    SELECT c.table_name, c.column_name
    FROM information_schema.columns c
    JOIN information_schema.tables t
      ON t.table_schema = c.table_schema AND t.table_name = c.table_name
    WHERE c.table_schema = current_schema()
      AND t.table_type = 'BASE TABLE'
      AND c.data_type = 'timestamp with time zone'
  LOOP
    EXECUTE format('ALTER TABLE %I ALTER COLUMN %I TYPE timestamptz(3)', col.table_name, col.column_name);
  END LOOP;
END $$;
