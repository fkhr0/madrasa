# School API

Express + PostgreSQL server for the school app.

## Run it on your PC

```bash
cd server
npm install        # first time only
npm run dev        # restarts by itself when you change a file
```

Nothing else needs to be installed. With `DATABASE_URL` empty, the server uses
**PGlite**: real PostgreSQL running inside Node, saved in `server/.data/`.
On first start it creates the tables and the demo data.

Then run the app against it:

```bash
flutter run -d chrome --dart-define=API_URL=http://localhost:3000
```

Without `--dart-define` the app keeps using its mock data.

| Demo account | ID | Password |
|---|---|---|
| Student | STU-2026-0142 | demo1234 |
| Teacher | TCH-2019-0031 | demo1234 |
| Parent | PAR-2026-0142 | demo1234 |
| Administrator | ADM-2020-0001 | demo1234 |
| Bus driver | DRV-2024-0012 | demo1234 |

## Commands

| Command | What it does |
|---|---|
| `npm run dev` | Start and restart on changes |
| `npm start` | Start (for hosting) |
| `npm test` | Run the tests (in-memory database, nothing to set up) |
| `npm run db:reset` | Delete the local database; the next start rebuilds it |

## Settings

Copy `.env.example` to `.env`. For an online database (Neon, Supabase) set
`DATABASE_URL`; in production also set `NODE_ENV=production` and two long
random `JWT_*_SECRET` values (the server refuses to start without them).

Optional:

| Setting | What it is for |
|---|---|
| `OSRM_URL` | The road-routing server (default: the free OSRM demo). `off` = straight lines |
| `NOMINATIM_URL` | The place-search server (default: OpenStreetMap's) |
| `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY` | Web Push keys. Without them the server makes a pair once in `.data/push-keys.json` |

## Folders

```
src/
  server.js            start: database → migrations → demo data → listen
  app.js               middleware and routes
  config.js            every setting from the environment
  common/              errors, validation, "who is calling" middleware
  db/
    database.js        query() and transaction(): PostgreSQL or PGlite
    migrate.js         runs migrations/*.sql in order, once each
    migrations/        the tables (never edit one that ran online; add a new file)
    seed.js            demo data, same as the app's mock data
  features/
    auth/              sign in, refresh, sign out
    users/             /me: profile and password
    institution/       the school (settings, map location), study year,
                       holidays; official-holidays.js = Iraq's list
    people/            accounts: generated IDs, temporary passwords
    events/            school events and meetings on the calendar
    academics/         subjects, classes, head teachers, subject teachers
    announcements/     the notice board; announce.js tells people
    transport/         school buses:
      transport.routes.js       lines, riders, homes, trips (the HTTP part)
      transport.repository.js   the SQL
      trip-rules.js             when a trip may start; distances
      alerts.js                 what families/driver/office are told
      maps.js                   OpenStreetMap: roads (OSRM), places, links
      roads.js                  keeps each line's road up to date
    notifications/     the bell: notify.js (save + who to tell),
                       push.js (Web Push to closed phones)
test/                  one file per feature
```

Each feature has a `*.routes.js` (the HTTP part) and a `*.repository.js`
(the SQL). All SQL uses `$1, $2…` parameters, never values pasted into text.

## API

| Method | Path | Who |
|---|---|---|
| GET | /health | anyone |
| POST | /auth/login `{schoolId, password}` | anyone |
| POST | /auth/refresh `{refreshToken}` | anyone |
| POST | /auth/logout `{refreshToken}` | anyone |
| POST | /auth/password-reset `{emailOrPhone}` | anyone |
| GET / PATCH | /me | signed in |
| POST | /me/password | signed in |
| GET | /institution, /academic-year | signed in |
| PATCH | /institution (name, contacts, map location) | admin |
| PATCH | /academic-year `{workingDays}` | admin |
| POST / PATCH / DELETE | /academic-year/holidays (official ones: dates only, no delete) | admin |
| GET | /events (only what the role may see) | signed in |
| POST / PATCH / DELETE | /events | admin |
| GET / POST | /people?role=… | admin |
| GET / PATCH / DELETE | /people/:id | admin |
| POST | /people/:id/active, /people/:id/reset-password | admin |
| GET / POST / PATCH / DELETE | /academics/subjects | admin |
| GET / POST / PATCH / DELETE | /academics/classes | admin |
| PUT / DELETE | /academics/classes/:id/subjects/:subjectId `{teacherId}` | admin |
| GET | /announcements (only what the person may see) | signed in |
| POST | /announcements | teacher (own classes), admin |
| PATCH / DELETE | /announcements/:id | its author, admin |
| GET / PUT | /transport/settings | signed in / admin |
| GET | /transport/routes, /transport/routes/:id | signed in |
| POST / PATCH / DELETE | /transport/routes (roads worked out on save) | admin |
| POST | /transport/routes/:id/road (work the road out again) | admin |
| GET | /transport/places?q=… (find a place by name) | admin |
| GET | /transport/driver-route | driver |
| GET | /transport/routes/:id/students | staff, driver |
| GET | /transport/students-without-bus | admin |
| PUT / DELETE | /transport/routes/:id/students/:studentId `{stopId}` | admin |
| GET | /transport/students/:id (their bus) | the student, parent, admin |
| POST | /transport/students/:id/not-riding `{notRiding}` | the student, parent, admin |
| GET / PUT | /transport/students/:id/home (door to door) | the student, parent, admin |
| POST | /transport/read-location `{text}` (WhatsApp / Maps link) | admin, parent, student |
| GET | /transport/routes/:id/trip (today's trip) | signed in |
| POST | /transport/routes/:id/trip/start, leave, arrive, boarding, delay, end | the line's driver, admin |
| POST | /transport/routes/:id/trip/location `{latitude, longitude}` | the line's driver |
| GET | /notifications | signed in |
| POST | /notifications/:id/read, /notifications/read-all | signed in |
| GET | /notifications/push-key | signed in |
| POST / DELETE | /notifications/push (this phone, Web Push) | signed in |

Sign-in uses a short access token (15 min) and a refresh token (30 days,
replaced on every use, stored hashed). The app refreshes silently.
