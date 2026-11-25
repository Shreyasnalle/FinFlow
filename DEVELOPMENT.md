# FinFlow: Development Guide

This is the guide a new contributor follows to set up the project, run every part of it, and write code that fits the existing conventions. For what the app is and how it is built, read the [README](README.md) first.

**Contents**

1. [Prerequisites](#1-prerequisites)
2. [First-time setup](#2-first-time-setup)
3. [Running the project](#3-running-the-project)
4. [Secrets and configuration rules](#4-secrets-and-configuration-rules)
5. [Project layout and where things go](#5-project-layout-and-where-things-go)
6. [Coding rules](#6-coding-rules)
7. [Changing the database](#7-changing-the-database)
8. [Working on the AI agent](#8-working-on-the-ai-agent)
9. [Testing](#9-testing)
10. [Building releases](#10-building-releases)
11. [Git and pull-request workflow](#11-git-and-pull-request-workflow)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Prerequisites

| Tool | Version | Notes |
| --- | --- | --- |
| Flutter SDK | stable, 3.50 or newer | The project was last built with Flutter 3.50.1 / Dart 3.14. `pubspec.yaml` allows Dart `>=3.2.0 <4.0.0`. |
| JDK | 17 | Point Flutter at it with `flutter config --jdk-dir=/path/to/jdk17`. |
| Android SDK | platform 35/36, build-tools 36, NDK 28.2, CMake 3.22 | Install via Android Studio's SDK Manager. Gradle will also fetch missing pieces on first build. |
| Android Studio | any recent | Optional as an editor; needed for the SDK Manager and emulator. |
| Chrome | any recent | For `flutter run -d chrome`. |
| Python | 3.11 or newer | Only for the `agent/` backend. |
| Git | any | |

Add Flutter and `adb` to your `PATH`, for example in `~/.bashrc`:

```bash
export PATH="$HOME/develop/flutter/bin:$PATH"
export PATH="$HOME/Android/Sdk/platform-tools:$PATH"
```

Verify with:

```bash
flutter doctor -v
```

You need green ticks for **Flutter**, **Android toolchain** and (for web) **Chrome**. Linux-desktop / Visual Studio warnings are irrelevant here: the project has no desktop runners.

## 2. First-time setup

```bash
git clone <your-fork-or-repo-url> finflow
cd finflow

# Flutter app
flutter pub get

# Python agent (only needed for the Coach tab)
cd agent
python3 -m venv .venv
.venv/bin/pip install -e ".[dev]"
cp .env.example .env          # then edit .env, see section 4
cd ..
```

### Running on a physical Android phone

1. On the phone: **Settings → About phone**, tap **Build number** seven times to enable Developer options.
2. **Developer options → USB debugging** on. Some phones also need **Install via USB** on.
3. Connect the cable and accept the "Allow USB debugging?" prompt.
4. Check it is detected: `adb devices` should list the device as `device` (not `unauthorized`).

## 3. Running the project

### The Flutter app

```bash
flutter devices                         # list targets

flutter run                             # debug build on the connected device/emulator
flutter run -d chrome                   # web
flutter run --release                   # release mode (no hot reload; closest to what users get)
```

Debug builds always show **Explore with a demo account** on the welcome screen (Demo User, PIN `1234`).

### The AI agent backend

```bash
cd agent
.venv/bin/uvicorn app.main:app --port 8000 --host 0.0.0.0 --reload
curl http://localhost:8000/health
```

Tell the app where it is with a compile-time define:

| Target | `AGENT_BASE_URL` |
| --- | --- |
| Web (same machine) | `http://localhost:8000` |
| Android emulator | `http://10.0.2.2:8000` (this is the default) |
| Physical phone on the same Wi-Fi | `http://<your-computer-LAN-IP>:8000` |
| Shared APK / production | an **HTTPS** URL of a hosted agent |

```bash
flutter run --dart-define=AGENT_BASE_URL=http://192.168.1.20:8000
```

> **Android blocks plain `http://` by default.** The project currently has no cleartext exception, so on Android the Coach tab only works against an `https://` URL. For local development over `http://`, add this to `android/app/src/debug/AndroidManifest.xml` (debug only; never in `main`):
>
> ```xml
> <application android:usesCleartextTraffic="true" />
> ```
>
> The web build is not affected by this.

### Hot reload tips

- `r` hot reloads, `R` hot restarts, `q` quits (in the `flutter run` terminal).
- Schema changes need a **full restart** (and often cleared app data, see [section 7](#7-changing-the-database)).

## 4. Secrets and configuration rules

**Never commit a secret.** This repository is public.

- Backend secrets go in `agent/.env` (git-ignored). The committed `agent/.env.example` lists every variable with an empty value; copy it and fill it in.
- Variables read by the backend (`agent/app/config.py`):

  | Variable | Required | Meaning |
  | --- | --- | --- |
  | `GROQ_API_KEY` | yes | Groq key used by the agent and the classifier |
  | `LLM_PROVIDER` | no | defaults to `groq` |
  | `AGENT_MODEL`, `CLASSIFIER_MODEL` | no | model names; sensible defaults in `config.py` |
  | `FIRECRAWL_API_KEY` / `FIRECRAWL_API_URL` | no | optional web search (cloud key or self-hosted URL) |
  | `RATE_LIMIT_*` | no | per-IP and global limits on the chat endpoints and (separately) the `/users` endpoints; defaults and proxy settings are in `agent/.env.example` and `agent/README.md` |
  | `MAX_REQUEST_BYTES` | no | request-body size cap (default 2,000,000); bigger requests get HTTP 413 |
  | `USERS_API_ENABLED` | no | serve the `/users` endpoints (default `true`; set `false` on public deployments) |
  | `FINFLOW_AGENT_DB` | no | path of the agent's SQLite file (synced data and memory) |

- Get a Groq key at <https://console.groq.com>. Firecrawl is optional; without it the agent simply doesn't search the web.
- The Flutter app has **no** secret configuration. Its only compile-time values are `AGENT_BASE_URL` and `DEMO_USER`, both public. Anything compiled into an app can be extracted, so **do not pass API keys through `--dart-define`**. Keys belong on the backend.
- If you add a new setting: add it to `Settings` in `agent/app/config.py`, add an empty entry to `agent/.env.example`, and document it here and in the README table.
- `.gitignore` already excludes `.env*` (except `.env.example`), `key.properties`, keystores (`*.jks`, `*.keystore`), `local.properties`, `google-services.json`, `agent/.venv/`, build output and `.claude/`. Before every commit run `git status` and skim the file list.
- If you ever commit a secret by accident: **revoke the key immediately**, then remove it from history. Deleting it in a later commit is not enough.

## 5. Project layout and where things go

See the annotated tree in the [README](README.md#project-structure). In short:

| You want to… | Put it in… |
| --- | --- |
| Add or change a screen | `lib/screens/<name>_screen.dart`, and register it in `main_screen.dart` if it is a tab |
| Add a bottom sheet or reusable widget | `lib/widgets/` |
| Add business logic with no UI (forecasts, market data, PDF) | `lib/services/` |
| Add or change SQL | `lib/database/finance_repository.dart` (queries) and `lib/database/schema/` (DDL) |
| Expose data/actions to screens | `lib/providers/finance_provider.dart` |
| Change colours, type or spacing | `lib/theme/app_theme.dart` |
| Add an AI capability | `agent/app/skills/content/<skill>/SKILL.md` (see [section 8](#8-working-on-the-ai-agent)) |

Data flows one way: **screen → provider → repository → SQLite**. Screens never run SQL, and the repository never touches widgets.

## 6. Coding rules

### Dart / Flutter

1. **Money is an integer in the database.** Store and compute in minor units (paise/cents); convert to a display value only at the edge. Never use `double` for stored amounts.
2. **Dates are local-time ISO-8601 strings** (`DateTime.toIso8601String()` of a local `DateTime`). Use `AppCalendar` (`lib/utils/app_calendar.dart`) for month arithmetic, because month-end handling is easy to get wrong.
3. **No SQL outside `FinanceRepository`.** Use parameterised statements (`?` placeholders). Never build SQL by string interpolation with user input.
4. **Let the database do aggregation.** Totals, balances, goal progress and net worth come from views and triggers (`v_*` views, `monthly_rollup`). Don't re-sum raw transactions in Dart.
5. **State goes through `FinanceProvider`.** Call `notifyListeners()` after state changes. Use `context.watch`/`Consumer` for values that must rebuild and `context.read` for one-off actions.
6. **Keep widgets small.** Extract a widget when a `build` method grows past a screenful or a block repeats. Prefer `const` constructors.
7. **Use the theme, not literals.** Colours and text styles come from `AppTheme` / the `context.fg`-style extensions, not hard-coded `Color(0xFF…)` in screens.
8. **Handle failure on every network call.** Use timeouts, catch errors, and show a friendly message. Never show raw backend errors in the UI.
9. **Async and `BuildContext`:** check `mounted` before using `context` after an `await`.
10. **Money-moving features need tests** (see the existing database and forecast tests).
11. **No `print`.** Use `debugPrint` for development output, and don't log personal data.
12. Run `flutter analyze` and fix what you introduce. The project uses `flutter_lints` (see `analysis_options.yaml`); the codebase currently has informational lints only, so don't add warnings or errors.
13. Match the surrounding style (the codebase uses wide lines and is not `dart format`-clean, so don't run `dart format` over files you didn't change; it would bury your diff in unrelated reformatting).

### Python (agent)

1. Type-annotate public functions; keep modules small and single-purpose (the existing layout is the model).
2. **The model suggests, Python enforces.** Limits, validation, leak checks and guardrails are code, never prompt-only. Don't weaken a check to make a test pass.
3. Read configuration only through `get_settings()`. No `os.environ` reads scattered through the code, and no hard-coded keys, URLs with credentials, or tokens.
4. Never log secrets, full prompts containing user data, or `Authorization` headers.
5. New behaviour comes with an **offline** test (mock the LLM). Live tests are marked `@pytest.mark.live`.

### General

- Comments explain **why**, not what. Keep the existing comment style (short, factual).
- Don't commit generated or build output (`build/`, `.dart_tool/`, `*.apk`).
- Keep changes focused: one concern per pull request.

## 7. Changing the database

The schema is versioned with SQLite's `PRAGMA user_version`. Migrations live in `lib/database/schema/schema.dart` as an ordered list of lists of SQL statements. `AppDatabase._migrate` runs every migration newer than the stored version inside a transaction (rolling back on failure).

**Rules**

- **Never edit a released migration.** Existing users have already applied it.
- To change the schema, **append a new list** to `migrations` (for example `v2Changes`), in a new file such as `v2_changes.dart`, and import it in `schema.dart`.
- Put DDL in the matching group: tables, indexes, views or triggers.
- Keep the conventions: integer minor units, ISO-8601 text dates, `CHECK` constraints for enums, `ON DELETE` rules on every foreign key.
- If a table's totals can be derived from another, maintain them with a **trigger** (as `monthly_rollup` is) rather than app code.
- Add or update tests in `test/database/`, including one that opens a fresh in-memory database (`AppDatabase.inMemory()`) and one that checks your trigger/view behaviour.
- Update the [schema section of the README](README.md#database-schema).

**Local data after a schema change:** during development you can clear app data (Android: Settings → Apps → FinFlow → Storage → Clear data; browser: clear site data / IndexedDB `finflow`) to re-run migrations from scratch.

## 8. Working on the AI agent

Architecture and endpoints are described in [`agent/README.md`](agent/README.md) and the README's [agent section](README.md#ai-coach-and-the-finance-agent).

### Adding a skill

1. Create `agent/app/skills/content/<skill_name>/SKILL.md`.
2. Start it with front matter, then the playbook:

   ```markdown
   ---
   name: <skill_name>
   description: One line the agent uses to decide when to load this skill.
   ---
   ## When to use
   Example user phrasings.

   ## Approach
   1. Numbered, concrete steps that anchor on the user's own data.
   ```

3. The registry loads every `*/SKILL.md` automatically, and names must be unique. Add a test in `agent/tests/test_skills_and_tools.py` if behaviour depends on it.

### Running the agent tests

```bash
cd agent
.venv/bin/python -m pytest                  # offline, fast
.venv/bin/python -m pytest -m live -s       # real model calls; needs GROQ_API_KEY and uses your quota
```

### Adding another LLM provider

Register it in `agent/app/agent/llm.py` and select it with `LLM_PROVIDER`. Nothing else should need to change.

## 9. Testing

```bash
flutter test            # Flutter unit/widget tests
flutter analyze         # static analysis
cd agent && .venv/bin/python -m pytest   # backend tests
```

Current Flutter tests cover the database layer (schema, triggers, views), the demo-data generator, the forecast service and the calendar helpers. When you fix a bug, add a test that fails without the fix.

## 10. Building releases

### Android APK

```bash
flutter build apk --release
# demo account visible + hosted agent:
flutter build apk --release \
  --dart-define=DEMO_USER=true \
  --dart-define=AGENT_BASE_URL=https://your-agent.example.com
```

Output: `build/app/outputs/flutter-apk/app-release.apk`. Install it on a connected phone with:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Release builds need the `INTERNET` permission (already declared in `android/app/src/main/AndroidManifest.xml`); without it, market data, fonts and the Coach cannot load.

### Web

```bash
flutter build web --release        # output in build/web/
```

The web build needs `web/sqlite3.wasm` (checked in) to be served alongside the app. Serve `build/web` from any static host.

### Deploying the agent to Render

The repo root has a [`render.yaml`](render.yaml) Blueprint that describes the agent service, so deploying is mostly clicking through Render's dashboard.

1. Push the repo to GitHub.
2. In the Render dashboard: **New → Blueprint**, connect the repo. Render reads `render.yaml` (service `finflow-agent`, free plan, `rootDir: agent`).
3. When prompted, enter **`GROQ_API_KEY`**. It is the only secret and lives only in Render's dashboard, never in git. Click **Apply**.
4. Wait for the first deploy (it runs `pip install .`, then `uvicorn app.main:app --host 0.0.0.0 --port $PORT`; Render checks `/health`). Then confirm it is live:

   ```bash
   curl https://<your-service>.onrender.com/health      # {"status":"ok"}
   ```

5. **Check how the rate limiter sees clients.** `render.yaml` sets `RATE_LIMIT_CLIENT_IP_HEADER=X-Forwarded-For` and `RATE_LIMIT_FORWARDED_HOPS=1`, with debug logging on. Send one chat request (for example from the app), then read the line `rate-limit client=… peer=… chain=…` in the service's **Logs**:
   - `client=` should be your real public IP, and it should be one of the addresses in `chain=`.
   - If `client=` shows an internal/proxy address instead, set `RATE_LIMIT_FORWARDED_HOPS` to `2` in the dashboard, redeploy, and check again. Until this is right, all users share one per-IP bucket (the global caps still protect your quota).
   - Then set `RATE_LIMIT_DEBUG_LOG_CLIENTS` to `false` (it logs IP addresses).
6. Build the app against it: `flutter build apk --release --dart-define=AGENT_BASE_URL=https://<your-service>.onrender.com`. Render serves HTTPS, which also avoids Android's plain-`http://` block.

**What the Blueprint does for you:** keeps the service configuration (commands, Python version, health check, rate-limit settings) in git where it is reviewed like code; lets you recreate the service from scratch in a few clicks; redeploys only when `agent/` changes (a `buildFilter`), so Flutter-only commits don't restart the backend; and keeps secrets out of the repo (`sync: false`). Render only prompts for secret values when a Blueprint is first created, so add any new secret (for example `FIRECRAWL_API_KEY`) in the dashboard.

#### Free-plan limits to design around

- **It sleeps after about 15 minutes without traffic** and takes about a minute to wake on the next request. The app handles this: it pings `/health` when it opens and on tab changes, and before a chat it waits (showing "Waking up your coach…") instead of failing. See `AgentWakeUp` in `lib/services/agent_chat_service.dart`.
- **The filesystem is not persistent.** Anything the agent writes to disk, including the server-side SQLite file (`FINFLOW_AGENT_DB`, set to `/tmp/finflow_agent.db` in `render.yaml`), is lost on every sleep, restart and redeploy. Use an external database, or treat that data as a cache the app can re-send.
- **512 MB RAM, 0.1 CPU, a single instance.** The agent uses about 94 MB after startup, so there is plenty of headroom. Keep one worker (the rate limiter is in-memory).
- **750 free instance hours per month** per workspace: enough for one always-on service, but not for two.

#### Before exposing it publicly

- The `/users/{user_id}/…` endpoints identify the user only by the id in the URL and have **no authentication** (the code says so in `app/api/users.py`). `render.yaml` therefore sets `USERS_API_ENABLED=false`, so they are **not served** on the public deployment (they return 404), and the app doesn't need them yet (it sends its data inline with each chat). Before turning them on, add real authentication; they are already rate limited (separately from chat) and covered by the request-size cap.
- The agent's memory and synced snapshots live in SQLite, which the free plan wipes on every sleep, restart and redeploy. Server-side memory is therefore not durable there; use an external database before relying on it.
- Each chat costs several model calls (answer, classifier, follow-up repair when needed, plus the memory step when a `user_id` is sent), so the global rate limits are also your model-quota budget.
- Requests over `MAX_REQUEST_BYTES` (2 MB) are refused with HTTP 413 before being read, so one oversized upload can't exhaust the 512 MB.
- Keep `GROQ_API_KEY` and any other secret only in Render's dashboard.

### Release signing

Release builds are currently signed with the **debug key**. That is fine for sharing with friends, but not for the Play Store or for users who must receive upgrades. Before publishing:

1. Create a keystore **outside the repo** and back it up:

   ```bash
   keytool -genkey -v -keystore ~/finflow-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias finflow
   ```

2. Create `android/key.properties` (git-ignored; never commit it):

   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=finflow
   storeFile=/absolute/path/to/finflow-release.jks
   ```

3. Wire it into `android/app/build.gradle.kts` (standard Gradle pattern; adapt and test it):

   ```kotlin
   import java.util.Properties

   val keystoreProperties = Properties().apply {
       val f = rootProject.file("key.properties")
       if (f.exists()) load(f.inputStream())
   }

   android {
       signingConfigs {
           create("release") {
               keyAlias = keystoreProperties["keyAlias"] as String
               keyPassword = keystoreProperties["keyPassword"] as String
               storeFile = file(keystoreProperties["storeFile"] as String)
               storePassword = keystoreProperties["storePassword"] as String
           }
       }
       buildTypes {
           release { signingConfig = signingConfigs.getByName("release") }
       }
   }
   ```

4. Change `applicationId` (currently `com.example.personal_finance_app`) to your own reverse-domain ID **before** the first public release; the Play Store rejects `com.example.*`, and it can't be changed after publishing.

### Android build toolchain notes

The Android build is pinned to what current Flutter requires:

| Component | Version | Where |
| --- | --- | --- |
| Gradle | 9.3.1 | `android/gradle/wrapper/gradle-wrapper.properties` |
| Android Gradle Plugin | 9.1.1 | `android/settings.gradle.kts` |
| Kotlin | built into AGP 9 | no separate Kotlin plugin is applied |
| Java target | 17 | `android/app/build.gradle.kts` |

`flutter build` prints warnings when Flutter wants newer versions; bump them in those files when it starts to fail. Low on RAM? `android/gradle.properties` caps Gradle at a 2 GB heap, two workers and no daemon. Raise `-Xmx` if the build runs out of memory, or lower it on small machines.

## 11. Git and pull-request workflow

- Branch from `main`: `feature/<short-name>`, `fix/<short-name>`, `docs/<short-name>`.
- Write commit messages in the imperative, with a short subject (≤ 72 chars): `Add budget over-limit warning`, `Fix bill anchor day in February`. Explain the *why* in the body when it isn't obvious.
- Keep pull requests small and focused, and include screenshots for UI changes.
- **Before opening a PR**, check all of these:
  - [ ] `flutter analyze` shows nothing new (no errors or warnings)
  - [ ] `flutter test` passes (and `pytest` if you touched `agent/`)
  - [ ] New behaviour has tests; bug fixes have a regression test
  - [ ] No secrets, keys, `.env`, keystores or personal data in the diff (`git diff --staged`, then `git status`)
  - [ ] Schema changes are a **new** migration, with tests and updated README docs
  - [ ] README/DEVELOPMENT updated if setup, configuration or behaviour changed

## 12. Troubleshooting

| Symptom | Likely cause and fix |
| --- | --- |
| `flutter: command not found` | Flutter isn't on `PATH`; add `<flutter>/bin` to it and open a new terminal. |
| `adb devices` shows `unauthorized` | Unlock the phone and accept the USB-debugging prompt; or revoke USB debugging authorisations in Developer options and reconnect. |
| Phone isn't listed at all | Try another cable/port (some cables are charge-only), set USB mode to File Transfer, and confirm USB debugging is on. |
| Install stalls at "Installing…" | Many phones (Oppo/Xiaomi families) show an extra **Install via USB** prompt on the screen. Approve it, or enable "Install via USB" in Developer options. |
| *"Your project's Gradle version is lower than Flutter's minimum"* / AGP errors | Bump the versions in [the toolchain table](#android-build-toolchain-notes). |
| Gradle runs out of memory / machine freezes | Lower `org.gradle.jvmargs -Xmx` in `android/gradle.properties`, close other apps, and keep `org.gradle.workers.max=2`. |
| *"sdkmanager … finished with non-zero exit value"* | A half-installed SDK package. Delete the partial folder under `~/Android/Sdk/ndk/<version>` (and `~/Android/Sdk/.temp`), make sure `JAVA_HOME` is set, then run `sdkmanager "ndk;28.2.13676358"` manually. |
| Fonts, market data or the Coach don't load in a release build | Missing `INTERNET` permission in `android/app/src/main/AndroidManifest.xml`. |
| Coach says it can't reach the service | The agent isn't running, `AGENT_BASE_URL` is wrong for your device (see [section 3](#3-running-the-project)), or Android is blocking plain `http://` (use HTTPS or the debug cleartext exception). |
| Coach shows "Waking up your coach…" for up to a minute | Expected on the free Render plan after 15 idle minutes. The app waits for the service to start, then sends the question. |
| Coach says "You're sending messages too quickly" / "busy right now" | The agent's rate limit (HTTP 429). Wait a moment, or tune `RATE_LIMIT_*` in the agent's environment. |
| Stock/commodity quotes empty on web | Expected. The quote provider blocks browser (CORS) requests; they work in the Android app. Crypto, forex and news work on web. |
| Web app shows a blank page | Serve from a real web server (not `file://`) and make sure `sqlite3.wasm` is next to `index.html`. |
