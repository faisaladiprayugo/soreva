# Product Requirements Document (PRD)

## Soreva — Personal Finance Capture (iOS First, Flutter + Supabase)

**Document status:** Final v3.2
**Date:** 20 October 2026
**Supersedes:** v3.0, v2.0 (`docs/personal_finance_capture_prd.v2.md`), v1.0 (`docs/personal_finance_capture_prd.v1.md`)
**v3.1 change:** corrects D-18 — authoritative app attribution via Shortcuts `Get Current App` (iOS 18.2+) replaces the earlier claim that no iOS API reports the foreground app.
**v3.2 change:** minimum iOS version set to **18.2** (D-22), removing all version-conditional attribution logic.
**Platforms:** iOS first; Android planned for a later phase
**Product approach:** Local-first, cloud-connected, single end-user application
**Distribution:** Free app, no monetization, no subscriptions, no ads

---

## 0. Decisions Locked

v1.0 left seven decisions open and omitted three stated requirements. v3.0
additionally resolves the capture mechanism, which v1.0 and v2.0 had both
framed incorrectly. Items marked *(proposed)* still need confirmation but
carry a default so implementation is never blocked.

| # | Decision | Resolution |
|---|---|---|
| D-01 | Product core | Double-Back-Tap screen capture **is** the product differentiator. |
| D-02 | Data model | Income **and** expense in one `transactions` table with a `direction` column. Single account for MVP; no wallets, no transfers. |
| D-03 | Auth gate | Sign-in **required** before recording. No guest mode, no local-to-cloud migration logic. |
| D-04 | Auth providers | **Google and Apple only.** No email/password, magic links, or anonymous auth. |
| D-05 | Platforms | iOS first. Android is Phase 4. Non-mobile targets removed from the repo. |
| D-06 | State management | **GetX**, confined to the presentation layer (§7.3). |
| D-07 | Architecture | Clean architecture, four layers, boundary enforced in CI (§7.2, §7.4). |
| D-08 | Native capture storage | Swift writes to an **App Group inbox**; it does not share the SQLite database (§7.6). |
| D-09 | Local database | **Drift** over SQLite. Viable because D-08 makes Dart the exclusive database owner. |
| D-10 | Uncertain captures | Saved as **drafts** with `review_status = 'needs_review'`. Never rejected, never silently accepted. |
| D-11 | Cloud payload | Structured transaction fields only. No receipt or screenshot images uploaded, ever, in MVP. |
| D-12 | Money storage | `amount_minor` BIGINT plus an explicit per-currency scale. **IDR scale is 0.** See §9.5. |
| D-13 | Default currency / locale | IDR; UI in Indonesian and English *(proposed)*. |
| D-14 | Phase 0 test apps | GoPay, OVO, DANA, ShopeePay, QRIS receipt screens, and one bank app (BCA or Livin) *(proposed)*. |
| D-15 | Flutter version | Pinned at bootstrap to a stable release satisfying Dart `^3.9.2` and the installed Xcode. Recorded in `.fvmrc`, not guessed here. See §6.1. |
| **D-16** | **Capture mechanism** | **Screenshot the screen, then OCR the pixels with Apple Vision.** The app does *not* depend on third-party apps exposing their receipt text. This corrects the central premise of v1.0 and v2.0 (§5.1). |
| **D-17** | **Capture routes** | **Both** routes are built. **Route B** (Shortcut → Take Screenshot → App Intent, image in-process) is primary; **Route A** (Back Tap native Screenshot → PhotoKit detection) is the fallback. They share the entire post-image pipeline (§7.5). |
| **D-18** | **Attribution — two distinct fields** | `source_app` comes from the Shortcuts **Get Current App** action and is **authoritative** on every supported device (guaranteed by D-22), on Route B. `payment_provider` is **inferred** from OCR branding and is best-effort, confidence-scored, user-correctable. Route A has no app attribution at all and falls back to OCR inference (§5.3). |
| **D-19** | **Screenshot retention** | Route B discards the image immediately after OCR and never persists it. Route A never copies the image out of Photos. No screenshot is ever uploaded. |
| **D-20** | **Additional triggers** | Share Sheet extension in MVP. Siri voice entry in Phase 2. Action Button supported free via the Route B Shortcut. |
| **D-21** | **Apple Developer Program** | **Already enrolled.** Not a blocker; Phase 0 can begin immediately. |
| **D-22** | **Minimum iOS version** | **iOS 18.2.** Guarantees `Get Current App`, `Take Screenshot`, and modern App Intents on every supported device, eliminating all version-conditional attribution code. Accepted cost: excludes iPhone 8 and X, which support Back Tap but not iOS 18 (§5.2). |

---

## 1. Product Overview

### 1.1 Vision

Build a personal finance app that minimizes the effort required to record
spending. The primary experience: the user completes a payment in any app,
reaches the receipt or success screen, and **double-taps the back of the
iPhone**. The screen is captured, Apple Vision reads it on-device, and the app
extracts the amount, merchant, source app, category, and date/time, prevents
duplicates, saves locally, and syncs to the user's cloud account.

Because the mechanism is a screenshot rather than a cooperative data handoff,
it works against any app that draws a readable receipt — no integration,
partnership, or API access is required from the payment provider.

Income, cash spending, and corrections are recorded by hand. Capture is an
expense accelerator; the ledger is the system of record.

### 1.2 Problem

Manually recording every expense is inconvenient, so users forget or delay.
Existing expense trackers require opening an app and typing the amount,
merchant, category, date, and time.

### 1.3 Product principles

- **Capture with minimal friction:** double Back Tap, no app switch, no typing.
- **Local-first reliability:** saving a valid transaction never depends on a
  network connection.
- **One user-facing app:** native iOS components ship inside the same app; no
  companion app to install.
- **Privacy by design:** all OCR happens on-device. Screenshots are never
  uploaded and never retained beyond the capture pipeline.
- **Honest automation:** never invent missing values, and never present an
  uncertain reading as confirmed.
- **Cross-platform core:** financial rules and domain logic stay reusable for
  Android.
- **Free forever:** no subscriptions, ads, or paid tiers. Operating cost must
  stay within free service tiers (§5.5).

---

## 2. Goals and Success Criteria

### 2.1 Goals

1. Capture the current screen from a double Back Tap and extract a transaction
   from it with no further user interaction.
2. Extract total, currency, merchant, source app, category, and date/time when
   present.
