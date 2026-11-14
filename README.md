# Kayra

Kayra ek AI companion (virtual girlfriend) chat app hai, 18+ users ke liye. Yeh repo do hisson me hai:

- `backend/` : Node.js server. Kayra ka character, Claude API se jawab, daily free-message limit, memory aur message reports yahin hain.
- `app/` : Flutter app (Android + web). Onboarding, chat screen, report button, data delete.

## Abhi kya bana hai

- 18+ confirmation ke saath onboarding, aur har jagah saaf likha hai ki Kayra AI hai
- Hinglish me chat, Kayra ko user ka naam aur pichli baatein yaad rehti hain
- Har device ko roz 30 free messages (raat 12 baje IST par reset)
- Kayra ke kisi bhi message ko long-press karke report karna
- "Mera data delete karo" option
- Limit khatam hone par Kayra Plus ki screen (payment abhi juda nahi hai)

## Abhi kya baaki hai

- Google Play Billing (Kayra Plus subscription aur coins)
- Login (abhi sirf device id hai, to app reinstall karne par limit reset ho jaati hai)
- Push notifications, voice notes, selfies
- Kayra ki images aur app icon
- Privacy policy page

## Backend chalana

Zaroorat: Node.js 22.13 ya naya, aur Anthropic API key (console.anthropic.com se).

```bash
cd backend
npm install
export ANTHROPIC_API_KEY=sk-ant-...
npm start
```

Settings (environment variables, sab optional): `PORT` (8080), `FREE_DAILY_LIMIT` (30), `KAYRA_MODEL` (`claude-haiku-5-5`), `KAYRA_DB_PATH` (`kayra.db`).

Tests: `npm test`

API key sirf server par rehti hai. Use app ke code me kabhi mat daalna.

## App chalana

Zaroorat: Flutter SDK (flutter.dev se install karo).

```bash
cd app
flutter pub get
flutter test
flutter run --dart-define=KAYRA_API=https://tumhara-server.example
```

APK banane ke liye:

```bash
flutter build apk --dart-define=KAYRA_API=https://tumhara-server.example
```

`KAYRA_API` backend ka address hai. Play Store wale build ke liye yeh `https` hona chahiye.
