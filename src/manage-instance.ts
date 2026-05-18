import path from "node:path";

import { runBotOnce, startBot } from "./bot";
import { loadConfigFromEnvFile } from "./config";
import { runDoctor } from "./doctor";
import { getInstanceEnvFile } from "./instances";

type Mode = "start" | "doctor" | "create-now";

function parseMode(value: string | undefined): Mode {
  if (value === "start" || value === "doctor" || value === "create-now") {
    return value;
  }

  throw new Error("Usage: node dist/manage-instance.js <start|doctor|create-now> <instance-name>");
}

function parseInstanceName(value: string | undefined): string {
  const instanceName = value?.trim();
  if (!instanceName) {
    throw new Error("An instance name is required.");
  }
  return instanceName;
}

async function main(): Promise<void> {
  const mode = parseMode(process.argv[2]);
  const instanceName = parseInstanceName(process.argv[3]);
  const appRootDir = path.resolve(__dirname, "..");
  const envFile = getInstanceEnvFile(appRootDir, instanceName);
  const config = loadConfigFromEnvFile(envFile, instanceName);

  console.info(`[instance] ${config.instanceName}`);

  if (mode === "start") {
    await startBot(config);
    return;
  }

  if (mode === "doctor") {
    await runDoctor(config);
    return;
  }

  await runBotOnce(config);
}

void main().catch((error) => {
  console.error("[instance] Failed", error);
  process.exitCode = 1;
});