3. Save transactions locally even when offline.
4. Synchronize user-owned transactions with Supabase when online.
5. Detect duplicate captures and never silently create duplicate records.
6. Provide a dashboard, transaction history, category breakdown, review queue,
   and settings.
7. Record both income and expense in one ledger, with fast manual entry for
   cash.
8. Authenticate exclusively through Google and Apple.
9. Use FVM to pin the Flutter SDK for reproducible builds.
10. Keep the architecture ready for Android without rebuilding the domain layer.
11. Keep the domain layer free of framework dependencies, enforced in CI.
12. Incur zero marginal operating cost per capture.

### 2.2 MVP success criteria

- A double Back Tap on a supported receipt screen produces a transaction with
  no typing.
- A valid capture is persisted locally before any network operation.
- Re-triggering the same capture does not create another transaction.
- A transaction created offline is queued and synced when connectivity returns.
- Each authenticated user can read and mutate only their own cloud records.
- Unreadable or ambiguous captures produce a reviewable draft or an honest
  failure — never a fabricated transaction.
- Ledger and dashboard work fully offline after initial sign-in.
- A user can delete their account and all data from inside the app.
- No screenshot image is ever transmitted off the device.

---

## 3. Target Users and Primary Use Case

### Primary user

A person who makes frequent digital payments — predominantly through
Indonesian e-wallets and bank apps — and wants a complete expense record
without manual entry.

### Primary user journey (Route B, primary)

1. User pays in a third-party app.
2. User reaches the payment receipt or success screen.
3. User **double-taps the back of the iPhone**.
4. Back Tap runs the Soreva Shortcut.
5. The Shortcut's **Take Screenshot** action captures the screen.
6. The Shortcut passes the image to the Soreva **App Intent**.
7. The App Intent runs **Apple Vision** OCR on-device, writes a capture record
   (extracted text plus metadata) to the **App Group inbox**, discards the
   image, and returns.
8. On next app run or background refresh, Dart drains the inbox: parses,
   categorizes, validates, deduplicates.
9. A confident transaction is saved; an uncertain one is saved as a draft.
10. The transaction is queued for cloud sync.
11. The dashboard reflects it.

### Alternate journey (Route A, fallback)

Steps 1–3 identical. Back Tap is configured to the **built-in Screenshot
action** with no Shortcut. The screenshot lands in Photos. On next app run,
Soreva queries PhotoKit for new screenshot-subtype assets, OCRs them, and
proceeds from step 8. Requires Photos read permission.

### Fallback journeys

- **Share Sheet:** share any receipt image, PDF, or text into Soreva.
- **Manual entry:** required for cash, and the only path for income.
- **Capture diagnostics:** when OCR yields nothing usable, the app reports why
  and offers manual entry. It never claims success.

---

## 4. Scope

### 4.1 MVP — In scope

- iOS application built with Flutter, FVM-managed and pinned.
- Swift App Intent exposing a screenshot-accepting capture action.
- Route B: Back Tap → Shortcut → Take Screenshot → App Intent.
- Route A: Back Tap → native Screenshot → PhotoKit detection.
- On-device Apple Vision OCR.
- App Group inbox handoff from Swift to Dart.
- Back Tap and Shortcut setup guidance, with a one-tap Shortcut install link.
- Receipt text parsing for amount, currency, merchant, date, time, reference
  ID — implemented in Dart.
- Source-app inference from OCR text with a brand-keyword dictionary.
- Deterministic category suggestion.
- Local persistence via Drift over SQLite.
- Income and expense ledger, single account.
- Fast manual entry.
- Share Sheet extension.
- Transaction history, dashboard summaries, review queue.
- Duplicate detection.
- Supabase Auth restricted to Google and Apple.
- Supabase PostgreSQL with Row Level Security.
- Local-first sync queue with retry and conflict handling.
- Settings, sync status, sign-out, data export.
- **In-app account deletion** (App Store requirement, §5.4).
- Clean-architecture layering with CI-enforced boundaries.

### 4.2 Out of scope for MVP

- Reading another app's data, notifications, or memory. Only rendered pixels
  are read, and only when the user triggers it.
- Guaranteed extraction from every possible receipt layout.
- Direct access to bank or e-wallet APIs.
- Continuous, background, or unattended screen capture.
- AI/LLM categorization requiring paid external APIs.
- Email/password or magic-link authentication.
- Guest or anonymous mode.
- Multiple accounts/wallets and transfers.
- Budgets, goals, recurring transactions.
- Screenshot or receipt image storage and upload.
- Siri voice entry (Phase 2).
- Shared household budgets or multi-user accounts.
- Subscription billing and monetization.
- Android capture (Phase 4).
- Non-mobile platform targets.
- Financial advice, transfers, or initiating payments.

---

## 5. Platform and Technical Constraints

### 5.1 Capture mechanism — corrected premise

**v1.0 and v2.0 both stated that the central risk was whether third-party apps
"expose their receipt content to Shortcuts." That framing was wrong.**

No cooperation from the payment app is required or requested. The app captures
a **screenshot** — the same pixels the user is already looking at — and reads
it with on-device OCR. Apple Vision is indifferent to which app rendered the
screen. Consequently:

- There is no dependency on GoPay, OVO, DANA, ShopeePay, or any bank app
  providing an integration, an API, or Shortcuts support.
- The residual risk is **OCR legibility and layout variance**, not app
  cooperation. That is a tractable parsing problem with a user-correctable
  failure mode, not an existential product risk.
- iOS provides no API for an app to read another app's screen unprompted. Both
  routes are **user-initiated per capture**, which is what makes them
  permissible.

### 5.2 iOS capture constraints

- Back Tap is configured by the user in Settings → Accessibility → Touch →
  Back Tap. The app cannot listen for Back Tap directly and must guide setup.
- **Minimum supported iOS is 18.2 (D-22).** Every capture API the product
  relies on — `Get Current App`, `Take Screenshot`, and App Intents image
  parameters — is therefore guaranteed present. No capability checks or
  version-conditional fallbacks are needed anywhere in the capture path.
- Back Tap requires iPhone 8 or later, but iOS 18 requires iPhone XS/XR or
  later. The 18.2 floor therefore excludes iPhone 8 and X, which support Back
  Tap but cannot run the OS. This is an accepted trade (D-22); confirm the
  exact supported-device list against Apple's iOS 18 compatibility page before
  release.
