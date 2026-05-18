import { CronJob } from "cron";
import {
  AnyThreadChannel,
  ChannelType,
  Client,
  GatewayIntentBits,
  RESTJSONErrorCodes,
  TextChannel,
} from "discord.js";
import { DateTime } from "luxon";

import { BotConfig } from "./config";
import { loadGuideMessage } from "./messages";
import { renderThreadTitle } from "./title";

function getScheduleDate(config: BotConfig, now = DateTime.now()): DateTime {
  return now.setZone(config.timezone);
}

function createClient(): Client {
  const client = new Client({
    intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages],
  });

  client.on("error", (error) => {
    console.error("[client] Discord client error", error);
  });

  return client;
}

function logPaused(config: BotConfig, mode: "start" | "create-now"): void {
  console.info(`[paused] Instance ${config.instanceName} is paused. Skipping ${mode}.`);
}

async function loginClient(client: Client, token: string): Promise<void> {
  await client.login(token);
  await new Promise<void>((resolve) => {
    if (client.isReady()) {
      resolve();
      return;
    }

    client.once("ready", () => resolve());
  });
  console.info(`[ready] Logged in as ${client.user?.tag ?? "unknown-user"}`);
}

async function findExistingThread(
  channel: TextChannel,
  expectedName: string,
): Promise<AnyThreadChannel | null> {
  const activeThreads = await channel.threads.fetchActive();
  const activeMatch = activeThreads.threads.find((thread) => thread.name === expectedName);
  if (activeMatch) {
    return activeMatch;
  }

  const archivedThreads = await channel.threads.fetchArchived({
    type: "public",
    limit: 100,
  });
  return archivedThreads.threads.find((thread) => thread.name === expectedName) ?? null;
}

async function pinGuideMessage(thread: AnyThreadChannel, guideMessage: string): Promise<void> {
  const firstBatch = await thread.messages.fetch({ limit: 5 });
  const postedGuideMessage = firstBatch.find((message) => message.content === guideMessage);
  if (!postedGuideMessage) {
    return;
  }

  try {
    await postedGuideMessage.pin();
    console.info(`[pin] Pinned guide message in thread ${thread.id}`);
  } catch (error) {
    if (
      typeof error === "object" &&
      error !== null &&
      "code" in error &&
      error.code === RESTJSONErrorCodes.MissingPermissions
    ) {
      console.warn(`[pin] Missing permission to pin guide message in thread ${thread.id}`);
      return;
    }
    console.warn(`[pin] Failed to pin guide message in thread ${thread.id}`, error);
  }
}

export async function createWeeklyThread(client: Client, config: BotConfig): Promise<void> {
  const scheduleDate = getScheduleDate(config);
  const threadTitle = renderThreadTitle(scheduleDate, config.titleSuffix);
  const guideMessage = loadGuideMessage(config.guideMessageFile);

  const fetchedChannel = await client.channels.fetch(config.channelId);
  if (!fetchedChannel) {
    throw new Error(`Channel ${config.channelId} was not found.`);
  }
  if (fetchedChannel.type !== ChannelType.GuildText) {
    throw new Error(`Channel ${config.channelId} must be a guild text channel.`);
  }

  const channel = fetchedChannel as TextChannel;
  const existingThread = await findExistingThread(channel, threadTitle);
  if (existingThread) {
    console.info(`[skip] Thread already exists: ${threadTitle} (${existingThread.id})`);
    return;
  }

  console.info(`[create] Creating thread ${threadTitle}`);
  const parentMessage = await channel.send(threadTitle);
  const thread = await parentMessage.startThread({
    name: threadTitle,
    autoArchiveDuration: config.autoArchiveDuration,
    reason: `Weekly thread scheduled for ${scheduleDate.toISO()}`,
  });

  await thread.send(guideMessage);
  await pinGuideMessage(thread, guideMessage);
  console.info(`[create] Thread created successfully: ${thread.id}`);
}

export async function runBotOnce(config: BotConfig): Promise<void> {
  if (config.paused) {
    logPaused(config, "create-now");
    return;
  }

  const client = createClient();
  try {
    await loginClient(client, config.discordToken);
    await createWeeklyThread(client, config);
  } finally {
    client.destroy();
  }
}

export async function startBot(config: BotConfig): Promise<void> {
  if (config.paused) {
    logPaused(config, "start");
    return;
  }

  const client = createClient();

  const cronExpression = `${config.minute} ${config.hour} * * ${config.dayOfWeek}`;

  client.once("ready", async () => {
    console.info(`[ready] Logged in as ${client.user?.tag ?? "unknown-user"}`);
    console.info(
      `[schedule] ${config.dayOfWeek} ${String(config.hour).padStart(2, "0")}:${String(
        config.minute,
      ).padStart(2, "0")} (${config.timezone})`,
    );

    const job = CronJob.from({
      cronTime: cronExpression,
      onTick: async () => {
        try {
          await createWeeklyThread(client, config);
        } catch (error) {
          console.error("[schedule] Failed to create weekly thread", error);
        }
      },
      start: true,
      timeZone: config.timezone,
    });

    if (!job.isActive) {
      job.start();
    }

    if (config.runOnStartup) {
      try {
        await createWeeklyThread(client, config);
      } catch (error) {
        console.error("[startup] Failed to create weekly thread", error);
      }
    }
  });

  await client.login(config.discordToken);
}
