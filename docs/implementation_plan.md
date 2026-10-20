# Soreva — Phase-by-Phase Implementation Plan

**Status:** v1.0
**Date:** 20 October 2026
**Companion to:** `personal_finance_capture_prd.md` (v3.2), `credentials_and_keys.md`

Effort is given in **focused working days** for one developer, not calendar
time — scale to your actual availability. Estimates are deliberately rough for
Phases 2–4, which depend on what Phase 0 proves.

---

## Sequencing principle: spike before you scaffold

The PRD lists Phase 0 setup before route validation. **This plan deliberately
inverts that.**

Three unknowns gate the entire product (PRD §5.2): whether `Take Screenshot`
prompts on every Back Tap run, whether it captures the payment app or the
Shortcuts overlay, and whether `Get Current App` returns the payment app or
Shortcuts. If any of them fails, the product changes shape.

So **Stage 0A is a throwaway spike that answers them in 1–2 days**, before any
architecture exists. Building a clean four-layer skeleton and then discovering
the trigger does not work would waste a week of good work. Answer the
questions with ugly code, throw it away, then build properly.

---

## Phase 0 — Feasibility and foundation

**Goal:** prove a double Back Tap can capture the screen unattended, and decide
route priority on evidence.
**Effort:** 8–10 days
**Credentials:** A2, A3, A4, A6, R1 (see `credentials_and_keys.md` §10)
**Gate:** hard — no Phase 1 work until this passes.

### Stage 0A — Trigger spike (1–2 days, throwaway)

| # | Task |
|---|---|
| 1 | Register bundle ID (A3) and App Group (A4) |
| 2 | Bare Flutter app + one App Intent target, App Group entitlement on **both** |
| 3 | App Intent accepting `IntentFile` (`public.image`), writing the file to the App Group and logging |
| 4 | Shortcut: `Get Current App` → `Take Screenshot` → Soreva intent |
| 5 | Bind to double Back Tap; test on a real device over a GoPay/OVO/DANA receipt |

**Answer and record in the PRD:**
- Does `Take Screenshot` prompt for permission every run, or once?
- Does it capture the payment app or the Shortcuts overlay?
- Does `Get Current App` return the payment app or Shortcuts?
- Tap-to-inbox latency?
- Does any of it differ when the app has never been launched?

**Decision point:** Route B primary if clean; Route A primary if B prompts
every run or captures the wrong surface; pivot per PRD §14 if both fail.

### Stage 0B — Project foundation (3 days)

| # | Task |
|---|---|
| 6 | `git init`, `.gitignore` covering `config/*.json` and `.env` before any secret-adjacent commit |
| 7 | FVM: resolve and pin the Flutter version satisfying Dart `^3.9.2` + installed Xcode; commit `.fvmrc` |
| 8 | Delete `web/`, `macos/`, `linux/`, `windows/` |
| 9 | Set iOS deployment target to **18.2** (D-22) |
| 10 | Create the four-layer skeleton: `core/ domain/ data/ presentation/ app/` |
| 11 | Strict `analysis_options.yaml`; warnings fail the build |
| 12 | CI: Dart tests + the two §7.4 boundary greps, on Linux runners |
| 13 | `config/example.json` + `--dart-define-from-file` wiring |

### Stage 0C — Real capture path (3–4 days)

| # | Task |
|---|---|
| 14 | Rebuild the App Intent properly: Vision OCR → inbox JSON (PRD §7.6 schema) → discard image |
| 15 | Atomic write (temp + rename); verify no image persists |
| 16 | Route A: PhotoKit screenshot-subtype detection |
| 17 | Dart inbox drain with `capture_attempt_id` idempotency |
| 18 | Crash-mid-drain test proving no double-insert |

### Stage 0D — OCR corpus (1–2 days)

| # | Task |
|---|---|
| 19 | Collect 30–50 real receipt screenshots across the D-14 apps |
| 20 | Run Vision over all; record extraction rates for amount, merchant, date, provider branding |
| 21 | Commit as test fixtures — this becomes the Phase 1 parser's regression suite |

**Exit criteria:** one route works end-to-end unattended from a double Back
Tap; route priority recorded in the PRD; corpus shows acceptable amount and
date extraction; CI green with boundary checks active.