- Back Tap is unavailable on iPad.
- Route B depends on App Intents accepting an image parameter (`IntentFile`
  with `public.image`).
- App Intents run under a short execution budget. Native work is limited to
  OCR plus one atomic file write — no parsing, no network, no database.
- The App Intent must not require a running Flutter/Dart engine (§7.6).
- Route A requires Photos read permission and a privacy purpose string.
- Test with the app foregrounded, backgrounded, and never launched.

**Unresolved and gating route priority — Phase 0 must answer on a real device:**

1. Does **Take Screenshot** prompt for permission on every run when fired from
   Back Tap, or only on first use? Public documentation does not say.
2. Does it capture the **payment app** or the Shortcuts overlay/banner?
3. Does **Get Current App** return the payment app, or Shortcuts itself, when
   the Shortcut is fired from Back Tap? Same uncertainty class as question 2.
4. What is the end-to-end latency from tap to inbox write?
5. Does any of this behave differently when the app has never been launched?

If Route B prompts on every capture or captures the wrong surface, **Route A
becomes primary.** This is precisely why both are built (D-17).

### 5.3 OCR, extraction, and attribution

- Apple Vision performs on-device text recognition. It is part of the iOS SDK:
  no API key, no account, no per-call charge, no network. It works offline and
  has **zero marginal cost** at any scale.
- Vision produces **text only**. All interpretation happens in Dart.
- Parse with deterministic rules and locale-aware number/date handling.
- Recognize total labels including "Total", "Amount paid", "Grand total", and
  Indonesian equivalents: "Jumlah", "Total Bayar", "Total Pembayaran",
  "Nominal", "Total Harga".
- Never treat subtotal, discount, tax, change, or balance as the final amount
  without sufficient evidence.
- Store extraction confidence and the provenance of each field.
- If multiple plausible totals exist and cannot be resolved, save a draft
  flagged ambiguous rather than guessing.

**Attribution uses two distinct fields (D-18).** Apple Vision itself cannot
identify an app: its request types are text recognition, face and barcode
detection, image classification against ~1000 generic everyday classes, and
custom Core ML models. None of them recognize applications. Attribution
therefore comes from two independent sources, and the app records both.

**`source_app` — authoritative, from the OS.** The Shortcuts **Get Current
App** action, available since **iOS 18.2**, returns the app currently in use.
In Route B the Shortcut runs `Get Current App` before `Take Screenshot` and
passes the app name and identifier into the App Intent alongside the image.
This is reported by the system, not guessed, and carries full confidence.

**`payment_provider` — inferred, from the pixels.** The wallet or bank that
actually moved the money is read from brand strings and layout cues in the OCR
text, matched against a maintained keyword dictionary (GoPay, OVO, DANA,
ShopeePay, QRIS, BCA, Livin, and others). Store `provider_detection_method`
and a confidence score, default to `unknown`, and always let the user correct
it. Never present an inferred provider as certain.

**The two fields genuinely differ**, which is why both are kept. Paying with a
GoPay-linked card inside Tokopedia yields app = Tokopedia, provider = GoPay.
Screenshotting a receipt email yields app = Gmail, provider = whatever the
email states. For budgeting, `payment_provider` is usually the meaningful
field; `source_app` is the reliable one. Neither alone is sufficient.

**Degradation.** With the 18.2 floor (D-22), `Get Current App` is available on
every supported device, so `source_app` is always authoritative on Route B.
Only Route A degrades: a native screenshot carries no app context and Photos
records no source app, so `source_app` there falls back to OCR inference with
reduced confidence and `attribution_source` is set honestly. This is a
material advantage for Route B beyond its privacy posture.

### 5.4 Authentication and App Store constraints

Direct consequences of D-03 and D-04, to be designed for rather than
discovered at review time.

- **Guideline 4.8 — Sign in with Apple is mandatory.** Offering Google sign-in
  on iOS obliges offering Sign in with Apple. Both are required.
- **Guideline 5.1.1(v) — in-app account deletion is mandatory.** A documented
  policy is insufficient. The flow must delete the Supabase account, all cloud
  rows, and all local data.
- **Guideline 5.1.1(i) — the sign-in wall is a review risk.** The app is
  local-first and works offline, so a reviewer may argue mandatory sign-in is
  unjustified. Mitigation: onboarding and the store listing must consistently
  present cloud backup, recovery, and future multi-device access as the
  account-based functionality the sign-in enables.
- **Apple returns the full name only on first authorization.** Persist it then
  or lose it permanently.
- **Apple users may hide their email behind a private relay.** Email is not a
  stable identity key; key all ownership on the Supabase user UUID.
- Handle externally revoked Apple credentials gracefully on next launch.
- **Privacy disclosure:** the app reads screen content the user explicitly
  captures. Onboarding, the privacy policy, and the App Store privacy
  questionnaire must state plainly that OCR is on-device and screenshots are
  never uploaded. Route A's Photos permission needs a clear purpose string.

### 5.5 Cost constraints

The app is free to users and nearly free to operate.

| Item | Cost | Notes |
|---|---|---|
| Apple Developer Program | USD 99/year | **Already enrolled (D-21)** — not a blocker. |
| **Apple Vision OCR** | **USD 0, unlimited** | On-device, part of the OS. No key, no quota, no bill. Zero marginal cost per capture. |
| Google Play Developer | USD 25 one-time | Phase 4 only. |
| Supabase | USD 0 (free tier) | Structured rows are tiny; the DB ceiling is not the binding constraint. Free projects pause after inactivity, and growth eventually forces the paid tier. **Verify current limits at bootstrap — they change.** |
| Google Sign-In / Google Cloud project | USD 0 | OAuth client and consent screen are free. |
| Flutter, Dart, FVM, GetX, Drift, Supabase SDK | USD 0 | All open source. |
| CI — GitHub Actions | USD 0 on public repos | macOS runners consume quota ~10x faster than Linux. A private repo exhausts the free allowance quickly; keep the repo public or build iOS locally. |
| Crash reporting | USD 0 | Sentry free tier or Firebase Crashlytics. |

**Cost mitigation by design:** the architecture is local-first, so cloud sync
is a *feature*, not a dependency. If Supabase ever becomes a cost problem,
sync can be disabled or self-hosted and the app still works completely. **No
design decision may violate this property.** Since OCR is on-device and free,
the per-capture cost is zero regardless of user count — the expensive part of
a receipt-scanning product is exactly the part that costs nothing here.

