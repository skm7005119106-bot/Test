# Kayra ko live karne ki guide

Yeh guide phone se bhi follow ho sakti hai. Har step ke ant me likha hai ki aage kis step me kya value lagegi, isliye ek notes app khol kar values save karte jao.

**Kul kharcha (andaaza):**

| Cheez | Kharcha |
|---|---|
| Google Play Console | $25 ek baar (aapke paas pehle se hai) |
| Anthropic API (Kayra ka AI) | ~₹0.03–0.05 har message; shuru me $5 credit |
| Render server | Free (so jaata hai) ya $7/mahina (hamesha on) |
| Neon database | Free (0.5 GB tak) |
| Google Cloud (login, purchase check) | Free |

Agar ₹ me sochein: roz 30 message karne wala ek user ≈ ₹1/din. 1,000 roz ke users ≈ ₹30,000/mahina. Isliye free limit aur Kayra Plus zaroori hain.

---

## Step 1: Anthropic API key (Kayra ka AI)

1. https://console.anthropic.com par account banao.
2. **Settings > Billing** me card se $5 ka credit daalo.
3. **Settings > Limits** me monthly spend limit lagao (jaise $20), taaki galti se zyada bill na aaye.
4. **Settings > API keys > Create key**, naam `kayra-server`. Key `sk-ant-...` se shuru hogi; abhi copy karo, baad me dobara nahi dikhegi.

Save karo: `ANTHROPIC_API_KEY`.

## Step 2: Database (Neon, free)

1. https://neon.tech par GitHub ya Google se sign up karo.
2. **Create project**: naam `kayra`, region **Asia Pacific (Singapore)**.
3. Dashboard par **Connection string** copy karo (`postgresql://...neon.tech/...?sslmode=require`).

Save karo: `DATABASE_URL`.

## Step 3: Google login ki setting (Google Cloud)

1. https://console.cloud.google.com kholo, upar se **New project** banao, naam `Kayra`.
2. **APIs & Services > OAuth consent screen**:
   - User type: **External**
   - App name: `Kayra`, support email: aapka email
   - App domain me privacy policy: `https://<aapka-render-url>/privacy` (Step 4 ke baad bhar sakte ho)
   - Scopes me kuch add nahi karna. Save karke **Publish app** dabao.
3. **APIs & Services > Credentials > Create credentials > OAuth client ID**:
   - **Web application**, naam `Kayra server`. Bana kar **Client ID** copy karo.
4. Phir se **Create credentials > OAuth client ID**:
   - **Android**, package name: `com.kayraapp.kayra`
   - SHA-1: aapki upload key wali file (`kayra-upload-key.txt`) ke neeche likha SHA-1.
   - Play Store se install hone wale app ke liye ek aur Android client chahiye hoga; woh Step 7 me hai.

Save karo: Web client ka Client ID. Yahi `GOOGLE_WEB_CLIENT_ID` (server ke liye) aur `GOOGLE_SERVER_CLIENT_ID` (app ke liye) dono hai.

## Step 4: Server chalu karo (Render)

1. https://render.com par **GitHub se sign in** karo aur is repository ki access do.
2. **New > Blueprint**, repository `skm7005119106-bot/Test` chuno. Branch: jis branch par yeh code hai (abhi `ccr-589549c9-lkv94n`, ya `main` agar merge kar diya ho).
3. Render `render.yaml` padh kar ye values maangega:
   - `ANTHROPIC_API_KEY`: Step 1 wali key
   - `DATABASE_URL`: Step 2 wala connection string
   - `GOOGLE_WEB_CLIENT_ID`: Step 3 wala Web Client ID
   - `GOOGLE_SERVICE_ACCOUNT_JSON`: abhi khaali chhod do (Step 7 me bharenge)
   - `SUPPORT_EMAIL`: users ke sawaalon ke liye email (privacy policy par dikhega)
4. **Apply** dabao. Kuch minute me URL milega, jaise `https://kayra-backend.onrender.com`.
5. Check karo: `https://<url>/health` par `{"ok":true}` aana chahiye, aur `https://<url>/privacy` par privacy policy.

**Free plan ki baat:** 15 minute koi request na aaye to server so jaata hai, aur agla pehla message ~1 minute lega. Launch ke time service ko **Starter ($7/mahina)** par kar dena.

Save karo: server URL, yahi `KAYRA_API` hai.

## Step 5: GitHub par values daalo aur app banao

Repository par jao: **Settings > Secrets and variables > Actions**.

**Variables** tab > New repository variable:

| Name | Value |
|---|---|
| `KAYRA_API` | Step 4 ka server URL (bina `/` ke ant me) |
| `GOOGLE_SERVER_CLIENT_ID` | Step 3 ka Web Client ID |

**Secrets** tab > New repository secret (teeno values `kayra-upload-key.txt` me hain):

| Name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | file ki lambi line |
| `ANDROID_KEYSTORE_PASSWORD` | file me likha password |
| `ANDROID_KEY_ALIAS` | `upload` |

Phir **Actions > Build Android app > Run workflow**. ~6 minute me build ke neeche do files milengi:
- `kayra-apk`: phone par seedha install karke test karne ke liye
- `kayra-aab-for-play-store`: Play Console me upload karne ke liye

Build ke **Summary** me signing ka SHA-1 bhi likha aayega; woh Step 3 wale SHA-1 se match hona chahiye.

