# Clubhouse Stakes — Deployment Runbook

Friends-and-family beta: Flutter web frontend on Cloudflare Pages, Node API on Railway, domain at Namecheap.

**Final URLs:**
- `https://www.clubhousestakes.com` — frontend
- `https://api.clubhousestakes.com` — backend API

---

## 1. Backend on Railway

### 1.1 Create the project
1. Sign up at [railway.app](https://railway.app)
2. New Project → **Deploy from GitHub repo** → select this repo
3. Set the **Root Directory** to `backend/`
4. Railway auto-detects Node and runs `npm start`

### 1.2 Add Postgres
1. In your project, click **+ New** → **Database** → **Add PostgreSQL**
2. Railway auto-injects `DATABASE_URL` into your service — no manual setup needed

### 1.3 Set environment variables
In the backend service → **Variables** tab, add:

| Key | Value | Required? |
|---|---|---|
| `NODE_ENV` | `production` | ✅ |
| `JWT_SECRET` | run `node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"` and paste the result | ✅ |
| `CORS_ORIGINS` | `https://www.clubhousestakes.com,https://clubhousestakes.com` | ✅ |
| `GOLFCOURSE_API_KEY` | your key from [golfcourseapi.com](https://golfcourseapi.com) | ✅ for course search |
| `APP_PUBLIC_URL` | `https://www.clubhousestakes.com` | needed for invite emails |
| `EMAIL_FROM` | `Clubhouse Stakes <no-reply@clubhousestakes.com>` | needed for invite emails |
| `SMTP_HOST` | e.g. `smtp.sendgrid.net` | needed to actually send invites |
| `SMTP_PORT` | `587` (or `465` for TLS) | with SMTP_HOST |
| `SMTP_USER` | `apikey` (SendGrid) or your username | with SMTP_HOST |
| `SMTP_PASS` | your SMTP password / API key | with SMTP_HOST |

(Leave `DATABASE_URL` alone — Railway sets it automatically.)

If SMTP is unset the backend boots fine but logs invite emails to the console
instead of sending them.

### 1.4 Run migrations
After the first deploy succeeds:
```bash
# Install Railway CLI: https://docs.railway.app/develop/cli
railway link
railway run npm run migrate
```

The runner picks up everything in `backend/migrations/` in order, including:

| File | What it does |
|---|---|
| `001_schema.sql` | Core tables (users, tournaments, teams, entries, payouts) |
| `002_skins.sql`  | Skins side-game columns |
| `003_rules.sql`  | `tournaments.rules` |
| `004_round2.sql` | Handicap toggle, custom pars, designated team scorer |
| `005_courses.sql` | golfcourseapi columns (yardages, tee, course_api_id) |
| `006_scramble.sql` | Allow `'scramble'` format |
| `007_clubhouses.sql` | Clubhouses + tournament link |
| `008_notifications.sql` | Notifications + clubhouse memberships |
| `009_email_invites.sql` | Invite-by-email flow |

All migrations are idempotent — safe to re-run.

### 1.5 Custom domain
1. In Railway → backend service → **Settings** → **Networking** → **Custom Domain**
2. Enter `api.clubhousestakes.com`
3. Railway gives you a CNAME target — copy it
4. Add it as a CNAME record at Namecheap (or Cloudflare if you've moved nameservers)

### 1.6 Promote yourself to admin
After signing up in the app:
```bash
railway run npm run grant-admin -- you@example.com
```

---

## 2. Frontend on Cloudflare Pages

### 2.1 Move DNS to Cloudflare (recommended, optional)
At Namecheap → Domain List → Manage → **Nameservers** → set to Cloudflare's two nameservers (Cloudflare gives them to you when you add the domain). Propagation takes 5-60 min.

If you skip this, you'll add CNAME records at Namecheap directly — works fine, just less convenient.

### 2.2 Add the site
1. Sign up at [pages.cloudflare.com](https://pages.cloudflare.com)
2. **Create application** → **Connect to Git** → select this repo
3. Build settings:
   - **Framework preset**: None
   - **Build command**:
     ```
     cd mobile && flutter build web --release --dart-define=API_BASE_URL=https://api.clubhousestakes.com/api
     ```
   - **Build output directory**: `mobile/build/web`
   - **Root directory**: leave blank (build runs from repo root)
4. Environment variables (Build): no special vars needed — the `--dart-define` flag bakes the API URL in at build time

> **Note**: Cloudflare Pages doesn't have Flutter pre-installed. You'll need to either:
> - Use a build image with Flutter (Cloudflare Pages supports custom Docker images on the Workers Builds plan), or
> - Pre-build locally with `flutter build web --release --dart-define=API_BASE_URL=...` and deploy the `mobile/build/web` folder via `wrangler pages deploy`
>
> For the friends-and-family beta, the simplest path is **manual deploy**:
> ```
> cd mobile
> flutter build web --release --dart-define=API_BASE_URL=https://api.clubhousestakes.com/api
> npx wrangler pages deploy build/web --project-name=clubhouse-stakes
> ```

### 2.3 Custom domain
1. In Cloudflare Pages → your project → **Custom domains** → **Set up a custom domain**
2. Add `www.clubhousestakes.com` and `clubhousestakes.com`
3. Cloudflare configures the DNS automatically if your domain is on Cloudflare; otherwise it gives you records to add at Namecheap

---

## 3. First-run checklist

Once both services are live and the domains resolve:

- [ ] Visit `https://www.clubhousestakes.com` — splash should load, login screen appears
- [ ] Sign up (this creates the first user account)
- [ ] On your machine: `railway run npm run grant-admin -- your-email@here`
- [ ] Refresh app, log out and back in — admin button should appear
- [ ] Create a test tournament with a small entry fee and a $5 skins fee
- [ ] Have a second device sign up, register as a team using partner search
- [ ] Walk through hole-by-hole scoring on both phones
- [ ] Watch the leaderboard + skins tab update live

---

## 3.5 Limitations to be aware of

**Image uploads** — `POST /api/uploads/image` writes files to the backend's local
`uploads/` folder, which Railway treats as ephemeral. Uploads will not survive
a redeploy. For production, plug in S3 / R2 / a CDN (the `uploadController` is
the only file you need to change).

---

## 4. Common gotchas

**API requests fail with CORS error in browser console**
→ Check `CORS_ORIGINS` env var in Railway includes the exact frontend URL (with `https://`, no trailing slash).

**App loads but API calls 404**
→ The `--dart-define` didn't get baked in. Rebuild with `flutter build web --release --dart-define=API_BASE_URL=https://api.clubhousestakes.com/api` and redeploy.

**Login works but admin panel is empty**
→ You haven't been granted admin yet. Run `railway run npm run grant-admin -- your-email@here`.

**"Migration failed" on Railway logs**
→ Run `railway run npm run migrate` manually after the deploy. Migrations are idempotent — safe to re-run.

**PWA "Add to Home Screen" doesn't appear**
→ Site must be served over HTTPS (Cloudflare Pages does this automatically) and visited at least once. Some browsers require user interaction before showing the prompt.

---

## 5. Updating the app

```bash
# Backend: just push to main
git push origin main   # Railway auto-deploys

# Frontend: rebuild and redeploy
cd mobile
flutter build web --release --dart-define=API_BASE_URL=https://api.clubhousestakes.com/api
npx wrangler pages deploy build/web --project-name=clubhouse-stakes
```

---

## 6. Costs (rough estimate)

- Railway: $5 credit/mo free, then ~$5-10/mo for backend + Postgres at this scale
- Cloudflare Pages: free tier (500 builds/mo, unlimited bandwidth)
- Namecheap domain: ~$10/yr (already paid)

Total: **~$5-10/mo**
