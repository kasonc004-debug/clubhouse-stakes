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

| Key | Value |
|---|---|
| `NODE_ENV` | `production` |
| `JWT_SECRET` | run `node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"` and paste the result |
| `CORS_ORIGINS` | `https://www.clubhousestakes.com,https://clubhousestakes.com` |

(Leave `DATABASE_URL` alone — Railway sets it automatically.)

### 1.4 Run migrations
After the first deploy succeeds:
```bash
# Install Railway CLI: https://docs.railway.app/develop/cli
railway link
railway run npm run migrate
```

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
