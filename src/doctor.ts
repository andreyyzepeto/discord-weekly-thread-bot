import dotenv from "dotenv";

import { BotConfig, loadConfig } from "./config";

dotenv.config();

export async function runDoctor(config: BotConfig): Promise<void> {
  const authHeader = { Authorization: `Bot ${config.discordToken}` };

  const userResponse = await fetch("https://discord.com/api/v10/users/@me", {
    headers: authHeader,
  });

  if (!userResponse.ok) {
    const body = await userResponse.text();
    console.error("[doctor] Token check failed");
    console.error(`[doctor] /users/@me -> ${userResponse.status}`);
    console.error(`[doctor] Response: ${body}`);
    process.exitCode = 1;
    return;
  }

  const user = (await userResponse.json()) as { id: string; username: string };
  console.info(`[doctor] Token OK for bot ${user.username} (${user.id})`);

  const channelResponse = await fetch(
    `https://discord.com/api/v10/channels/${config.channelId}`,
    { headers: authHeader },
  );

  if (!channelResponse.ok) {
    const body = await channelResponse.text();
    console.error("[doctor] Channel check failed");
    console.error(`[doctor] /channels/${config.channelId} -> ${channelResponse.status}`);
    console.error(`[doctor] Response: ${body}`);
    process.exitCode = 1;
    return;
  }

  const channel = (await channelResponse.json()) as {
    id: string;
    type: number;
    name?: string;
  };

  console.info(
    `[doctor] Channel OK: ${channel.name ?? "(unnamed)"} (${channel.id}), type=${channel.type}`,
  );
}

async function main(): Promise<void> {
  const config = loadConfig();
  await runDoctor(config);
}

void main().catch((error) => {
  console.error("[doctor] Unexpected failure", error);
  process.exitCode = 1;
});