**Upload key sambhal kar rakho.** `kayra-upload-key.txt` ko Google Drive jaisi safe jagah rakho aur kisi ko mat bhejo. Kho jaaye to Play Console support se nayi upload key lagwani padti hai.

## Step 6: Phone par test karo

1. `kayra-apk` zip download karke `app-release.apk` install karo.
2. 18+ tick karke **Google se continue karo**. Naam daalo, Kayra se baat karo.
3. Check karo: jawab aate hain, level badhta hai, mood badalta hai, Settings > Kayra ki yaadein me 8 message ke baad baatein dikhti hain.

Sign-in me error aaye to 99% Step 3 ka SHA-1 ya package name galat hai.

## Step 7: Google Play Console

### 7.1 App banao
**Create app**: naam `Kayra - AI Companion Chat`, App, **Free**, policies accept.

### 7.2 App content (sab bharna zaroori hai)
- **Privacy policy:** `https://<server-url>/privacy`
- **App access:** "All or some functionality is restricted" chuno. Instructions: "Sign in with any Google account and confirm you are 18+."
- **Ads:** No
- **Content rating:** questionnaire imaandaari se bharo. Category: Social/Communication; users AI se chat karte hain; sexual content: No (sirf romantic baatein).
- **Target audience:** sirf **18 and over**
- **Data safety:**
  - Collected: Name, Email address, User IDs, Messages (in-app), Purchase history, Other user-generated content (memories)
  - Purpose: App functionality, Account management
  - Encrypted in transit: Yes
  - Users can request deletion: Yes, URL: `https://<server-url>/delete-account`
  - Shared with third parties: messages Anthropic ko jaate hain (AI jawab ke liye); form me "service provider" ke roop me batao
- **AI-generated content:** app me har Kayra message par long-press karke **Report** ka option hai; review form me yeh batao.

### 7.3 Kayra Plus ke plans
**Monetize > Products > Subscriptions > Create subscription**:

| Product ID | Base plan | Billing period | Price |
|---|---|---|---|
| `kayra_plus_monthly` | `monthly` (auto-renewing) | 1 month | ₹149 |
| `kayra_plus_yearly` | `yearly` (auto-renewing) | 1 year | ₹999 |

Product ID bilkul yahi rakhna; app aur server inhi naamon se plans dhoondhte hain. Dono ko **Activate** karo.

### 7.4 Purchase check karne ki permission (service account)
1. Google Cloud (Step 3 wala project) > **APIs & Services > Library** > "Google Play Android Developer API" > **Enable**.
2. **IAM & Admin > Service accounts > Create**, naam `kayra-play`. Bana kar **Keys > Add key > JSON**; ek file download hogi.
3. Play Console > **Users and permissions > Invite new users** > service account ka email daalo > app permissions: **View financial data** aur **Manage orders and subscriptions** > Invite.
4. Render > kayra-backend > **Environment** > `GOOGLE_SERVICE_ACCOUNT_JSON` me poori JSON file ka text paste karo > Save.

Permission chalu hone me 24–36 ghante tak lag sakte hain.

### 7.5 Testing aur launch
1. **Test and release > Internal testing > Create release**: `kayra-aab-for-play-store` wali `.aab` upload karo. Testers me apna email daalo.
2. Pehle upload ke baad **Test and release > App integrity > App signing** me **App signing key certificate** ka SHA-1 copy karo, aur Google Cloud me Step 3.4 jaisa ek aur **Android OAuth client** banao, usi package name aur is SHA-1 ke saath. Iske bina Play Store wale app me Google login nahi chalega.
3. **Settings > License testing** me apna email daalo, taaki test purchase me asli paise na katen.
4. Naye personal developer accounts ke liye Google ka rule: production se pehle **Closed testing me kam se kam 12 testers, 14 din tak**. Doston ko tester banao.
5. Uske baad **Production > Create release**.

### 7.6 Store listing
- **App icon:** `store/play-icon-512.png`
- **Feature graphic (1024×500)** aur **phone screenshots (kam se kam 2)** abhi banane baaki hain. Screenshots chat screen ke lo; Kayra ki body wali photos listing me mat lagao, Play suggestive images par app reject kar deta hai.
- **Short description (80 akshar):** `Kayra se Hinglish me baat karo: tumhari AI companion jo yaad rakhti hai`
- **Full description (shuruaat):**

  > Kayra ek AI companion hai jo tumhari baat sunti hai, samajhti hai aur Hinglish me pyaar se jawab deti hai. Jitni baat karoge, utna rishta gehra hoga: Stranger se Dost, Crush aur aage. Uska mood chuno, quick replies se jaldi jawab do, aur dekho Kayra tumhare baare me kya yaad rakhti hai.
  >
  > Kayra ek AI character hai, real insaan nahi. Yeh app sirf 18+ ke liye hai.

---

## Code ka naksha

| Jagah | Kya hai |
|---|---|
| `backend/` | Node.js server: Google login, chat (Claude Haiku 5.5), level/streak/moods, memories, Kayra Plus check, privacy pages |
| `app/` | Flutter Android app |
| `render.yaml` | Render par server chalane ki setting |
| `.github/workflows/` | GitHub par app build aur backend tests |
| `store/` | Play Store ka icon |

Backend tests: `cd backend && npm test` (Postgres par bhi chalane ke liye `TEST_DATABASE_URL` set karo).
App tests: `cd app && flutter test`.
