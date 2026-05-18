import fs from "node:fs";
import path from "node:path";

import dotenv from "dotenv";
import { IANAZone } from "luxon";

const VALID_DAYS = new Set(["mon", "tue", "wed", "thu", "fri", "sat", "sun"]);
const VALID_AUTO_ARCHIVE_DURATIONS = new Set([60, 1440, 4320, 10080]);

export type DayOfWeek = "mon" | "tue" | "wed" | "thu" | "fri" | "sat" | "sun";

export interface BotConfig {
  instanceName: string;
  instanceDir: string;
  discordToken: string;
  channelId: string;
  dayOfWeek: DayOfWeek;
  hour: number;
  minute: number;
  timezone: string;
  titleSuffix: string;
  guideMessageFile: string;
  autoArchiveDuration: 60 | 1440 | 4320 | 10080;
  runOnStartup: boolean;
  paused: boolean;
}

function requireEnv(env: Record<string, string | undefined>, name: string): string {
  const value = env[name]?.trim();
  if (!value) {
    throw new Error(`${name} is required.`);
  }
  return value;
}

function parseInteger(
  env: Record<string, string | undefined>,
  name: string,
  min: number,
  max: number,
): number {
  const value = requireEnv(env, name);
  const parsed = Number.parseInt(value, 10);

  if (!Number.isInteger(parsed) || parsed < min || parsed > max) {
    throw new Error(`${name} must be an integer between ${min} and ${max}.`);
  }

  return parsed;
}

function parseBoolean(value: string | undefined, defaultValue: boolean): boolean {
  if (!value) {
    return defaultValue;
  }

  return ["1", "true", "yes", "on"].includes(value.trim().toLowerCase());
}

function resolveGuideMessageFile(
  env: Record<string, string | undefined>,
  instanceDir: string,
): string {
  const configuredPath = env.GUIDE_MESSAGE_FILE?.trim();
  if (!configuredPath) {
    return path.join(instanceDir, "guide-message.txt");
  }

  return path.isAbsolute(configuredPath)
    ? configuredPath
    : path.resolve(instanceDir, configuredPath);
}

function loadConfigFromEnvironment(
  env: Record<string, string | undefined>,
  instanceDir: string,
  instanceName: string,
): BotConfig {
  const dayOfWeek = requireEnv(env, "DAY_OF_WEEK").toLowerCase();
  if (!VALID_DAYS.has(dayOfWeek)) {
    throw new Error("DAY_OF_WEEK must be one of mon, tue, wed, thu, fri, sat, sun.");
  }

  const timezone = requireEnv(env, "TIMEZONE");
  if (!IANAZone.isValidZone(timezone)) {
    throw new Error(`TIMEZONE must be a valid IANA timezone. Received: ${timezone}`);
  }

  const autoArchiveDuration = parseInteger(env, "AUTO_ARCHIVE_DURATION", 1, 10080);
  if (!VALID_AUTO_ARCHIVE_DURATIONS.has(autoArchiveDuration)) {
    throw new Error("AUTO_ARCHIVE_DURATION must be one of 60, 1440, 4320, 10080.");
  }

  const channelId = requireEnv(env, "CHANNEL_ID");
  if (!/^\d+$/.test(channelId)) {
    throw new Error("CHANNEL_ID must contain only digits.");
  }

  return {
    instanceName,
    instanceDir,
    discordToken: requireEnv(env, "DISCORD_TOKEN"),
    channelId,
    dayOfWeek: dayOfWeek as DayOfWeek,
    hour: parseInteger(env, "HOUR", 0, 23),
    minute: parseInteger(env, "MINUTE", 0, 59),
    timezone,
    titleSuffix: env.TITLE_SUFFIX?.trim() || "Feed Boosting Request",
    guideMessageFile: resolveGuideMessageFile(env, instanceDir),
    autoArchiveDuration: autoArchiveDuration as BotConfig["autoArchiveDuration"],
    runOnStartup: parseBoolean(env.RUN_ON_STARTUP, false),
    paused: parseBoolean(env.PAUSED, false),
  };
}

export function loadConfigFromEnvFile(envFile: string, instanceName: string): BotConfig {
  const envContent = fs.readFileSync(envFile, "utf8");
  const parsed = dotenv.parse(envContent);
  return loadConfigFromEnvironment(parsed, path.dirname(envFile), instanceName);
}

export function loadConfig(): BotConfig {
  return loadConfigFromEnvironment(
    process.env,
    process.cwd(),
    process.env.DISCORD_BOT_INSTANCE_NAME?.trim() || "default",
  );
}
