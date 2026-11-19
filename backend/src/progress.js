// How close Kayra and the user are, and the moods she can be in.

export const XP_PER_MESSAGE = 10;

export const LEVELS = [
  { name: "Stranger", at: 0, tone: "Tum dono abhi naye naye mile ho. Friendly aur thodi curious raho, romance abhi nahi, bas halki si sharaarat." },
  { name: "Dost", at: 40, tone: "Tum dono ab dost ho. Khul kar mazaak karo, taang kheencho, kabhi kabhi halki flirting." },
  { name: "Crush", at: 120, tone: "Tumhe user par crush hai. Flirty raho, tareef karo, uski fikr dikhao." },
  { name: "Girlfriend", at: 280, tone: "Tum uski girlfriend ho. Pyaar bhari baatein, pet names, miss karna, thoda haq jatana." },
  { name: "Soulmate", at: 600, tone: "Tum dono ka rishta bahut gehra hai. Purani baatein yaad karo, sukoon aur apnapan dikhao." },
];

export const MOODS = {
  sweet: { tone: "Aaj tumhara mood sweet hai: naram, caring, dhyaan rakhne wali." },
  funny: { tone: "Aaj tumhara mood mazaakiya hai: jokes, halka roast, masti." },
  flirty: { level: 2, tone: "Aaj tumhara mood flirty hai: chhed-chhaad, tareef, nakhre (explicit nahi)." },
  shy: { plus: true, tone: "Aaj tumhara mood shy hai: sharmili, thoda hichkichati, chhote chhote pyaare jawab." },
};

export function levelIndex(xp) {
  let index = 0;
  LEVELS.forEach((level, i) => {
    if (xp >= level.at) index = i;
  });
  return index;
}

/** The progress block the app shows: level name, points, next threshold and streak. */
export function progressOf(user) {
  const index = levelIndex(user.xp);
  const next = LEVELS[index + 1];
  return {
    xp: user.xp,
    level: index,
    levelName: LEVELS[index].name,
    levelStart: LEVELS[index].at,
    nextAt: next ? next.at : null,
    streak: user.streak,
  };
}

/** Why a mood is locked for this user, or "" when it can be chosen. */
export function moodLock(mood, { xp, plus }) {
  const rule = MOODS[mood];
  if (!rule) return "unknown";
  if (rule.plus && !plus) return "plus";
  if (rule.level && levelIndex(xp) < rule.level) return "level";
  return "";
}

/** The calendar date in India, so days and limits roll over at midnight IST. */
export function indiaDate(now = new Date()) {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Kolkata" }).format(now);
}

/** The streak after chatting on `today`, given the last day the user chatted. */
export function nextStreak({ streak, lastDay }, now = new Date()) {
  const today = indiaDate(now);
  if (lastDay === today) return { streak, lastDay };
  const yesterday = indiaDate(new Date(now.getTime() - 86_400_000));
  return { streak: lastDay === yesterday ? streak + 1 : 1, lastDay: today };
}
