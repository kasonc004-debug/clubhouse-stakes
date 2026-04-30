# Clubhouse Stakes

Skill-based golf tournament competition app for iOS and Android.

---

## Project Structure

```
Clubhouse Stakes/
├── backend/          ← Node.js + Express + PostgreSQL API
└── mobile/           ← Flutter app (iOS + Android)
```

---

## Backend Setup

### Prerequisites
- Node.js 18+
- PostgreSQL 14+

### 1. Install dependencies
```bash
cd backend
npm install
```

### 2. Configure environment
```bash
cp .env.example .env
# Edit .env with your database credentials and JWT secret
```

### 3. Create database
```bash
psql -U postgres -c "CREATE DATABASE clubhouse_stakes;"
```

### 4. Run migrations
```bash
npm run migrate
```

### 5. Seed sample data (optional)
```bash
npm run seed
```

### 6. Start the server
```bash
npm run dev        # development (nodemon)
npm start          # production
```

API runs on `http://localhost:3000`

### API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /api/auth/signup | — | Create account |
| POST | /api/auth/login | — | Email login |
| POST | /api/auth/apple | — | Apple Sign-In |
| GET | /api/auth/me | ✓ | Get current user |
| PATCH | /api/auth/me | ✓ | Update profile |
| GET | /api/tournaments | — | List tournaments (filter by city) |
| GET | /api/tournaments/:id | — | Tournament detail + purse |
| POST | /api/tournaments/:id/join | ✓ | Register for individual tournament |
| GET | /api/tournaments/:id/participants | — | Participant list |
| GET | /api/teams?tournament_id= | — | List teams |
| POST | /api/teams/create | ✓ | Create fourball team |
| POST | /api/teams/:id/join | ✓ | Join existing team |
| POST | /api/scores/submit | ✓ | Submit 18-hole scorecard |
| GET | /api/scores/:tournament_id/me | ✓ | Get my score |
| GET | /api/leaderboard/:tournament_id | — | Live leaderboard |
| POST | /api/admin/tournaments | ✓ Admin | Create tournament |
| PATCH | /api/admin/tournaments/:id | ✓ Admin | Update tournament |

---

## Flutter App Setup

### Prerequisites
- Flutter 3.13+ (`flutter --version`)
- Xcode 15+ (for iOS builds)
- Android Studio / Android SDK (for Android builds)

### 1. Install dependencies
```bash
cd mobile
flutter pub get
```

### 2. Configure API URL
Edit `lib/core/constants/api_constants.dart`:
```dart
// Change for production:
static const String baseUrl = 'https://your-api.com/api';
```

### 3. Run on simulator/device
```bash
flutter run                     # picks connected device
flutter run -d ios              # iOS simulator
flutter run -d android          # Android emulator
```

---

## Building for App Stores

### iOS — Apple App Store

1. Open `mobile/ios/Runner.xcworkspace` in Xcode
2. Set your **Team** and **Bundle ID** (`com.yourcompany.clubhousestakes`)
3. Add **Sign In with Apple** capability in Signing & Capabilities
4. Merge the keys from `ios/Runner/Info.plist.additions` into `Info.plist`
5. Archive and upload:
```bash
flutter build ios --release
# Then Archive in Xcode → Distribute App → App Store Connect
```

### Android — Google Play Store

1. Generate a keystore:
```bash
keytool -genkey -v -keystore release.jks -alias clubhouse \
  -keyalg RSA -keysize 2048 -validity 10000
```
2. Set environment variables: `KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`
3. Build release bundle:
```bash
flutter build appbundle --release
# Upload the .aab file to Google Play Console
```

---

## Database Schema

```
users              → id, name, email, password_hash, apple_id, handicap, city, is_admin
tournaments        → id, name, city, date, format, sign_up_fee, max_players, fee_per, status
teams              → id, tournament_id, name, created_by
team_members       → id, team_id, user_id
entries            → id, user_id, tournament_id, team_id, hole_scores[], gross_score, net_score
payouts            → id, tournament_id, user_id, team_id, position, amount
```

---

## Scoring Logic

**Individual:** Net score = gross − handicap. Ranked by net score ascending.

**Four-Ball (Best Ball):** Per hole, each player's net score = raw score − (handicap/18).
Team score per hole = lower of the two net scores. Team total = sum of all 18 best scores.

---

## Sample Login Credentials (after seeding)

| Name | Email | Password | Role |
|------|-------|----------|------|
| Admin User | admin@clubhousestakes.com | Password123! | Admin |
| Jordan Pierce | jordan@example.com | Password123! | Player |
| Taylor Brooks | taylor@example.com | Password123! | Player |

---

## Preparing for Production

- [ ] Replace `JWT_SECRET` with a strong random secret (32+ chars)
- [ ] Switch `ApiConstants.baseUrl` to your production API URL
- [ ] Remove localhost exception from iOS `Info.plist` ATS section
- [ ] Enable HTTPS on backend (nginx + Let's Encrypt recommended)
- [ ] Add Stripe: replace simulated payment flow with `stripe_flutter` SDK
- [ ] Add crash reporting: Firebase Crashlytics or Sentry
- [ ] Add push notifications for tournament reminders (Firebase Cloud Messaging)
- [ ] Upload App Store assets: icon (1024×1024), screenshots, privacy policy URL

---

## Future Tournament Formats

The codebase is designed to support additional formats by extending:
- `tournaments.format` column (add `scramble`, `skins`, etc.)
- `leaderboardController.js` with new scoring logic functions
- Flutter leaderboard screen with format-specific widgets

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3 + Dart |
| State Management | Riverpod 2 |
| Navigation | go_router |
| HTTP Client | Dio |
| Secure Storage | flutter_secure_storage |
| Apple Sign-In | sign_in_with_apple |
| Backend | Node.js + Express |
| Database | PostgreSQL 14 |
| Auth | JWT (jsonwebtoken) |
| Passwords | bcryptjs |
