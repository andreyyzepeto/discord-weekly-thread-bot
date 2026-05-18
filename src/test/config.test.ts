import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import { loadConfigFromEnvFile } from "../config";

function writeEnvFile(contents: string): string {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "discord-bot-config-"));
  const envFile = path.join(tempDir, ".env");
  fs.writeFileSync(envFile, contents);
  return envFile;
}

test("loadConfigFromEnvFile parses PAUSED=true", () => {
  const envFile = writeEnvFile(`DISCORD_TOKEN=test-token
CHANNEL_ID=123456789012345678
DAY_OF_WEEK=mon
HOUR=9
MINUTE=0
TIMEZONE=Asia/Seoul
AUTO_ARCHIVE_DURATION=10080
RUN_ON_STARTUP=false
PAUSED=true
`);

  const config = loadConfigFromEnvFile(envFile, "instance-1");

  assert.equal(config.paused, true);
});

test("loadConfigFromEnvFile defaults PAUSED to false", () => {
  const envFile = writeEnvFile(`DISCORD_TOKEN=test-token
CHANNEL_ID=123456789012345678
DAY_OF_WEEK=mon
HOUR=9
MINUTE=0
TIMEZONE=Asia/Seoul
AUTO_ARCHIVE_DURATION=10080
RUN_ON_STARTUP=false
`);

  const config = loadConfigFromEnvFile(envFile, "instance-1");

  assert.equal(config.paused, false);
});
