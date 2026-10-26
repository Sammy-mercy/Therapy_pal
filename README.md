# Therapy Pal

A dual-role (patient + clinician) treatment regimen app.

- `mobile/` - Flutter app (Android, iOS, web). Patient and clinician experiences share one login.
- `server/` - Node.js + Express 5 API. Data uses SQLite-style storage through `@libsql/client`: a local file in development, a hosted Turso database when deployed.
- `docs/` - `ARCHITECTURE.md` (how it is built) and `DEPLOYMENT.md` (how to put it online).

## Put it online

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md): the server and the app each become a Vercel project, and the database moves to Turso.

## Run it

Requires Node 22.13+ (tested on 24) and Flutter 3.44+.

```powershell
# 1. API (terminal 1)
cd server
npm install
npm run reset     # loads demo data (wipes the local database)
npm run dev       # http://localhost:4000/api/health

# 2. App (terminal 2)
cd mobile
flutter pub get
flutter run --dart-define-from-file=.env.local          # pick a device
flutter run -d chrome --dart-define-from-file=.env.local  # or the browser
```

Demo accounts (password `therapy-pal`): `alex.rivera@email.com` (patient), `s.carter@downtownclinic.org` (clinician).
They are pre-filled on the login screen in debug builds only.

Demo data is generated relative to the day you seed it. If it looks stale after a few days, run `npm run reset` again.

## Configuration (`.env.local`, git-ignored)

| File | Variable | Purpose |
|---|---|---|
| `server/.env.local` | `TURSO_DATABASE_URL`, `TURSO_AUTH_TOKEN` | Hosted database. Leave empty locally (a file is used); required online (set them in Vercel) |
| | `JWT_SECRET` | **Set before production.** Empty = temporary dev secret, logins reset on restart |
| | `PORT`, `DB_PATH`, `CORS_ORIGIN` | Server port, local database file, allowed web origins (`*` for dev only) |
| | `SEED_DEMO_DATA` | `true` loads demo data into an empty database on first start; set `false` for real use |
| `mobile/.env.local` | `API_BASE_URL` | Empty = emulator/localhost defaults. Physical phone: `http://<your-LAN-IP>:4000/api` |

## Notes and v1 limits

- Responsive layout (from the Stitch template): under 768px a bottom tab bar; 768-1279px a 72px icon rail with a top bar; 1280px and up a 260px sidebar with a top bar. Pages switch to multi-column grids on wide screens, and the clinician inbox becomes a list-plus-conversation split view. Breakpoints live in `mobile/lib/core/responsive.dart`; `mobile/test/responsive_test.dart` renders every screen at phone, tablet, laptop and wide sizes and fails on any layout overflow.
- No real-time: messages refresh every 10s and on pull-to-refresh. Dose reminders and missed-dose alerts are created when the app loads notifications; there is no push service yet (`.env.local` has commented placeholders).
- A scheduled dose counts as missed 3 hours after its time (`MISSED_AFTER_MIN` in `server/src/lib/adherence.js`).
- Android allows plain HTTP (`usesCleartextTraffic`) and iOS allows local networking for development. Remove both and serve the API over HTTPS before releasing.
- `server/test-api.ps1` exercises every endpoint plus the role/auth checks against a running server.
- Fonts (Plus Jakarta Sans) load through `google_fonts`; offline, the app falls back to the system font.
- Not yet verified on an emulator or phone: `flutter analyze`, the unit tests and a web build pass, but screens have not been run and visually compared with the design.