**Deliverable:** a working trigger, an empty but correct architecture, and a
measured sense of how good OCR actually is on your real receipts.

---

## Phase 1 — Local MVP

**Goal:** a complete, useful, offline finance app. No cloud at all.
**Effort:** 20–25 days
**Credentials:** C1 (Sentry DSN) only
**Depends on:** Phase 0 exit

### 1A — Domain layer first (4–5 days)

Build and test these as pure Dart against the Stage 0D corpus, before any UI:

| # | Task |
|---|---|
| 22 | `Money` value object — `amount_minor` + `currency_scale`, IDR scale 0, no floating point |
| 23 | `Transaction` entity with `direction`, attribution fields, `review_status` |
| 24 | Receipt parser — amount, currency, merchant, date/time, reference ID; Indonesian total labels |
| 25 | Provider inference — brand-keyword dictionary with confidence |
| 26 | Category rules + `Uncategorized` fallback |
| 27 | Deduplication — all four levels (PRD FR-06) |
| 28 | Repository interfaces |

**Gate:** 1A ships with unit tests only. If the parser cannot hit a reasonable
extraction rate on the corpus, fix it here — it is 10x cheaper than after the
UI exists.

### 1B — Data layer (3–4 days)

| # | Task |
|---|---|
| 29 | Drift schema mirroring PRD §9, with indexes |
| 30 | Migration harness + a test proving data survives a migration |
| 31 | Repository implementations + DTO mappers |
| 32 | Platform channel for the inbox; capture pipeline wired end to end |

### 1C — Presentation (8–10 days)

| # | Task |
|---|---|
| 33 | GetX bindings, routes, `NavigationService`, theme |
| 34 | Dashboard — today/month, income/net, category breakdown |
| 35 | Transaction history with search and filters |
| 36 | Transaction detail/edit, showing attribution source and confidence |
| 37 | **Fast manual entry** — first-class, keypad-first; the only path for cash |
| 38 | Review queue for drafts and possible duplicates |
| 39 | Capture diagnostics screen |
| 40 | Settings — route selection, currency, categories, export |

### 1D — Onboarding and polish (4–5 days)

| # | Task |
|---|---|
| 41 | Onboarding: honest capability disclosure, on-device-OCR privacy statement |
| 42 | One-tap Shortcut install link + Back Tap setup walkthrough |
| 43 | Live capture test with visible parsed result |
| 44 | Data export (JSON/CSV) |
| 45 | Sentry integration |
| 46 | Accessibility pass — text sizes, screen-reader labels |

**Exit criteria:** you can use the app as your real expense tracker for a week
without touching cloud code. Capture works, cash entry is fast, nothing is
lost.

---

## Phase 2 — Cloud account and sync

**Goal:** accounts, per-user isolation, and durable backup.
**Effort:** 12–15 days
**Credentials:** the full Phase 2 block — A5, G1–G4, S1–S9, R2

### 2A — Backend setup (2–3 days)

| # | Task |
|---|---|
| 47 | Supabase project; record S2/S3; store S4/S5/S6 outside the repo |
| 48 | SQL migrations for `profiles`, `categories`, `transactions` |
| 49 | **RLS on every table**, `auth.uid()` = owner |
| 50 | Indexes and unique constraints, incl. `capture_attempt_id` |
| 51 | Multi-user RLS test as a CI gate — two users, cross-access must fail |

### 2B — Authentication (3–4 days)

| # | Task |
|---|---|
| 52 | Privacy policy on GitHub Pages (R2) — blocks the Google consent screen |
| 53 | Google: iOS **and** Web OAuth clients; consent screen |
| 54 | Supabase Google provider: web client ID + **Skip nonce check on** |
| 55 | Apple: enable capability; bundle ID into Supabase Client IDs |
| 56 | `signInWithIdToken` for both providers |
| 57 | Persist Apple's first-authorization name; never null it on re-sign-in |
| 58 | Private-relay email tolerated; identity keyed on user UUID |
| 59 | Session restore, sign-out, revoked-credential handling |
| 60 | Keychain storage for tokens |