### 5.6 Android readiness

- Keep domain models, category logic, dedup rules, sync contracts, and
  repository interfaces in Dart.
- Keep Apple-specific code behind platform adapters.
- Android has no Back Tap. Plan a Quick Settings Tile, widget, or accessibility
  trigger, plus ML Kit text recognition (also free, on-device) in place of
  Vision. Do not promise identical behavior.

---

## 6. Technology Stack

| Area | Decision |
|---|---|
| App framework | Flutter |
| SDK management | FVM; exact version pinned in `.fvmrc` |
| Language | Dart (app), Swift (native iOS) |
| State management | GetX, presentation layer only (§7.3) |
| Dependency injection | GetX `Bindings`, presentation layer only |
| Routing | GetX named routes behind a navigation service |
| System trigger | Back Tap → Shortcut (Route B) or native Screenshot (Route A) |
| Shortcut integration | App Intents with an `IntentFile` image parameter |
| App attribution | Shortcuts `Get Current App` action, iOS 18.2+ (Route B) |
| OCR | Apple Vision, on-device, text extraction only, free |
| Photo detection (Route A) | PhotoKit, `PHAssetMediaSubtype.photoScreenshot` |
| Native-to-Dart handoff | App Group inbox, JSON capture records (§7.6) |
| Local database | Drift over SQLite, owned exclusively by Dart |
| Cloud backend | Supabase |
| Authentication | Supabase Auth — Google and Apple providers only |
| Cloud database | Supabase PostgreSQL |
| Authorization | PostgreSQL Row Level Security on all user-data tables |
| Sync | Application-managed outbox; local write first, cloud second |
| Secure storage | Keychain via `flutter_secure_storage` |
| Secrets | No service-role key or privileged secret in the app |
| CI/testing | Dart unit tests, domain-boundary lint, iOS build check |

### 6.1 FVM requirements

- Use FVM for all Flutter commands.
- Pin an exact stable Flutter version in `.fvmrc` at bootstrap, selected by
  checking which current stable satisfies Dart `^3.9.2` and is compatible with
  the installed Xcode and native dependencies. Verify with `fvm releases` and
  `fvm flutter doctor`; do not assume a version.
- Commit `.fvmrc` and `pubspec.lock`.
- Document setup in `README.md`.
- Never upgrade Flutter or major dependencies without running the test suite
  and validating the native iOS build.
- Setup workflow: `fvm install <PINNED_VERSION>` → `fvm use <PINNED_VERSION>`
  → `fvm flutter doctor` → `fvm flutter pub get` → `fvm flutter test`

### 6.2 Repository hygiene

- Initialize git before further work; the project is currently untracked.
- Remove the unused `web/`, `macos/`, `linux/`, and `windows/` directories
  generated by `flutter create` (D-05).
- Keep `.fvmrc`, `pubspec.lock`, and `analysis_options.yaml` committed.

---

## 7. Architecture

### 7.1 High-level flow

**Route B (primary):**
Double Back Tap → Shortcut → Take Screenshot → Swift App Intent → Apple
Vision OCR → App Group inbox → *(image discarded)*

**Route A (fallback):**
Double Back Tap → native Screenshot → Photos → PhotoKit scan on app run →
Apple Vision OCR → App Group inbox

**Shared pipeline:**
Inbox drain → Dart parser → validation → deduplication → Drift local
transaction → sync outbox → Supabase

Flutter reads the local repository and renders the UI. Cloud sync runs
independently of rendering.

### 7.2 Layer structure

```
lib/
  core/            # Result/Failure types, env config, constants, utils
  domain/          # entities, repository INTERFACES, usecases, pure rules
                   #   -> zero framework imports. Enforced in CI (§7.4)
  data/            # DTOs, local (Drift) + remote (Supabase) datasources,
                   #   repository IMPLEMENTATIONS, mappers, platform channels
  presentation/    # pages, widgets, GetxController, Bindings, view state
  app/             # routes, global bindings, theme, DI composition root
```

Dependency rule: `presentation -> domain <- data`. The domain layer depends on
nothing but `core` and the Dart SDK.

Receipt parsing, source-app inference, categorization, deduplication, and money
arithmetic all live in `domain/` as pure functions — unit-testable with no
device, database, or network. This is deliberate: those five rule sets are the
product's actual intellectual content and the most likely source of financial
error, so they must be the cheapest things to test.

### 7.3 GetX containment rules

GetX offers state management, DI, routing, HTTP, and storage. Only the first
three are adopted, and only in `presentation/`. Unconstrained GetX usage
dissolves the architecture into a service locator.

**Permitted:**
- `GetxController` subclasses in `presentation/`, holding view state.
- `Bindings` per route, lazily constructing controllers and injecting usecases.
- `Obx` / `GetBuilder` bound to presentation view-state objects.
- GetX named routes, invoked through a `NavigationService` interface so
  controllers are testable without a widget tree.

**Forbidden:**
- `GetConnect` — networking belongs to `data/`, via the Supabase client.
- `GetStorage` — persistence belongs to `data/`, via Drift and Keychain.
- Any `import 'package:get/get.dart'` under `lib/domain/` or `lib/data/`.
- `Get.find()` inside entities, usecases, or repository implementations;
  dependencies arrive via constructors.
- Binding `Obx` directly to domain entities; map to view state first.

**Rationale and exit path:** GetX is less actively maintained than it once was,
and the wider Flutter ecosystem has largely moved to Riverpod and Bloc. GetX
remains productive and is the chosen tool. Confining it to `presentation/`
means a future migration touches controllers and bindings only — domain, data,
parsing, and sync stay untouched. This containment is what keeps the decision
cheap to reverse.

### 7.4 Boundary enforcement

Enforced mechanically, because review does not reliably catch gradual drift.
CI fails if either check matches:

```bash
# domain must not import any framework
! grep -rn --include='*.dart' -E \
  "package:(get|supabase_flutter|drift|sqflite|flutter)/" lib/domain/

# data must not import GetX or Flutter widgets
! grep -rn --include='*.dart' -E \
  "package:(get|flutter)/" lib/data/
```

`analysis_options.yaml` enables strict analyzer settings, and CI treats
analyzer warnings as build failures.

### 7.5 Dual-route capture design (D-17)

Both routes converge on an identical contract after the image exists, so the
second route costs roughly 10% extra work and removes the single point of
failure from the headline feature.

