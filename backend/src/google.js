import { OAuth2Client } from "google-auth-library";
import { androidpublisher, auth } from "@googleapis/androidpublisher";

/**
 * Checks a Google ID token from the app's "Sign in with Google" button.
 * `clientId` is the OAuth *Web* client id the app passes as serverClientId.
 */
export function googleTokenVerifier(clientId) {
  const client = new OAuth2Client();
  return async (idToken) => {
    const ticket = await client.verifyIdToken({ idToken, audience: clientId });
    const payload = ticket.getPayload();
    if (!payload?.sub || payload.email_verified === false) throw new Error("unverified account");
    return {
      id: `g_${payload.sub}`,
      email: payload.email || "",
      name: payload.given_name || payload.name || "",
    };
  };
}

// Subscription states that still give access until the expiry time.
const ACTIVE_STATES = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  "SUBSCRIPTION_STATE_CANCELED",
]);

/**
 * Looks up a Google Play subscription purchase token with the Play Developer API.
 * `credentials` is the parsed JSON key of a service account that has access in Play Console.
 */
export function playSubscriptionVerifier({ packageName, credentials }) {
  const publisher = androidpublisher({
    version: "v3",
    auth: new auth.GoogleAuth({
      credentials,
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    }),
  });
  return async (purchaseToken) => {
    const { data } = await publisher.purchases.subscriptionsv2.get({ packageName, token: purchaseToken });
    const items = data.lineItems || [];
    const expiry = Math.max(0, ...items.map((item) => Date.parse(item.expiryTime || "") || 0));
    return {
      productId: items[0]?.productId || "",
      expiry,
      active: ACTIVE_STATES.has(data.subscriptionState),
      state: data.subscriptionState || "",
      accountId: data.externalAccountIdentifiers?.obfuscatedExternalAccountId || "",
    };
  };
}