### 2C — Sync (4–5 days)

| # | Task |
|---|---|
| 61 | Outbox writes in the same local transaction as the entity |
| 62 | Idempotent upserts on stable UUIDs |
| 63 | Bounded exponential backoff |
| 64 | Sync status UI + manual "Sync now" |
| 65 | Expired-session handling with zero local data loss |
| 66 | Conflict policy per PRD §7.8 |

### 2D — Deletion, export, Siri (3 days)

| # | Task |
|---|---|
| 67 | **`delete-account` Edge Function** with `service_role` as a secret; user ID from the JWT, never from params |
| 68 | In-app deletion flow: cloud rows, auth user, local data |
| 69 | Siri voice entry via parameterised App Intent — the only capture path for cash |

**Exit criteria:** two real accounts cannot see each other's data; offline
transactions sync on reconnect without duplicates; account deletion fully
works.

---

## Phase 3 — Release hardening

**Goal:** App Store submission.
**Effort:** 10–12 days
**Credentials:** A7, A8, A9 (optional), C2, R3

| # | Task |
|---|---|
| 70 | Device matrix testing; all three app lifecycle states |
| 71 | Parser regression suite expanded with real-world receipts |
| 72 | Performance: App Intent within budget, no UI-thread blocking, SQL-side aggregation |
| 73 | **Verify no network request carries image data** (PRD §12) |
| 74 | Indonesian + English localization |
| 75 | App Store privacy questionnaire — on-device OCR, no image upload |
| 76 | **Guideline 5.1.1(i) framing** — onboarding and listing both present the account as enabling backup and recovery |
| 77 | Store assets, screenshots, support page (R3) |
| 78 | Distribution signing; optional macOS CI for TestFlight |
| 79 | TestFlight beta; iterate |
| 80 | Submit |

**Known review risks:** the mandatory sign-in wall (5.1.1(i)), screen-content
reading needing a clear privacy explanation, and account deletion being
genuinely reachable.

---

## Phase 4 — Android

**Goal:** second platform without rebuilding the domain.
**Effort:** 15–20 days
**Credentials:** A10, P1, P2

| # | Task |
|---|---|
| 81 | Re-add the Android target; verify `domain/` and `data/` need no changes |
| 82 | Swap Vision for ML Kit on-device text recognition (also free) |
| 83 | Android trigger: Quick Settings Tile, widget, or accessibility gesture |
| 84 | Apple Services ID + `.p8` (A10) — now required, since Android uses the OAuth web flow |
| 85 | Android OAuth client (P2) |
| 86 | Play Console (P1), Android privacy declarations |

**Validation of the architecture:** if Phase 4 requires edits inside
`lib/domain/`, the boundary discipline failed somewhere in Phases 1–2.

---

## Rough totals

| Phase | Days | Cumulative |
|---|---|---|
| 0 — Feasibility | 8–10 | 10 |
| 1 — Local MVP | 20–25 | 35 |
| 2 — Cloud + sync | 12–15 | 50 |
| 3 — Release | 10–12 | 62 |
| **iOS launch** | | **~55–62 days focused** |
| 4 — Android | 15–20 | 80 |

At three focused days a week, iOS launch is roughly five months. Phase 0 is
10% of the effort and decides whether the other 90% is worth spending — treat
its gate as real.

---

## Critical path and dependencies

```
0A spike ──► route decision ──► 0C capture path ──► 1A domain ──► 1B data ──► 1C UI
                                                       │
0B foundation ──────────────────────────────────────────┤
0D corpus ─────────────────────────────────────────────►┘

R2 privacy policy ──► G4 consent screen ──► 2B auth ──► 2C sync
S4 service_role ────► 2D edge function ──► account deletion ──► 3 submission
```

**Things that block more than they look like they do:**
- The privacy policy URL (R2) gates the Google consent screen, which gates all
  of 2B.
- The App Group entitlement must be on **both** targets or the inbox is
  silently empty.
- Account deletion needs an Edge Function (`credentials_and_keys.md` §6) — it
  is not a client-only feature and it blocks submission.
- The Supabase "Skip nonce check" toggle blocks native Google sign-in entirely.