| Stage | Route B (primary) | Route A (fallback) |
|---|---|---|
| Trigger | Back Tap → Shortcut | Back Tap → native Screenshot |
| Image source | `IntentFile` passed in-process | PhotoKit screenshot asset |
| App attribution | **Authoritative** via `Get Current App` (iOS 18.2+) | OCR inference only — Photos records no source app |
| Permission | Shortcut run (prompt behavior TBD, §5.2) | Photos read |
| Image persisted | No — discarded after OCR | Yes, in Photos (not copied) |
| Latency | Immediate | Deferred to next app run |
| Privacy posture | Strongest | Good, but image remains in Photos |
| iOS floor | 18.2 (project minimum, D-22) | 18.2 (project minimum, D-22) |

Route selection is a runtime setting, defaulted by what Phase 0 proves and
overridable by the user in Settings. Onboarding configures whichever route is
primary and offers the other if setup fails.

### 7.6 Native capture handoff — App Group inbox (D-08)

**This replaces v1.0's shared-SQLite requirement.**

v1.0 required both the Swift App Intent and the Flutter app to read and write
one SQLite file through an App Group. That costs two writers in two languages
on one file, duplicated schema and migration logic in Swift, and real
multi-process locking and corruption exposure. It also contradicted v1.0's own
requirement that parsing stay platform-independent Dart, since a Swift-only
save path forces that logic into Swift.

It was also unnecessary: v1.0 §3 already accepted that the dashboard reflects a
capture the next time the app opens, so no shared writable database is needed.

**Design:**

1. The Swift App Intent receives the image, runs Vision OCR, and writes exactly
   one immutable JSON record into the App Group container:

   ```
   <AppGroup>/inbox/<capture_attempt_uuid>.json
   {
     "capture_attempt_id": "<uuid>",
     "created_at": "<ISO8601>",
     "route": "shortcut_intent" | "photokit",
     "input_kind": "image" | "text",
     "raw_text": "<Vision output>",
     "foreground_app_name": "<from Get Current App, or null>",
     "foreground_app_id": "<bundle id if available, or null>",
     "attribution_source": "get_current_app" | "ocr_inference" | "unavailable",
     "ocr_engine": "vision",
     "ocr_block_confidences": [ ... ],
     "schema_version": 1
   }
   ```

2. Swift performs no parsing, categorization, deduplication, database access,
   or network calls. Writes are atomic (temp name, then rename).
3. The image is discarded immediately after OCR and never written to the
   container (D-19).
4. On launch, resume, and background refresh, Dart drains the inbox: parses,
   validates, deduplicates, persists via Drift, enqueues sync, deletes the file.
5. Draining is idempotent and keyed on `capture_attempt_id`, so a crash
   mid-drain cannot double-insert.
6. The inbox is the only shared surface between languages. The database has a
   single owner.

**Accepted trade-off:** a capture is not visible until the app next runs.

### 7.7 Local-first transaction lifecycle

1. A capture record arrives in the inbox, or the user enters a transaction.
2. Normalize content; `capture_attempt_id` is the idempotency key.
3. Extract candidate fields with confidence scores.
4. Validate required fields: credible amount, currency, direction.
5. Run exact and heuristic duplicate checks.
6. Save the transaction and its sync-outbox event in one local DB transaction.
7. Update the local UI data source.
8. If online with a valid session, attempt sync.
9. Mark the outbox item synchronized only after server confirmation.
10. Retry transient failures with bounded exponential backoff; never create a
    second transaction on retry.

### 7.8 Cloud sync rules

- Local storage is the immediate source of truth for capture and UI feedback.
- Supabase is the account-backed copy for recovery and future multi-device use.
- Every record carries a stable client-generated UUID.
- Upserts use stable IDs and unique constraints so retries are idempotent.
- Track `updated_at`, sync state, and soft-delete/tombstone state.
- For MVP, transactions are append-oriented; edits use version/timestamp rules
  and must not blindly overwrite newer server data.
- Structured fields only; no images (D-11).
- Network failure must never roll back a saved local transaction.
- An expired session must never cause local data loss; queue and prompt for
  re-authentication.

---

## 8. Functional Requirements

### FR-01: Onboarding and setup

- Explain honestly what capture can and cannot do, including that cash is
  invisible to it and that source-app detection is a guess.
- State plainly that OCR is on-device and screenshots are never uploaded.
- Present cloud backup and recovery as the reason an account is required
  (§5.4, Guideline 5.1.1(i)).
- Provide a one-tap Shortcut install link and step-by-step Back Tap setup with
  screenshots.
- Offer the alternate route if the primary one fails during setup.
- Let the user test capture on a sample receipt and see the parsed result.

### FR-02: Authentication

- **Google Sign-In and Sign in with Apple only** (D-03, D-04). No
  email/password, magic links, guest, or anonymous mode.
- Both providers offered on iOS; Apple is mandatory alongside Google
  (Guideline 4.8).
- Sign-in required before any transaction can be recorded.
- Sign-out and silent session restoration on launch.
- Persist the Apple full name on first authorization only; never overwrite it
  with null on later sign-ins.
- Treat email as non-identifying; expect Apple private-relay addresses. Key all
  ownership on the Supabase user UUID.
- Handle externally revoked Apple credentials gracefully.
- **In-app account deletion** removing the Supabase account, all cloud rows,
  and all local data (Guideline 5.1.1(v)).
- Session tokens in the Keychain.
- Never embed privileged Supabase service-role credentials.

### FR-03: Screen capture

- Support Route B and Route A (D-17), selectable in Settings.
- Capture only on explicit user trigger. No continuous, background, or
  unattended capture.
- Run Vision OCR on-device; discard the image immediately (Route B).
- Write one inbox record per capture attempt.
- Never present a capture as successful before it is saved locally.
- Provide Share Sheet and manual-entry fallbacks.
- Record a diagnostic result for every attempt, including failures.

### FR-04: Transaction extraction

Fields:
- Amount / total — required to auto-save
- Direction — expense or income; capture always yields expense
- Currency — required; may default from settings but must be explicit in the
  stored record
- Merchant / payee — optional
- Source application — **authoritative** from `Get Current App` on iOS 18.2+
  via Route B; degrades to OCR inference otherwise. Store `attribution_source`
  (D-18)
- Payment provider — **inferred** from OCR branding; store detection method and
  confidence, default `unknown` (D-18)
