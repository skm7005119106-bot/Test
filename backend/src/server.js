import Anthropic from "@anthropic-ai/sdk";
import { createApp } from "./app.js";
import { openDb } from "./db.js";
import { googleTokenVerifier, playSubscriptionVerifier } from "./google.js";

function required(name) {
  const value = process.env[name];
  if (!value) {
    console.error(`Missing environment variable ${name}. See SETUP.md.`);
    process.exit(1);
  }
  return value;
}

const port = Number(process.env.PORT || 8080);
required("ANTHROPIC_API_KEY");
const googleClientId = required("GOOGLE_WEB_CLIENT_ID");

let verifyPurchase = null;
if (process.env.GOOGLE_SERVICE_ACCOUNT_JSON) {
  verifyPurchase = playSubscriptionVerifier({
    packageName: process.env.PLAY_PACKAGE_NAME || "com.kayraapp.kayra",
    credentials: JSON.parse(process.env.GOOGLE_SERVICE_ACCOUNT_JSON),
  });
} else {
  console.warn("GOOGLE_SERVICE_ACCOUNT_JSON is not set: Kayra Plus purchases cannot be verified yet.");
}

const db = await openDb(process.env.DATABASE_URL || "kayra.db");
const app = createApp({
  db,
  claude: new Anthropic(), // reads ANTHROPIC_API_KEY
  verifyGoogleToken: googleTokenVerifier(googleClientId),
  verifyPurchase,
  config: {
    freeDailyLimit: Number(process.env.FREE_DAILY_LIMIT || 30),
    plusDailyLimit: Number(process.env.PLUS_DAILY_LIMIT || 300),
    supportEmail: process.env.SUPPORT_EMAIL || "",
  },
});

app.listen(port, () => console.log(`Kayra backend on port ${port} (${db.dialect})`));
