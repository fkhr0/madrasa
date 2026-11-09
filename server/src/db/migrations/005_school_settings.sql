-- School settings the administrator edits: contact details and the school's
-- place on the map (every bus line ends there).
ALTER TABLE institutions ADD COLUMN address TEXT NOT NULL DEFAULT '';
ALTER TABLE institutions ADD COLUMN phone TEXT NOT NULL DEFAULT '';
ALTER TABLE institutions ADD COLUMN latitude DOUBLE PRECISION;
ALTER TABLE institutions ADD COLUMN longitude DOUBLE PRECISION;

-- Only schools for now (universities may come back later).
UPDATE institutions SET type = 'school';

-- Al-Noor's gate in Baghdad, as on the app's demo map.
UPDATE institutions SET latitude = 33.315, longitude = 44.365,
  address = 'Al-Mansour, Baghdad'
WHERE id IN ('inst-001', 'inst-002');

-- Official holidays come from the platform's list (official-holidays.js).
-- The school can move their dates (moon sighting) but not delete them.
ALTER TABLE holidays ADD COLUMN official_key TEXT;
CREATE UNIQUE INDEX holidays_official ON holidays (academic_year_id, official_key);

UPDATE holidays SET official_key = CASE name
  WHEN 'Iraqi National Day' THEN 'national-day'
  WHEN 'Christmas' THEN 'christmas'
  WHEN 'New Year''s Day' THEN 'new-year'
  WHEN 'Army Day' THEN 'army-day'
  WHEN 'Eid al-Fitr' THEN 'eid-al-fitr'
  WHEN 'Nowruz' THEN 'nowruz'
  WHEN 'Eid al-Adha' THEN 'eid-al-adha'
END;
