# Running the Deeds Office Register on Windows

This prototype is a SWI-Prolog web app. You do **not** need Linux. After
SWI-Prolog is installed, you unzip the project and double-click `start.bat`.

## 1. Install SWI-Prolog (Windows 64-bit)

1. Open the official downloads page:
   [https://www.swi-prolog.org/download/stable](https://www.swi-prolog.org/download/stable)
2. Download **SWI-Prolog for Microsoft Windows (64 bit)** — a self-installing
   `.exe` (as of November 2026 the stable file is named like
   `swipl-10.0.2-1.x64.exe`; a newer patch release is fine).
3. Run the installer.
4. **Tick “Add SWI-Prolog to the system PATH”** (or the wording your installer
   uses for adding `swipl` to PATH).
5. Finish the install. Accept the default location if you can. The usual
   executable is:

   `C:\Program Files\swipl\bin\swipl.exe`

6. If you already had a Command Prompt or PowerShell window open, close it and
   open a new one so it picks up the new PATH.

The `start.bat` script also looks in `C:\Program Files\swipl\bin\` if `swipl`
is not on PATH, so a default install still works.

## 2. Unzip the project

1. Unzip `deeds-prolog.zip` to a folder you can write to, for example:

   `C:\Users\YourName\Documents\deeds-prolog`

2. Keep the folder structure intact (`start.bat`, `scripts\`, `src\`, `web\`,
   `data\`, and so on should all sit together).

Avoid unzipping into a path that needs Administrator rights if you can.

## 3. Start the register

1. In File Explorer, open the unzipped `deeds-prolog` folder.
2. Double-click **`start.bat`**.
3. A console window opens and prints:

   `Deeds office register listening at http://localhost:8080/`

4. Your default browser should open that address. If it does not, open
   [http://localhost:8080/](http://localhost:8080/) yourself.
5. Leave the console window open while you use the app. Closing it stops the
   server.

The first start creates (or reuses) `data\deeds.db` and loads the fictional
sample register: 15 properties, 13 parties, transfers, bonds, servitudes, and a
few deliberate irregularities for the advisor.

## 4. What to try

- **Dashboard** — counts and recent registrations.
- **Properties** — open Erf 123 Claremont (bond still open), Erf 789 Parktown
  (clean chain), Erf 12 Observatory (price jump), Erf 99 Anomaly Township
  (broken title chain), Erf 1 Phantom Township (no title).
- **Advisor** — rule-based findings across the register.
- **Register** — try a transfer of Claremont while the bond is open; you should
  see a clear rejection from the Prolog rules.
- **Settings** — optional model advice (see below) and **Reset demo data**.

## 5. Optional: model advice

The advisor always shows rule-based findings. To add commentary from a larger
model, configure an **OpenAI-compatible** Chat Completions endpoint:

- In the app: **Settings** — paste the endpoint URL, model name, and API key.
  The key is stored only in `data\ai_settings.json` on this PC and is never
  sent back by the Settings API.
- Or set environment variables before starting (no key in any source file):

  ```
  set DEEDS_AI_API_KEY=your-key
  set DEEDS_AI_ENDPOINT=https://api.openai.com/v1/chat/completions
  set DEEDS_AI_MODEL=gpt-4o
  start.bat
  ```

You can also uncomment `ai_endpoint/1` and `ai_model/1` in `config.pl` for the
URL and model name. Do not put API keys in `config.pl` if you share the folder.

If nothing is configured, the advisor panel says that model advice is off and
still shows the Prolog findings.

## 6. Troubleshooting

| Problem | What to do |
|---------|------------|
| `SWI-Prolog was not found` | Install the 64-bit Windows build and tick PATH, then open a **new** window and run `start.bat` again. |
| Browser shows “can't reach this page” | Wait a second for the console to print the listening line. Confirm you are opening `http://localhost:8080/`. |
| “Port 8080 already in use” / failed start | Another program is using 8080. Close it, or run `start.bat --port 8081` from Command Prompt and browse to that port. |
| Windows Firewall prompt | This server listens on your machine only for a local browser. Allow access on a private network if asked. |
| Antivirus flags the SWI-Prolog installer | This is a known false-positive issue on the SWI-Prolog download page. Prefer the official `swi-prolog.org` build and its published SHA-256. |
| Double-click does nothing visible | Right-click `start.bat` → **Edit** is unnecessary; instead open Command Prompt in the folder and run `start.bat` so you can read any error. |
| Paths with spaces | `start.bat` quotes the SWI-Prolog path. Keep the project path reasonably simple if you run into quoting issues. |
| Reset from a messy database | Settings → **Reset demo data** wipes `data\deeds.db` and reloads the fictional sample. |

To start from Command Prompt instead of double-clicking:

```
cd C:\Users\YourName\Documents\deeds-prolog
start.bat
```

Optional flags (they are passed through to Prolog):

```
start.bat --port 8081
start.bat --no-browser
```

## 7. Command-line tools (optional)

With `swipl` on PATH, from the project folder:

```
swipl -s repl.pl
swipl -q -s tests\test_rules.pl -g "run_tests,halt"
```

The web app is the supported way to use the register on a PC. The `.sh` start
script is only for Linux or macOS and is not needed on Windows.
