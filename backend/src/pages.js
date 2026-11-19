// Public pages Google Play asks for: a privacy policy and how to delete an account.

const style = `
  body { font: 16px/1.6 system-ui, sans-serif; max-width: 720px; margin: 0 auto; padding: 24px 16px; color: #1d1626; background: #fff; }
  h1 { font-size: 1.8rem; margin-bottom: 0; } h2 { font-size: 1.15rem; margin-top: 2rem; }
  .muted { color: #6b5d78; } li { margin: 4px 0; }
  @media (prefers-color-scheme: dark) { body { background: #0d0716; color: #f6ecff; } .muted { color: #a994c6; } a { color: #ff8cc6; } }
`;

function page(title, body) {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title><style>${style}</style></head><body>${body}</body></html>`;
}

function escapeHtml(text) {
  return text.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}

function contact(email) {
  return email
    ? `<p>Questions or requests: <a href="mailto:${escapeHtml(email)}">${escapeHtml(email)}</a></p>`
    : "";
}

export function privacyPage({ supportEmail, updated }) {
  return page(
    "Kayra Privacy Policy",
    `<h1>Kayra Privacy Policy</h1>
<p class="muted">Last updated ${escapeHtml(updated)}</p>
<p>Kayra is an AI companion chat app for adults (18+). Kayra is an AI character, not a real person. This policy explains what the app collects and why.</p>

<h2>What we collect</h2>
<ul>
  <li><b>Google account basics</b>: your Google account id, email address and first name, when you sign in with Google.</li>
  <li><b>What you tell the app</b>: your name, the name you want Kayra to call you, your chat messages, reactions, and the mood you pick.</li>
  <li><b>Memories</b>: short notes about you that the app writes from your chats (for example your city or what you like), so Kayra can remember them. You can see and delete them in the app under Settings &gt; Memories.</li>
  <li><b>Progress</b>: your relationship level points, daily streak and how many messages you send each day.</li>
  <li><b>Purchases</b>: if you buy Kayra Plus, Google Play gives us a purchase token, the plan and its expiry date. We never see your card or UPI details.</li>
  <li><b>Reports</b>: messages you report, and the reason.</li>
</ul>

<h2>How we use it</h2>
<ul>
  <li>To run the chat, keep your history across devices, and apply the free daily limit or your Kayra Plus plan.</li>
  <li>Your recent messages, memories and profile are sent to Anthropic's Claude API to write Kayra's replies. Under Anthropic's commercial terms, data sent through its API is not used to train its models.</li>
  <li>Reported messages are reviewed to improve safety.</li>
</ul>
<p>We do not sell your data, show ads, or share your data with anyone other than the service providers needed to run the app (Anthropic for AI replies, Google for sign-in and payments, and our hosting and database providers).</p>

<h2>How long we keep it</h2>
<p>We keep your data while your account exists. When you delete your account, your profile, chats, memories, progress and sessions are deleted right away. Purchase records are kept only as long as needed for billing and legal obligations.</p>

<h2>Your choices</h2>
<ul>
  <li>Delete individual memories, or clear your chat history, in Settings.</li>
  <li>Delete your account and all its data in Settings &gt; Delete account. See <a href="/delete-account">how to delete your account</a>.</li>
</ul>

<h2>Age</h2>
<p>Kayra is only for people aged 18 or older. We do not knowingly collect data from anyone under 18; if you believe a minor is using the app, contact us and we will delete the account.</p>

<h2>Security</h2>
<p>Data is sent over encrypted connections (HTTPS) and stored with our hosting and database providers.</p>

<h2>Help in a crisis</h2>
<p>Kayra is not a therapist. If you are struggling, call Tele-MANAS on 14416 (free, 24x7, India) or talk to someone you trust.</p>
${contact(supportEmail)}`,
  );
}

export function deleteAccountPage({ supportEmail }) {
  return page(
    "Delete your Kayra account",
    `<h1>Delete your Kayra account</h1>
<p>You can delete your Kayra account and all its data from inside the app:</p>
<ol>
  <li>Open Kayra and tap the menu at the top right of the chat.</li>
  <li>Open <b>Settings</b>.</li>
  <li>Tap <b>Delete account</b> and confirm.</li>
</ol>
<p>This deletes your profile, chat history, memories, progress and sign-in sessions immediately. It cannot be undone.</p>
<p><b>Kayra Plus:</b> deleting your account does not cancel a Google Play subscription. Cancel it in the Play Store under Profile &gt; Payments &amp; subscriptions &gt; Subscriptions.</p>
${supportEmail ? `<p>If you can no longer open the app, email <a href="mailto:${escapeHtml(supportEmail)}">${escapeHtml(supportEmail)}</a> from the Google account you signed in with, and we will delete the account within 7 days.</p>` : ""}`,
  );
}