- Category — suggested, with `Uncategorized` fallback
- Transaction date/time — optional when absent; falls back to capture time
- Capture timestamp — always recorded
- Reference/receipt ID — optional
- Extraction confidence and review status

### FR-05: Categorization

- Deterministic merchant/category mapping and keyword rules.
- `Uncategorized` fallback.
- User edits to category, remembered for that merchant.
- No external paid AI API (§5.5).
- Logic lives in `domain/` and is platform-independent.

### FR-06: Duplicate prevention

Levels, in order:
1. Exact match on `capture_attempt_id`.
2. Exact match on source plus stable transaction/reference ID when available.
3. Exact normalized receipt fingerprint when one can be generated reliably.
4. Heuristic comparison of amount, currency, merchant, transaction time, source.

A heuristic-only match is marked a **possible duplicate** for user review, never
auto-deleted — two legitimate purchases can look identical. Enforced locally and
backed by server-side unique constraints where the data supports them. Repeated
sync attempts must be idempotent.

### FR-07: Local ledger management

- Chronological list covering income and expense.
- **Fast manual entry** — a first-class flow, not an afterthought, since cash
  can never be captured.
- Daily/monthly totals, net position, category breakdowns.
- Search and filter by date, direction, category, merchant, source.
- Edit and delete transactions.
- Review queue for drafts and possible duplicates (D-10).
- Changes reflected immediately without waiting for sync.

### FR-08: Synchronization

- Show whether sync is current, pending, or failed.
- Queue local writes while offline.
- Bounded exponential backoff on transient failures.
- No duplicate cloud rows on retries.
- Handle expired sessions without losing local transactions.
- Manual "Sync now" action.

### FR-09: Privacy and security

- TLS for all network communication.
- **No screenshot or receipt image leaves the device, ever** (D-19).
- OCR entirely on-device.
- RLS enabled on every user-data table, with policies restricting rows to
  `auth.uid()`.
- Least-privilege grants, tested with multiple users.
- Session tokens in the Keychain.
- Never log raw OCR text, tokens, or full financial details in production.
- Collect only what the product functionally requires.
- Implement data export, data deletion, and account deletion before release.
- Evaluate iOS Data Protection for the local database file.
- The App Group container holds only transient inbox records, deleted on
  consume. No images.

---

## 9. Data Model

### 9.1 `profiles`

- `id` UUID, primary key, references the authenticated user
- `display_name` text nullable — from Apple's first-authorization name or
  Google profile
- `default_currency` text
- `preferred_capture_route` text — `shortcut_intent` or `photokit`
- `created_at`, `updated_at` timestamps

### 9.2 `categories`

- `id` UUID, primary key
- `owner_id` UUID nullable for built-in categories
- `name` text
- `direction` text — `expense`, `income`, or `both`
- `icon_key`, `color_key` text nullable
- `is_system` boolean
- `created_at` timestamp

### 9.3 `transactions`

- `id` UUID, primary key, generated client-side
- `owner_id` UUID, required
- `direction` text, required — `expense` or `income`
- `amount_minor` BIGINT, required — see §9.5
- `currency` text, required
- `currency_scale` smallint, required — frozen at write time
- `merchant_name` text nullable
- `source_app_id`, `source_app_name` text nullable — which iOS app was on screen
- `attribution_source` text nullable — `get_current_app`, `ocr_inference`,
  `user`, `unavailable`
- `payment_provider` text nullable — which wallet or bank moved the money
- `provider_detection_method` text nullable — `ocr_keyword`, `user`, `unknown`
- `provider_confidence` numeric nullable
- `category_id` UUID nullable
- `transaction_at` timestamp nullable
- `captured_at` timestamp, required
- `entry_method` text — `capture_route_b`, `capture_route_a`, `share_sheet`,
  `manual`
- `capture_attempt_id` UUID nullable — idempotency key for captured rows
- `reference_id` text nullable
- `receipt_fingerprint` text nullable
- `extraction_confidence` numeric nullable
- `review_status` text — `confirmed`, `needs_review`, `possible_duplicate`
- `created_at`, `updated_at` timestamps
- `deleted_at` timestamp nullable

### 9.4 `sync_outbox` (local only)

- `id` UUID, primary key
- `entity_type`, `entity_id`, `operation`
- `payload_version` integer
- `created_at` timestamp
- `attempt_count` integer
- `last_attempt_at` timestamp nullable
- `last_error_code` text nullable
- `sync_status` text

### 9.5 Money representation (D-12)

- Store `amount_minor` BIGINT with an explicit `currency_scale`. The real value
  is `amount_minor / 10^currency_scale`.
- **IDR uses scale 0.** The sen subunit is obsolete in practice; treating IDR as
  two-decimal would introduce a silent 100x error.
- USD, EUR and similar use scale 2.
- BIGINT is required, not INTEGER: IDR amounts are large and a 32-bit column
  overflows near Rp 2.1 billion.
- `currency_scale` is stored per row, not looked up at read time, so historical
  rows stay correct if a scale table is later corrected.
- All money arithmetic lives in a `domain/` value object. **No floating point
  anywhere in the money path.**

### 9.6 Data-model notes

- Never use amount plus date alone as a unique key.
- No image retention in MVP.
- Index `owner_id`, `transaction_at`, `category_id`, `capture_attempt_id`
  (unique where not null), and sync columns.
- Cloud tables carry RLS; the local Drift schema mirrors them minus `owner_id`
  enforcement, which is implicit in a single-user local database.

---

## 10. Non-Functional Requirements

### Reliability

- Local save is atomic.
- Capture never requires network availability.
- Inbox draining is idempotent and crash-safe.
- Sync retries never create duplicates.
- Every database migration has a test and preserves existing local data.
- If the primary capture route fails, the fallback route remains available.

### Performance

- The App Intent completes within the iOS execution budget — OCR plus one file
  write.
- Local save completes quickly after parsing and validation.
- OCR runs on-device.
- OCR, parsing, and network work never block the Flutter UI thread.
- Dashboard summaries push aggregation into SQL rather than Dart loops.

### Security and privacy

- Strong per-user cloud isolation, verified by multi-user tests.
- No privileged cloud keys in client code.
- No image ever transmitted; OCR text minimized and never logged.
- Clear user-facing explanation of what is captured and what is synchronized.

### Maintainability

- Flutter SDK pinned with FVM.
- Four-layer separation with CI-enforced boundaries (§7.4).
- Platform-specific code behind interfaces.
- Tests for parsing, source inference, categorization, deduplication, money
  arithmetic, sync retries, migrations, and RLS authorization.
