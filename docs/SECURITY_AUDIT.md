# Security audit, 2026-11-09

Scope: the Node server (`server/`), the Flutter app (`lib/`, `android/`), and
the repository. Every finding below has a test in `server/test/`.

## Fixed in this audit

| # | Finding | Risk | Fix |
|---|---|---|---|
| 1 | File download links were signed with the same key and purpose as sign-in tokens | A leaked link (they appear in addresses and logs) was accepted as a sign-in token | Tokens carry their purpose (`aud`: access / file) and only HS256 is accepted (`auth/tokens.js` `verifyToken`) |
| 2 | "Forgot password" said a code was sent but sent nothing | Users stuck; false promise | The request notifies the school office, which resets the password in People; same answer whether or not the account exists |
| 3 | Sign-in answered faster for IDs that don't exist | Valid school IDs could be found by timing | A password check always runs (against a dummy hash for unknown IDs) |
| 4 | One account could open unlimited live connections | Memory exhaustion | 5 connections per person; the oldest is closed |

## Checked, no problem found

| Area | What was checked |
|---|---|
| SQL injection | Every query: user values always go through `$1, $2…` parameters; SQL text is only built from constants in the code |
| Shell / code execution | One program is started (`pg_dump`): fixed arguments, no shell, no user input. No `eval`, `Function`, `vm` |
| Server-side request forgery | Pasted location links: only Google's short-link hosts are fetched, redirects followed by hand and checked each hop |
| Access control (IDOR) | Every route with an ID checks it belongs to the caller (`personOr404`, `classOr404`, `conversationOr404`, own rows by `user_id`); one school can't reach another (test) |
| Becoming admin | Roles come only from the signed token; only admins create accounts; demo accounts are off in production (`SEED_DEMO_DATA`, startup check) |
| Uploads | Allowed types only, content checked against the name, our own Content-Type, risky types forced to download with a sandbox, photos re-encoded (EXIF/GPS removed), size limits |
| Brute force | Rate limits per address and per ID, 5 wrong passwords lock the ID for 15 minutes |
| Headers | CSP, HSTS (production), nosniff, no framing, referrer off, CORS allowlist, WebSocket origin check |
| Errors | Details only in the server log; the caller gets a generic message |
| Secrets | Not in git (`.gitignore` + a scan before the first commit): `.env`, Firebase key, signing key, `google-services.json` |
| App | Session in Android secure storage, no app data in cloud backups, http only in debug builds, no tokens in logs, saved answers deleted on sign-out |

## Known and accepted

- `npm audit`: 6 moderate findings inside `@google-cloud/firestore`, which
  `firebase-admin` installs but the server never calls. Dependabot will offer
  the update when Google ships it.
- OpenStreetMap's public tile, routing and search servers are for light use:
  fine for a portfolio; switch to a hosted plan or self-hosted tiles for real
  traffic.

## Automated from now on (CI)

npm audit · CodeQL · Trivy (image and secrets) · Gitleaks · Hadolint ·
Dependabot: see `.github/workflows/`.
