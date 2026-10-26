# Deploying Therapy Pal (Vercel + Turso)

This puts the whole app online:

| Part | Where it runs | What it is |
|---|---|---|
| **Database** | **Turso** | A hosted SQLite-style database (your server keeps its data here) |
| **Server** | **Vercel project 1** (folder `server`) | The Express API, run as a Vercel Function |
| **App** | **Vercel project 2** (folder `mobile`) | The Flutter web app, built by `mobile/build.sh` |

Do the steps in this order, because each part needs the address of the one before it.

> Free plans usually restrict commercial use and have usage limits. Check Vercel's and Turso's current terms. Real patient data also needs the privacy work listed in `ARCHITECTURE.md` section 11 before launch.

---

## 0. Before you start

- A GitHub account, a Vercel account and a Turso account.
- Your code on GitHub. If you have not done this yet, in the `Therapy_pal` folder:
  ```powershell
  git init
  git add .
  git commit -m "Therapy Pal"
  git branch -M main
  git remote add origin https://github.com/YOUR-NAME/therapy-pal.git
  git push -u origin main
  ```
  Your `.env.local` files and the local database are excluded automatically (see `.gitignore`).
- A long random secret for login passes. Generate one and keep it somewhere safe:
  ```powershell
  node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
  ```

## 1. Create the database (Turso)

Using the Turso dashboard (turso.tech):

1. Create a database named `therapy-pal`.
2. Choose a **location close to your users and close to the region where your Vercel Function will run** (every request makes several database calls, so distance adds up).
3. Copy the **database URL** (it starts with `libsql://`).
4. Create an **auth token** for the database (read and write) and copy it.

Prefer the command line? These do the same (see Turso's current docs if a command has changed):

```bash
turso auth login
turso db create therapy-pal
turso db show therapy-pal --url
turso db tokens create therapy-pal
```

You do not need to create tables. The server creates them the first time it runs.

## 2. (Optional) Load the demo data into the hosted database

Skip this for a real launch and create accounts through the app's sign-up screen instead (create a clinician first, then patients who enter that clinician's email).

For a demo, run this once from your computer. It only works on an empty database:

```powershell
cd server
$env:TURSO_DATABASE_URL = "libsql://YOUR-DATABASE-URL"
$env:TURSO_AUTH_TOKEN   = "YOUR-TOKEN"
npm run seed
```

The demo accounts all use the password `therapy-pal`. **Change or delete them before real use.**

`npm run reset` wipes data, so it refuses to touch a hosted database unless you add `--confirm-remote`.

## 3. Deploy the server (Vercel project 1)

1. In Vercel choose **Add New, Project** and import your GitHub repository.
2. Set **Root Directory** to `server`. Vercel detects Express on its own.
3. Add these **Environment Variables**:

   | Name | Value |
   |---|---|
   | `TURSO_DATABASE_URL` | the `libsql://` address from step 1 |
   | `TURSO_AUTH_TOKEN` | the token from step 1 |
   | `JWT_SECRET` | the long random secret from step 0 |
   | `CORS_ORIGIN` | `*` for now (you will tighten it in step 6) |

   Vercel sets `NODE_ENV=production` itself. Do not add `SEED_DEMO_DATA`.
4. Click **Deploy**.
5. Open `https://YOUR-SERVER.vercel.app/api/health`. You should see `{"ok":true,"service":"therapy-pal",...}`.
6. Open the project's **Settings, Functions** and set the **Function Region** next to your Turso database.

If the health page works but sign-in fails, open **Logs** in the Vercel dashboard. The most common cause is a missing environment variable.

## 4. Deploy the app (Vercel project 2)

1. Add a second project from the same repository.
2. Set **Root Directory** to `mobile` and **Framework Preset** to `Other`.
3. Add one environment variable: `API_BASE_URL` = `https://YOUR-SERVER.vercel.app/api` (it must end with `/api`).
4. Deploy. The first build takes several minutes because it downloads Flutter. `mobile/build.sh` and `mobile/vercel.json` handle the rest.

The server address is baked in when the app is built. If you ever change it, redeploy the app.

## 5. Try it

Open the app's Vercel address and sign in. If you loaded the demo data: `alex.rivera@email.com` (patient) or `s.carter@downtownclinic.org` (clinician), password `therapy-pal`.

## 6. Lock down the server

Back in the **server** project, change `CORS_ORIGIN` from `*` to the app's exact address, for example `https://YOUR-APP.vercel.app` (no trailing slash; separate several addresses with commas). Then **redeploy** the server, because new settings only apply to new deployments.

---

## Updating later

Push to GitHub. Each project redeploys on its own. Vercel keeps previous deployments, so you can roll back from the dashboard.

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| App says "Can't reach the server at https://..." | The address in `API_BASE_URL` is wrong, or lacks `/api`. Fix it in the app project and redeploy |
| Browser console shows a CORS error | `CORS_ORIGIN` does not exactly match the app's address, or you did not redeploy the server after changing it |
| Server logs say `TURSO_DATABASE_URL is not set` | Add the variables in the server project, then redeploy |
| Every request is slow | Function Region and Turso location are far apart |
| App build fails at `build.sh` | Check the build log. The first run downloads Flutter; also make sure `API_BASE_URL` is set |
| "Too many attempts" while testing sign-in | The login limit is 30 attempts per 15 minutes; wait, or test with fewer tries |

## What changes between local and online

| | Local | Online |
|---|---|---|
| Database | file `server/data/therapy_pal.db` | Turso |
| Server | `npm run dev` (port 4000) | Vercel Function |
| App | `flutter run` | Vercel static website |
| Secrets | `server/.env.local` | Vercel environment variables |

Your local setup keeps working exactly as before.
