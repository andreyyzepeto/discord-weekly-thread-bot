# Discord Weekly Thread Bot

A `TypeScript + discord.js` bot that creates a weekly public thread in a text channel and posts a guide message inside the thread automatically.

This project supports a multi-instance structure, so one app can run multiple bot configurations (`instance-1`, `instance-2`, and so on).

## How It Works

- Runs every week based on `DAY_OF_WEEK`, `HOUR`, `MINUTE`, and `TIMEZONE`.
- Generates thread titles in a weekly format like `[March Week 4 Feed Boosting Request (03/23~03/29)]`.
- Skips creation if a thread with the same title already exists.
- Posts a guide message right after thread creation and pins it when possible.
- Supports multiple isolated instance configs in one app.

## Required Discord Permissions

- `View Channels`
- `Read Message History`
- `Send Messages`
- `Create Public Threads`
- `Send Messages in Threads`
- `Manage Threads` (recommended)

## Instance Structure

Each bot instance has its own folder:

```text
instances/
  instances.json
  instance-1/
    .env
    guide-message.txt
  instance-2/
    .env
    guide-message.txt
```

- `instances.json` contains active instance names.
- Each instance `.env` contains token, channel ID, and schedule settings.
- Each instance `guide-message.txt` contains its own thread guide message.

## Installation

### ChatGPT Self-Install Kit

This is the recommended path for non-technical Client Admins.

