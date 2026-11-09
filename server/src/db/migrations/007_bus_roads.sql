-- The road a bus line drives, worked out once from its stops when they are
-- saved (OSRM, on OpenStreetMap roads), so maps draw streets, not straight
-- lines. Null until worked out, or when the routing service was unreachable.
-- { legs: [[[lat, lng], …], …] one per stop-to-stop drive,
--   metres, seconds, legSeconds: [...] }
ALTER TABLE bus_routes ADD COLUMN road_to_school JSONB;
ALTER TABLE bus_routes ADD COLUMN road_to_home JSONB;
