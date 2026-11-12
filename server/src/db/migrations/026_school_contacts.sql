-- How families reach the school, shown on the Help page (empty = hidden).
ALTER TABLE institutions ADD COLUMN email TEXT NOT NULL DEFAULT '';
ALTER TABLE institutions ADD COLUMN whatsapp TEXT NOT NULL DEFAULT '';
