# Deeds Office Register — Prolog prototype

A working prototype of a **South African deeds office register** in SWI-Prolog,
with a browser front end, a rule-based advisor, and an optional hook for a
larger model’s advice.

It stores properties (erven, farms, sectional title units), parties (natural
persons, companies and trusts), title deeds, transfers, mortgage bonds,
cancellations, and servitudes. Business rules decide who the current owner is,
whether a property is bonded, and whether a transfer may be registered. An
advisor flags problems such as outstanding bonds, broken title chains, missing
identifiers, stale bonds and unusual price jumps.

**All parties, properties, banks, identifiers and deed numbers in the sample
data are fictional** and exist only to prove the idea.

## Run it on a Windows PC

This is the supported way to try the prototype on your own computer:

1. Install **SWI-Prolog Windows 64-bit** from
   [https://www.swi-prolog.org/download/stable](https://www.swi-prolog.org/download/stable)
   and tick **Add SWI-Prolog to the system PATH**.
2. Unzip `deeds-prolog.zip`.
3. Double-click **`start.bat`**. Your browser should open
   [http://localhost:8080/](http://localhost:8080/).

Full steps, firewall notes and troubleshooting are in
[`WINDOWS_SETUP.md`](WINDOWS_SETUP.md).

## Requirements

- [SWI-Prolog](https://www.swi-prolog.org/) 8+ (`swipl`). Developed with
  9.2.9; the current Windows 64-bit installer (10.x) is also fine.
- On Debian/Ubuntu: `sudo apt-get install -y swi-prolog-nox`
- No other runtime is required for the web UI (no Node, no CDN).

## Quick start

From the project folder (`deeds-prolog/`):

```bash
# Web app (Linux / macOS) — then open http://localhost:8080/
./start.sh

# Web app (Windows)
start.bat

# Start without opening a browser, or on another port
./start.sh --no-browser
./start.sh --port 8081

# Prolog REPL with the register attached
swipl -s repl.pl
?- current_owner(prop_claremont_123, Owner).

# Test suites (rules, advisor, HTTP)
swipl -s scripts/run_tests.pl

# Original non-interactive CLI demo
./scripts/demo.pl
```

The captured CLI demo lives in [`demo_output.txt`](demo_output.txt). The
command-line menu is still available as `./scripts/deeds.pl`.

## Web application

One command starts an HTTP server on **http://localhost:8080/**.

| Page | What it shows |
|------|----------------|
| Dashboard | Counts, recent registrations, urgent advisor flags |
| Properties | Searchable list; detail with current owner, title chain, bonds, servitudes and a per-property advisor |
| Parties | List and current holdings |
| Deed lookup | Search by official number (`T9100/2024`, `B2100/2021`, `K400/2018S`) |
| Register | Forms for party, property, first title, transfer, bond, cancellation, servitude — server-side Prolog validation, errors shown in full |
| Advisor | Registry-wide rule findings, plus optional model commentary |
| Settings | Advice-hook configuration and **Reset demo data** |

Styles and scripts are served from `web/static/` (offline, no CDN).

### Optional model advice

The advisor always runs the Prolog rules. To add commentary from an
OpenAI-compatible **chat completions** model:

- **Settings** in the web app: endpoint URL, model name, API key. The key is
  stored only in `data/ai_settings.json` on this machine and is never returned
  by `GET /api/settings`.
- Or environment variables (highest precedence):

  ```
  DEEDS_AI_API_KEY      your key
  DEEDS_AI_ENDPOINT     https://api.openai.com/v1/chat/completions
  DEEDS_AI_MODEL        gpt-4o
  ```

- Or uncomment `ai_endpoint/1` and `ai_model/1` in `config.pl` for the URL and
  model name only. **Never put an API key in source files.**

If nothing is configured, the panel says that model advice is off and still
shows the rule-based findings.

## Layout



| Path | Role |
|------|------|
| `start.bat` / `start.sh` | Start the web server (Windows / Unix) |
| `WINDOWS_SETUP.md` | Exact install steps for a Windows PC |
| `web/index.html`, `web/static/` | Browser UI (no CDN) |
| `src/deeds_http.pl` | HTTP server and JSON API |
| `src/deeds_advisor.pl` | Rule-based advisor and optional AI hook |
| `src/deeds_config.pl` | Endpoint / model / key resolution (env, settings file, `config.pl`) |
| `src/deeds_schema.pl` | Data model and `library(persistency)` journal |
| `src/deeds_rules.pl` | Registration API, validation, and queries |
| `src/deeds_sample.pl` | Fictional seed data and `reset_demo/0` |
| `src/deeds_report.pl` | Pretty-printers used by the CLI and demo |
| `src/deeds_cli.pl` | Interactive menu |
| `load.pl` | Path setup, `setup_deeds/0` |
| `repl.pl` | REPL entry — attaches the register and imports queries |
| `scripts/server.pl` | Web entry point |
| `scripts/deeds.pl` | CLI entry point |
| `scripts/demo.pl` | Non-interactive walkthrough |
| `tests/test_rules.pl` | Registration and query tests |
| `tests/test_advisor.pl` | Advisor and reset tests |
| `tests/test_http.pl` | HTTP smoke tests (`http_open`) |
| `data/deeds.db` | Persistent journal (survives restarts) |
| `config.pl` | Optional local endpoint/model defaults (no keys) |

## Data model

Persistent facts:

```
party(Id, Kind, Name, Identifier)
    Kind = natural | company | trust

property(Id, Kind, Description, Details)
    Kind = erf | farm | sectional
    Details = erf(No, Township, Municipality, Province, ExtentM2)
             | farm(Name, No, Portion, Division, Province, Extent)
             | sectional(Section, SchemeName, SchemeNo, Municipality, Province, ExtentM2)

title_deed(DeedNo, PropertyId, OwnerId, Date, PreviousDeed, Consideration)
    PreviousDeed = none  for the opening title
    Consideration = grant | rands(Integer)

bond(BondNo, PropertyId, DeedNo, Mortgagee, MortgagorId, Amount, Date)
    DeedNo is the title current when the bond was registered
    Amount is a whole number of rands

bond_cancellation(BondNo, Date, Note)

servitude(DeedNo, PropertyId, Type, InFavourOf, Date, Description)
```

Official numbers follow realistic (simplified) South African formats:

- Title deeds: `T12345/2024` (conventional) or `ST1234/2020` (sectional title)
- Mortgage bonds: `B6789/2024`
- Notarial deeds of servitude: `K1234/2023S`
- Dates: ISO `YYYY-MM-DD`

The **current title** is the deed that is not the `PreviousDeed` of any later
deed on the same property, so the title chain is walked by pointer, not merely
sorted by date.

## Validation rules

- Deed and bond numbers must match the formats above and must be **unique**
  across the register.
- A first title can be registered only once per property. Later ownership
  changes use `register_transfer/7`.
- A transfer is allowed **only from the current registered owner**.
- **Outstanding mortgage bonds block a transfer.** In South African practice a
  bond must be cancelled or substituted before a new title is registered. This
  prototype enforces the cancellation path and returns a clear rejection (it
  does not silently allow a transfer and merely “flag” the bond).
- A bond is passed by the current owner over the current title. A bond cannot
  be cancelled twice, or before its registration date.
- Transfer and cancellation dates may not pre-date the current title / bond.

## Queries

```prolog
current_owner(Property, Owner).
title_chain(Property, Chain).          % chronological list of title/6 terms
is_bonded(Property, Bonds).            % [] if unencumbered
properties_owned_by(Person, List).
deed_search(DeedNo, Record).           % title, bond (with status), or servitude
encumbrance_summary(Property, Summary).
```

Registration predicates bind `Result` to `ok` or `error(Reason)`. Use
`error_message/2` for a readable explanation.

## Sample register (fictional)

Thirteen parties (including a company, two trusts, and one person seeded
without an identifier) and fifteen properties. `load_sample/0` (and
**Reset demo data** in Settings) loads all of the following.

A short selection:

| Property | Opening title | Later deeds | Notes / encumbrances |
|----------|---------------|-------------|----------------------|
| Erf 123 Claremont | T1001/2018 to Thabo | T4521/2021 to Lerato (R2,150,000) | Active bond B2100/2021 (blocks transfer) |
| Erf 456 Stellenbosch | T2100/2019 to Pieter | T7800/2023 to the company (R5,400,000) | Active bond B3300/2023 |
| Farm Weltevreden No. 78 | T0800/2015 to the trust | — | Bond B1500/2016 cancelled 2020-08-12; servitude K400/2018S |
| Section 12 SS Harbour View | ST1200/2020 to Ayesha | — | Active bond B2500/2020 |
| Erf 789 Parktown | T3000/2017 to Thabo | T6100/2020 to Pieter; bond cancelled; T9100/2024 to Ayesha | Clean, unencumbered |
| Erf 55 Rondebosch | T4001/2019 to Siya | T4002/2023 to Nomsa (R2,800,000) | Clean |
| Erf 12 Observatory | T5100/2022 to Isabel (R800,000) | T5101/2023 to Jordan (R4,500,000) | Unusual price jump (advisor) |
| Erf 2001 Sandton | T2200/2011 to Pieter | — | Stale bond B800/2012 still open (advisor) |
| Erf 88 Durban North | T6300/2024 to Isabel | — | Clean |
| Farm Langeberg No. 12, Knysna | T1100/2016 to Karoo Estates | — | Active bond B900/2017; pipeline servitude K210/2019S |
| Section 3 SS Paarl Vineyards | ST1400/2021 to Jordan | — | Clean |
| Erf 410 Waterkloof | T3500/2018 to the Naidoo Family Trust | — | Clean |
| Section 7 SS Atlantic Heights | ST701/2022 to Johan Botha | — | Owner has no identifier (advisor) |
| Erf 1 Phantom Township | — | — | No title at all (advisor) |
| Erf 99 Anomaly Township | T7001/2016 (raw seed) | T7002/2019 points at missing T6999/2016 | Broken chain (advisor) |

Internal ids follow the same pattern (`thabo`, `prop_claremont_123`,
`prop_orphan_erf_1`, `prop_broken_chain`, …).

## Example queries (actual output)

After `setup_deeds.` in the REPL, or as printed by `./scripts/demo.pl`:

```text
?- current_owner(prop_claremont_123, Owner).
Owner = lerato.

?- current_owner(prop_parktown_789, Owner).
Owner = ayesha.
```

Pretty-printed title chain for Erf 789 Parktown (two transfers):

```text
Title chain for Erf 789 Parktown, City of Johannesburg, Gauteng [erf, prop_parktown_789]
  1. T3000/2017  dated 2017-05-22
     owner: Thabo Mokoena ...
     previous deed: none
     consideration: grant (first registration)
  2. T6100/2020  dated 2020-11-03
     owner: Pieter van der Merwe ...
     previous deed: T3000/2017
     consideration: R3,000,000
  3. T9100/2024  dated 2024-02-15
     owner: Ayesha Khan ...
     previous deed: T6100/2020
     consideration: R3,750,000
```

Bonds and holdings:

```text
Active mortgage bonds over Erf 123 Claremont ...
  B2100/2021  dated 2021-06-18
     mortgagee: Atlantic Commercial Bank Limited
     amount: R1,500,000

Active mortgage bonds over Erf 789 Parktown ...
  none (property is not bonded)

Properties currently owned by Ayesha Khan ...
  Section 12 SS Harbour View ... (current title ST1200/2020)
  Erf 789 Parktown ... (current title T9100/2024)

Properties currently owned by Thabo Mokoena ...
  none
```

Deed search finds titles, cancelled and active bonds, and servitudes:

```text
Deed search: B1500/2016
  Mortgage bond B1500/2016
  ...
  amount:     R4,000,000
  status:     CANCELLED on 2020-08-12 (Cancellation of mortgage bond)

Deed search: K400/2018S
  Notarial deed of servitude K400/2018S
  type:         right of way
```

Validation (transfers are rejected, not partially applied):

```text
Attempting T99901/2024: Thabo Mokoena transfers Erf 123 Claremont
(current owner is Lerato Dlamini) ...
  Result: REJECTED
  Transfer is only allowed from the current registered owner. Thabo Mokoena
  ... is not the owner; the current registered owner is Lerato Dlamini ...

Attempting T99902/2024: Lerato Dlamini transfers Erf 123 Claremont
to Pieter van der Merwe, while bond B2100/2021 is still open ...
  Result: REJECTED
  Transfer blocked: outstanding mortgage bond(s) B2100/2021 must be cancelled
  or substituted before a transfer can be registered (South African deeds
  practice).
```

## Tests

```bash
swipl -s scripts/run_tests.pl
# or individually:
swipl -q -s tests/test_rules.pl -g 'run_tests,halt'
swipl -q -s tests/test_advisor.pl -g 'run_tests,halt'
swipl -q -s tests/test_http.pl -g 'run_tests,halt'
```

`test_rules.pl` covers deed-number and date formats, first-title and transfer
registration, the current-owner rule, the outstanding-bond block (and the
successful path after cancellation), uniqueness, bond cancellation, title
chains, queries, and **persistence across detach and re-attach**.

`test_advisor.pl` covers each seeded irregularity, registry-wide findings,
plain-English recommendations, the disabled AI hook, and **Reset demo data**.

`test_http.pl` starts the server on port 18080 and uses `http_open` to smoke-test
HTML, static files, JSON endpoints, validation error responses, and settings
(confirming that API keys are never returned).

Each test uses its own temporary journal so it does not touch `data/deeds.db`.

## Design notes

- Persistence uses SWI-Prolog `library(persistency)` with `sync(flush)`, so
  each successful registration is written to `data/deeds.db` immediately and
  survives a restart.
- The demo attaches a temporary copy of the sample register so re-running it
  does not mutate `data/deeds.db`.
- Bond *substitution* (a new bond in place of an existing one on transfer) is
  not modelled as a single act. Cancel the outstanding bond, then register the
  transfer, then register a new bond — that is the supported path.
- Mortgagees are stored as bank names, not as `party/4` records.
- Consideration `grant` means “opening entry in this prototype register”, not a
  historical Crown grant.
- This is a prototype, not a substitute for a real deeds office system
  (no endorsements, no diagrams, no conveyancer workflow, no multi-user
  locking beyond the persistency mutex).

## License

Prototype sample code for demonstration. Sample data is fictional.