- GetX confined to presentation so it stays replaceable (§7.3).

### Accessibility and localization

- Accessible text sizes and screen-reader labels.
- Data model designed for localized dates, number formats, currency formatting.
- Indonesian and English at launch *(D-13, proposed)*.

---

## 11. MVP Screens

1. **Onboarding** — honest capability disclosure, on-device-OCR privacy
   statement, account rationale, Shortcut install link, Back Tap setup guide,
   live capture test.
2. **Authentication** — Google and Apple buttons only.
3. **Dashboard** — spending today/month, income and net, category breakdown,
   recent transactions, sync status.
4. **Transaction history** — searchable and filterable.
5. **Transaction detail/edit** — amount, direction, merchant, category,
   date/time, source with confidence, review status.
6. **Review queue** — drafts and possible duplicates awaiting confirmation.
7. **Manual entry** — fast path for cash and income.
8. **Capture diagnostics** — last capture result, failure reason, active route,
   fallback guidance.
9. **Settings** — account, capture route, default currency, categories, data
   export, sync status, privacy, sign-out, **delete account**.

Capture must never open the Flutter UI when the native action can process the
image and write to the inbox.

---

## 12. Acceptance Criteria

**Project setup**
- [ ] Repository under git version control.
- [ ] FVM used; `.fvmrc` and `pubspec.lock` committed.
- [ ] Unused platform directories removed.
- [ ] iOS app builds with the pinned Flutter SDK and selected Xcode.

**Architecture**
- [ ] `lib/` follows the four-layer structure in §7.2.
- [ ] CI fails on any framework import under `lib/domain/`.
- [ ] CI fails on any GetX or Flutter import under `lib/data/`.
- [ ] No `GetConnect` or `GetStorage` usage anywhere.
- [ ] Parsing, source inference, categorization, deduplication, and money
      arithmetic are unit tested with no device, database, or network.

**Capture**
- [ ] A double Back Tap on a receipt screen produces a transaction with no
      typing, on a real device.
- [ ] Route B passes a screenshot into the App Intent and OCRs it without a
      running Dart engine.
- [ ] Route A detects a new screenshot via PhotoKit and OCRs it.
- [ ] Both routes write a valid inbox record with the correct `route` value.
- [ ] Route B leaves no image on disk after OCR.
- [ ] Inbox draining is idempotent across a simulated mid-drain crash.
- [ ] Vision OCR runs with no network connection.
- [ ] Supported receipts yield parsed candidates for amount, merchant,
      category, and date/time.
- [ ] Source-app inference reports a confidence score and falls back to
      `unknown` rather than guessing confidently.
- [ ] Missing or ambiguous values produce a reviewable draft, never a
      fabricated transaction.
- [ ] Repeating the same capture does not create a second transaction.
- [ ] Share Sheet and manual fallbacks are documented and tested.
- [ ] Capture diagnostics report an honest reason for every failure.

**Ledger and sync**
- [ ] A valid transaction saves locally while offline.
- [ ] Income and expense both record and are distinguished in totals.
- [ ] An IDR amount round-trips through local and cloud storage with no scale
      error.
- [ ] List and dashboard update immediately after a successful save.
- [ ] Reconnection synchronizes pending transactions without duplication.
- [ ] An expired session loses no local data.

**Auth, privacy, compliance**
- [ ] Google Sign-In and Sign in with Apple both work on a real device.
- [ ] No email/password or anonymous auth path exists.
- [ ] Apple's first-authorization name persists; a second sign-in does not
      null it.
- [ ] An Apple private-relay email breaks neither identity nor sync.
- [ ] Two users cannot access each other's cloud transactions (multi-user RLS
      test).
- [ ] In-app account deletion removes the Supabase account, all cloud rows, and
      all local data.
- [ ] Data export produces a complete, re-importable file.
- [ ] No service-role key or privileged secret in the built app.
- [ ] No network request anywhere in the app carries image data.

---

## 13. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| ~~Third-party apps do not expose receipt content~~ | **Retired in v3.0** | Obsolete under D-16: the app screenshots pixels and needs no cooperation from the payment app. |
| Take Screenshot prompts for permission on every Back Tap run | Capture stops being frictionless | Phase 0 validates first; Route A becomes primary if so (D-17, §5.2) |
| Take Screenshot captures the Shortcuts overlay instead of the payment app | Route B unusable | Same — Route A is the built fallback, not a hypothetical one |
| OCR misreads total as subtotal, tax, or balance | Incorrect financial records | Confidence scoring, deterministic Dart parsing, draft-on-ambiguity, user correction |
| Receipt layout variance across wallets and banks | Patchy extraction quality | Per-provider parser rules seeded from the Phase 0 corpus; regression tests per layout; graceful degradation to draft |
| `Get Current App` returns Shortcuts instead of the payment app | Wrong app attribution | Phase 0 question 3 (§5.2); fall back to OCR inference and flag `attribution_source` honestly |
| Payment provider cannot be inferred from receipt text | Missing provider attribution | Best-effort with confidence, `unknown` default, user-correctable; `source_app` still authoritative on 18.2+ (D-18) |
| iOS 18.2 floor excludes iPhone 8 and X | Smaller addressable device base | Accepted trade for a single code path and guaranteed attribution (D-22); revisit only if telemetry shows meaningful demand |
| Duplicate capture or sync retry | Inflated spending totals | `capture_attempt_id` idempotency, stable IDs, unique constraints, fingerprinting, idempotent upserts |
| App Intent exceeds its execution budget | Capture fails in some states | Native work limited to OCR plus one atomic write; test all lifecycle states |
| User declines Photos permission | Route A unavailable | Route B needs no Photos access; onboarding explains the trade-off |
| Local and cloud data diverge | Inconsistent history | Durable outbox, explicit conflict policy, sync status, retry handling |
| Misconfigured RLS | **Financial data exposure** | RLS on every table, multi-user policy test as a CI gate |
| IDR assumed to be 2 decimals | **Silent 100x money error** | Explicit per-row `currency_scale`, IDR scale 0, round-trip acceptance test |
| Screenshots of payment screens are highly sensitive | Privacy harm, review scrutiny | On-device OCR only, image discarded immediately, never uploaded, never logged (D-19) |
| Sign-in wall rejected under Guideline 5.1.1(i) | App Store rejection | Frame the account as enabling backup and recovery, consistently in app and listing |
| Missing in-app account deletion | App Store rejection | Built in MVP, not post-launch |
| Apple name captured once, then lost | Permanently blank display names | Persist on first authorization; covered by acceptance criterion |
| Supabase free tier outgrown | Unexpected operating cost | Local-first means sync is optional; app degrades to offline-only. OCR cost stays zero regardless of scale |
| GetX maintenance decline | Future migration cost | GetX confined to `presentation/`; domain and data unaffected by a swap |
| Flutter/native dependency incompatibility | Build instability | Pin SDK with FVM; validate package and Xcode compatibility before upgrades |

