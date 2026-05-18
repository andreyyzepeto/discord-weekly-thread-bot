import dotenv from "dotenv";

import { startBot } from "./bot";
import { loadConfig } from "./config";

dotenv.config();

async function main(): Promise<void> {
  const config = loadConfig();
  await startBot(config);
}

void main().catch((error) => {
  console.error("[fatal] Bot startup failed", error);
  process.exitCode = 1;
});