1. Unzip the kit, then **double-click `install.command` in the kit root** (next to `README.md`), **or** open Terminal, `cd` to that folder, and run `zsh install.command`.
2. If Node.js is not installed, the script tries to **download the official Node.js for macOS** into `bot-files/runtime/` (one time, network required) via `scripts/ensure-node-runtime.sh`. If that fails, install LTS from [https://nodejs.org/](https://nodejs.org/) and run the installer again.
3. Read the kit’s root **`README.md`** for the full install, Discord, and troubleshooting guide.

`install.command` in the kit root delegates to this folder’s `install.command` — same script.

The self-install kit keeps end-user documentation in the root **`README.md`** and application code in **`bot-files/`**.

### Manual setup

```bash
npm install
mkdir -p instances/instance-1
cp .env.example instances/instance-1/.env
cp guide-message.txt instances/instance-1/guide-message.txt
printf '%s\n' '["instance-1"]' > instances/instances.json
npm run build
```

Set these values in `instances/instance-1/.env`:

- `DISCORD_TOKEN`: bot token
- `CHANNEL_ID`: target text channel ID
- `DAY_OF_WEEK`: `mon`, `tue`, `wed`, `thu`, `fri`, `sat`, `sun`
- `HOUR`: 0-23
- `MINUTE`: 0-59
- `TIMEZONE`: e.g. `Asia/Seoul`
- `TITLE_SUFFIX`: default `Feed Boosting Request`
- `GUIDE_MESSAGE_FILE`: default `guide-message.txt`
- `AUTO_ARCHIVE_DURATION`: `60`, `1440`, `4320`, `10080`
- `RUN_ON_STARTUP`: run once immediately on startup when `true`
- `PAUSED`: skip login and thread creation when `true`

Any valid IANA timezone is accepted when editing `.env` manually.

### Local macOS installer-style setup

```bash
./install.command
```

- On first run without system Node, the script can populate `runtime/` with a downloaded Node.js (see `scripts/ensure-node-runtime.sh`). Otherwise install Node LTS or rely on a system `node` on `PATH`.
- Enter how many bot instances to configure.
- Prompt: `How many Discord bots do you want to configure in this app? (1-20)`
- For example, if you enter `3`, the setup repeats 3 times.
- For each instance, input `DISCORD_TOKEN`, `CHANNEL_ID`, `TIMEZONE`, `HOUR`, and `TITLE_SUFFIX`.
- `TIMEZONE` is selected from the recommended timezone list.
- Setup stops if a required value is missing or invalid.
- You can optionally edit each instance `guide-message.txt`.
- Then it runs `npm install` and `npm run build`.
- It creates `Start instance-N.app`, `Test instance-N.app`, and `Check instance-N.app`.
- This mode installs in the current project folder.

### Build a macOS `.pkg` installer

```bash
./build-installer.command
```

- Creates `build/DiscordWeeklyThreadBotInstaller.pkg`.
- Creates `build/INSTALL_FIRST_README.txt` with the recommended install command for downloaded Macs.
- During installation, instance count is requested in a GUI prompt.
- A setup guide document may open automatically at install start (depends on the `.pkg` build).
- A readiness double-check step is shown before configuration starts.
- For each instance, input `DISCORD_TOKEN`, `CHANNEL_ID`, `TIMEZONE`, `HOUR`, and `TITLE_SUFFIX`.
- `TIMEZONE` is chosen from the recommended timezone list.
- Setup fails if required values are missing or invalid.
- Optional per-instance `guide-message.txt` editing is supported.
- Installed path: `/Applications/Discord Weekly Thread Bot`.
- Instance configs are created under `/Applications/Discord Weekly Thread Bot/instances/instance-N/`.
- Includes `Start instance-N.app`, `Test instance-N.app`, and `Check instance-N.app`.
- Includes `Uninstall Discord Weekly Thread Bot.app` for one-click removal.
- Bundles both Apple Silicon and Intel Node.js runtimes (Node 22 family).
- No separate Node.js or Python install is required on recipient Macs.
- To pause quickly, set `PAUSED=true` in an instance `.env`.

Important Gatekeeper note:
- Downloaded `.command` helper files may be blocked by macOS before they can run.
- If that happens, use the command in `INSTALL_FIRST_README.txt` to remove quarantine from the extracted installer folder and open the `.pkg`.

## Run

Development mode:

```bash
npm run dev
```

Run one instance continuously:

```bash
./start.command instance-1
```

or:

```bash
npm run start-instance -- instance-1
```

Check one instance connection:

```bash
./doctor.command instance-1
```

or:

```bash
npm run doctor-instance -- instance-1
```

Create one test thread immediately:

```bash
./test-now.command instance-1
```

or:

```bash
npm run create-now -- instance-1
```

Run tests:

```bash
npm test
```

## Uninstall

Open `/Applications/Discord Weekly Thread Bot` and double-click `Uninstall Discord Weekly Thread Bot.app`.

This removes the app folder, configured instances, and saved Discord tokens stored inside that folder.

## Example Config

```env
DISCORD_TOKEN=your_bot_token_here
CHANNEL_ID=123456789012345678
DAY_OF_WEEK=mon
HOUR=9
MINUTE=0
TIMEZONE=Asia/Seoul
TITLE_SUFFIX=Feed Boosting Request
GUIDE_MESSAGE_FILE=guide-message.txt
AUTO_ARCHIVE_DURATION=10080
RUN_ON_STARTUP=false
PAUSED=false
```

## Operations Tips

- Run this bot in an always-on environment (local PC, VPS, etc.).
- Recommended Node version: `22` (see `.nvmrc`).
- You can edit timezone suggestions in `recommended-timezones.txt`.
- In `.pkg` installs, the same file is available at `/Applications/Discord Weekly Thread Bot/recommended-timezones.txt`.
- Reducing instance count does not delete old folders automatically; only instances listed in `instances.json` are active.
- `pm2` example:

```bash
pm2 start ./start.command --name discord-bot-instance-1 -- instance-1
pm2 start ./start.command --name discord-bot-instance-2 -- instance-2
```

- For `systemd`, register one service per instance with `./start.command instance-N`.
- Example service file: `deploy/discord-weekly-thread-bot.service` (adjust path/user).
- Docker example:

```bash
docker build -t discord-weekly-thread-bot .
docker run -v "$(pwd)/instances:/app/instances" discord-weekly-thread-bot ./start.command instance-1
```

## Notes

- v1 currently supports text channels only.
- Previous-thread locking is only reflected in the guide content; automatic locking is not implemented yet.
