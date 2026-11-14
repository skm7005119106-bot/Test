import Anthropic from "@anthropic-ai/sdk";
import { createApp } from "./app.js";
import { openStore } from "./store.js";

const port = Number(process.env.PORT || 8080);
const store = openStore(process.env.KAYRA_DB_PATH || "kayra.db");
const app = createApp({
  client: new Anthropic(), // reads ANTHROPIC_API_KEY from the environment
  store,
  freeDailyLimit: Number(process.env.FREE_DAILY_LIMIT || 30),
});

app.listen(port, () => console.log(`Kayra backend listening on port ${port}`));
