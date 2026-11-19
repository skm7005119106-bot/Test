# Kayra

Kayra ek AI companion (virtual girlfriend) chat app hai, 18+ users ke liye, Android par. Kayra Hinglish me baat karti hai; uske jawab Anthropic ke Claude (Haiku 5.5) se aate hain.

**Live karne ke steps: [SETUP.md](SETUP.md)**

## Features

- Google se login; chat, level aur subscription server par, isliye phone badalne par bhi saath
- Hinglish chat, typing animation, message ka time, emoji reactions, har jawab ke baad 3 quick replies
- Rishta level (Stranger → Dost → Crush → Girlfriend → Soulmate) aur roz ki streak; level ke saath Kayra ka andaaz badalta hai
- Moods: Sweet, Funny, Flirty (Crush level par), Shy (Kayra Plus)
- Kayra ka profile: bio, pasand-napasand, photos jo level ya Plus se khulti hain
- Memories: Kayra user ke baare me baatein yaad rakhti hai; user Settings me dekh aur hata sakta hai
- Kayra Plus (Google Play subscription): roz 300 messages (free me 30), Shy mood, saari photos, 40 yaadein; purchase server par Google se verify hota hai
- Settings: naam badalna, privacy policy, chat saaf karna, sign out, account delete
- Safety: 18+ gate, har jagah "AI hai" ka disclosure, message report, explicit content nahi, self-harm par Tele-MANAS 14416

## Folders

- `backend/`: Node.js + Express server (Postgres ya SQLite)
- `app/`: Flutter app
- `render.yaml`: server hosting ki setting
- `.github/workflows/`: APK/AAB build aur backend tests