---

## 14. Delivery Plan

### Phase 0 — Technical feasibility (hard gate)

Capture is the product (D-01), so this phase decides route priority and proves
the pipeline. **Timebox: 2 weeks.** The Apple Developer account is already in
place (D-21), so work can start immediately.

**Setup**
- Initialize git, FVM, and the pinned Flutter version.
- Create the four-layer skeleton and the CI boundary check.
- Configure the App Group and a minimal App Intent target.

**Route B validation**
- Build a Shortcut: Get Current App → Take Screenshot → Soreva App Intent.
- Bind it to double Back Tap on a real iPhone.
- Answer the five questions in §5.2: per-run permission prompt, captured
  surface, latency, cold-start behavior.

**Route A validation**
- Bind double Back Tap to the native Screenshot action.
- Detect new screenshot assets via PhotoKit and OCR them.
- Measure the permission flow and detection reliability.

**Shared pipeline validation**
- Run Vision OCR against receipt screens from the D-14 apps; build the initial
  corpus.
- Validate the App Group inbox write and Dart drain, including crash
  idempotency.
- Assess how often amount, merchant, and date are extractable, and how often
  source app is inferable, per provider.

**Exit criteria**
- At least one route works end to end, unattended, from a double Back Tap.
- The OCR corpus shows acceptable extraction rates for amount and date across
  the D-14 apps.
- Route priority is decided on evidence and recorded in this PRD.

**Pivot criterion:** if *both* routes fail to capture the foreground app
unattended, the product reframes around the Share Sheet plus fast manual entry,
and this PRD is revised before Phase 1. Do not build Phase 1 on an unvalidated
capture path.

### Phase 1 — Local MVP

- Onboarding, Shortcut install link, Back Tap setup guide, capture test.
- Drift data layer, schema, migration tests.
- Receipt parsing, source inference, and categorization in `domain/`, fully
  unit tested against the Phase 0 corpus.
- Income/expense ledger, fast manual entry, edit, delete.
- Transaction list, dashboard, review queue, deduplication.
- Both capture routes wired, selectable in Settings.
- Share Sheet extension.
- Capture diagnostics.

### Phase 2 — Online account and sync

- Supabase Auth with Google and Apple.
- PostgreSQL schema and migrations.
- RLS policies and multi-user authorization tests.
- Sync outbox, retries, idempotent upserts, sync status.
- Data export and account deletion.
- **Siri voice entry** via a parameterised App Intent (D-20) — the only path
  that captures cash spending.

### Phase 3 — Release hardening

- Device and lifecycle testing across iOS versions.
- Privacy disclosures, App Store privacy questionnaire, 5.1.1(i) framing.
- Accessibility, localization, performance, migration testing.
- Parser regression suite expanded with real-world receipts.
- TestFlight beta and feedback iteration.

### Phase 4 — Android

- Reuse Flutter domain, data contracts, and most UI.
- Replace Vision with ML Kit on-device text recognition (also free).
- Implement an Android trigger (Quick Settings Tile, widget, or accessibility
  gesture) plus platform adapter.
- Define Android permissions and behavior separately; do not promise identical
  Back Tap behavior.

---

## 15. Remaining Open Decisions

All of v1.0's seven open decisions are resolved in §0. These remain:

1. Confirm D-13: IDR as default currency, Indonesian and English at launch?
2. Confirm D-14: the exact app list for the Phase 0 feasibility matrix.
3. Repository public (free macOS CI) or private (local iOS builds)?
4. Crash reporting: Sentry or Crashlytics?

Resolved since v3.1: minimum iOS version is **18.2** (D-22).

---

## 16. References

- Use Back Tap on your iPhone: https://support.apple.com/en-us/111772
- Shortcuts `Get Current App` property (iOS 18.2): https://macmost.com/using-the-new-current-app-shortcuts-property.html
- iOS 18 supported devices: https://support.apple.com/en-us/121033
- Back Tap actions (iPhone User Guide): https://support.apple.com/guide/iphone/back-tap-iphaa57e7885/ios
- Shortcuts Take Screenshot action (iOS 14.5): https://9to5mac.com/2021/02/16/ios-14-5-adds-new-shortcuts-actions-for-taking-screenshots-changing-orientation-lock-more/
- Apple Vision text recognition: https://developer.apple.com/documentation/vision/recognizing-text-in-images
- Apple App Intents: https://developer.apple.com/documentation/appintents
- App Intents file/image parameters: https://www.avanderlee.com/swiftui/app-intents-spotlight-integration-using-shortcuts/
- PhotoKit: https://developer.apple.com/documentation/photokit
- Apple Shortcuts User Guide: https://support.apple.com/guide/shortcuts/welcome/ios
- Sign in with Apple: https://developer.apple.com/sign-in-with-apple/
- App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Supabase Flutter quickstart: https://supabase.com/docs/guides/getting-started/quickstarts/flutter
- Supabase Row Level Security: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase social login (Google): https://supabase.com/docs/guides/auth/social-login/auth-google
- Supabase social login (Apple): https://supabase.com/docs/guides/auth/social-login/auth-apple
- Supabase pricing: https://supabase.com/pricing
- Drift: https://drift.simonbinder.eu
- GetX: https://pub.dev/packages/get
- FVM: https://fvm.app/documentation

---

**PRD status note:** v3.0 corrects the central technical premise of v1.0 and
v2.0. Those drafts treated "will third-party apps expose their receipt content
to Shortcuts?" as a product-killing risk. They need not have: the app
screenshots the rendered screen and reads it with on-device OCR, so no
cooperation from any payment provider is required. The residual risk is OCR
legibility and iOS screenshot-permission behavior — both bounded, both
testable in Phase 0, and both covered by a second capture route built for
exactly that reason.
