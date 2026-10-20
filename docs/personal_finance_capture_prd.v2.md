# Product Requirements Document (PRD)

## Soreva — Personal Finance Capture (iOS First, Flutter + Supabase)

**Document status:** Draft v2.0
**Date:** 20 October 2026
**Supersedes:** v1.0 (archived at `docs/personal_finance_capture_prd.v1.md`)
**Platforms:** iOS first; Android planned for a later phase
**Product approach:** Local-first, cloud-connected, single end-user application
**Distribution:** Free app, no monetization, no subscriptions

---

## 0. Decisions Locked in v2.0

v1.0 left seven open decisions and omitted three requirements the product
owner has since specified. This section records what is now settled. Items
marked *(proposed)* still need confirmation but have a stated default so
implementation is not blocked.

| # | Decision | Resolution |
|---|---|---|
| D-01 | Product core | Back Tap receipt capture **is** the product differentiator. Phase 0 feasibility is a hard gate on everything else. |
| D-02 | Data model | Income **and** expense in a single `transactions` table with a `direction` column. Single account for MVP; no wallets, no transfers. |
| D-03 | Auth gate | Sign-in **required** before recording. No guest mode. No local-to-cloud migration logic needed. |
| D-04 | Auth providers | **Google and Apple only.** No email/password, no magic links, no anonymous auth. |
| D-05 | Platforms | iOS first. Android is Phase 4. Non-mobile platform targets removed from the repo. |
| D-06 | State management | **GetX**, confined to the presentation layer (see §7.3). |
| D-07 | Architecture | Clean architecture, four layers, boundary enforced in CI (see §7.2, §7.4). |
| D-08 | Native capture storage | Swift writes to an **App Group inbox**; it does not share the SQLite database (see §7.5). This replaces v1.0 §6's shared-database requirement. |
| D-09 | Local database | **Drift** over SQLite. Viable because D-08 makes Dart the exclusive owner of the database. |
| D-10 | Uncertain captures | Saved as **drafts** with `review_status = 'needs_review'`, never rejected and never silently accepted. |
| D-11 | Cloud payload | Structured transaction fields only. No receipt images in MVP, no opt-in image backup until a later release. |
| D-12 | Money storage | `amount_minor` BIGINT plus an explicit per-currency scale. IDR scale is **0**. See §9.5. |
| D-13 | Default currency / locale | IDR; UI in Indonesian and English *(proposed)*. |
| D-14 | Phase 0 test apps | GoPay, OVO, DANA, ShopeePay, QRIS receipt screens, and one bank app (BCA or Livin) *(proposed)*. |
| D-15 | Flutter version | Pinned at bootstrap to a stable release satisfying Dart `^3.9.2` and the installed Xcode. Recorded in `.fvmrc`, not guessed here. See §6.1. |

---

## 1. Product Overview

### 1.1 Vision

Build a personal finance app that minimizes the effort required to record
spending. The primary experience is a user performing a transaction in
another app, reaching its payment receipt or success screen, and triggering
a capture workflow through iPhone Back Tap. When usable receipt content is
available, the app extracts transaction details, categorizes the expense,
detects its source, prevents duplicates, saves it locally, and synchronizes
it to the user's cloud account.

Income and manual corrections are recorded by hand. Capture is an expense
accelerator; the ledger is the system of record.

### 1.2 Problem

Manually recording every expense is inconvenient, so users often forget or
delay recording transactions. Existing expense trackers commonly require
users to open an app and enter the amount, merchant, category, date, and
time manually.

### 1.3 Product principles

- **Capture with minimal friction:** Back Tap is the preferred trigger after
  a payment.
- **Local-first reliability:** saving a valid transaction must not depend on
  an active internet connection.
- **One user-facing app:** native iOS components are packaged as part of the
  same app experience; users do not install a separate companion app.
- **Privacy by design:** process receipt content on-device whenever feasible
  and send only necessary structured transaction data to the cloud.
- **Honest automation:** never invent missing values or claim that every
  third-party app's screen can be read.
- **Cross-platform core:** keep financial rules and domain logic reusable for
  a future Android version.
- **Free forever:** no subscriptions, no ads, no paid tiers. Operating costs
  must stay within free service tiers (see §5.4).

---

## 2. Goals and Success Criteria

### 2.1 Goals

1. Allow users to initiate receipt capture from iOS Back Tap through Apple
   Shortcuts.
2. Extract transaction total, currency, merchant/source, category, and
   date/time when available.
3. Save transactions locally even when offline.
4. Synchronize user-owned transactions with Supabase when online.
5. Detect duplicate captures and avoid silently creating duplicate records.
6. Provide a dashboard, transaction history, category breakdown, and settings.
7. Record both income and expense in one ledger.
8. Authenticate exclusively through Google and Apple.
9. Use FVM to pin the Flutter SDK version for reproducible development.
10. Keep the architecture ready for Android without rebuilding the financial
    domain layer.
11. Keep the domain layer free of framework dependencies, enforced in CI.

### 2.2 MVP success criteria

- A valid capture is persisted locally before any network operation is
  attempted.
- Re-triggering the same capture does not create another transaction.
- A transaction created offline is queued and synchronized when connectivity
  returns.
- Each authenticated user can only read or mutate their own cloud records.
- If receipt content cannot be obtained or parsed reliably, the app reports a
  capture failure or saves a reviewable draft instead of fabricating a
  transaction.
- Core expense management and dashboard features work without a network
  connection after initial sign-in.
- A user can delete their account and all associated data from inside the app.

---

## 3. Target Users and Primary Use Case

### Primary user

A person who makes frequent digital payments and wants to maintain an expense
record without manually entering every transaction.

### Primary user journey

1. User pays in a third-party app.
2. User reaches the payment receipt or transaction-success screen.
3. User triggers Back Tap, configured to run an Apple Shortcut for expense
   capture.
4. The Shortcut passes supported screen content or an available item to the
   capture workflow.
5. Native iOS processing extracts text from supported text/image content and
   writes a capture record to the App Group inbox (§7.5).
6. On next app run, Dart drains the inbox: the parser identifies likely
   transaction fields and assigns confidence scores.
7. Validation and deduplication run.
8. A valid transaction is saved to local storage; an uncertain one is saved as
   a draft for review.
9. The transaction is queued for cloud sync.
10. The dashboard reflects the saved transaction.

### Fallback journey

If the source app does not provide usable screen content, the app must not
pretend the capture succeeded. It may offer a Share Sheet flow, a supported
image/text input, or manual entry as a fallback. The exact fallback UX will be
validated during the technical proof of concept.

---

## 4. Scope

### 4.1 MVP — In scope

- iOS application built with Flutter, FVM-managed and pinned.
- Swift-based native iOS integration for App Intents / Shortcuts.
- Back Tap setup guidance for the user.
- Receipt-content intake where iOS and the source app permit it.
- On-device OCR using Apple Vision for supported images.
- App Group inbox handoff from Swift to Dart.
- Receipt text parsing for total, currency, merchant, date, time, and
  reference ID where present — implemented in Dart.
- Expense category suggestion using deterministic rules.
- Local persistence via Drift over SQLite.
- Income and expense ledger, single account.
- Manual transaction entry and editing.
- Local transaction history and dashboard summaries.
- Duplicate detection and draft review queue.
- Supabase Auth restricted to Google and Apple providers.
- Supabase PostgreSQL cloud storage with Row Level Security.
- Local-first synchronization queue with retry and conflict handling.
- Account settings, sync status, sign-out, data export.
- **In-app account deletion** (App Store requirement, see §5.3).
- Clean-architecture layering with CI-enforced boundaries.

### 4.2 Out of scope for MVP

- Guaranteed extraction from every third-party app.
- Direct access to all notifications from other apps.
- Automatic access to private bank or e-wallet APIs.
- Background capture from arbitrary screen pixels.
- AI/LLM-based categorization requiring paid external APIs.
- Email/password or magic-link authentication.
- Guest or anonymous mode.
- Multiple accounts/wallets and transfers between them.
- Budgets, goals, and recurring transactions.
- Receipt image storage or upload.
- Shared household budgets or multi-user financial accounts.
- Subscription billing and monetization.
- Android capture implementation (Phase 4).
- Non-mobile platform targets (web, macOS, Linux, Windows).
- Financial advice, bank transfers, or initiating payments.

---

## 5. Platform and Technical Constraints

### 5.1 iOS capture constraints

- Back Tap is configured by the user in iOS Accessibility settings to run a
  Shortcut; the app must not assume it can listen to Back Tap directly.
- Shortcuts can only pass content available to the Shortcut workflow. The app
  cannot assume every third-party payment app exposes its receipt text or
  image.
- App Intents may run without showing the Flutter UI, but the exact execution
  behavior and available inputs must be validated on supported iOS versions
  and devices.
- The App Intent must not require an active Flutter/Dart engine. It writes to
  the App Group inbox and returns; see §7.5.
- App Intents run under a short execution budget. Keep native work to OCR and
  a file write — no parsing, no network, no database migrations.
- If receipt content is unavailable, ambiguous, or unsupported, the capture
  should fail safely or use a fallback.
- Test at minimum with the app foregrounded, backgrounded, and not previously
  open, subject to platform behavior.

### 5.2 OCR and extraction

- Use Apple Vision for on-device text recognition from supported image inputs.
- Vision produces **text only**. All interpretation happens in Dart.
- Parse receipt text with deterministic rules and locale-aware number/date
  handling.
- Identify likely total labels such as "Total", "Amount paid", "Grand total",
  and localized equivalents including "Jumlah", "Total Bayar", "Total
  Pembayaran".
- Do not treat subtotal, discount, tax, change, or balance as the final amount
  without sufficient evidence.
- Store extraction confidence and the source of each extracted field.
- If multiple possible totals exist and the correct total cannot be resolved,
  save the capture as a draft flagged ambiguous rather than silently saving an
  uncertain amount.

### 5.3 Authentication and App Store constraints

These follow directly from D-03 and D-04 and must be designed for, not
discovered at review time.

- **Guideline 4.8 — Sign in with Apple is mandatory.** Offering Google
  sign-in on iOS obliges the app to also offer Sign in with Apple. Both
  providers are required; neither is optional.
- **Guideline 5.1.1(v) — in-app account deletion is mandatory.** A documented
  policy is not sufficient; a working in-app flow is required. It must delete
  both the Supabase account and all cloud rows, and clear local data.
- **Guideline 5.1.1(i) — registration gating is a review risk.** The app is
  local-first and functions offline, so a reviewer may argue the mandatory
  sign-in wall is unjustified. Mitigation: onboarding must present cloud
  backup, recovery, and future multi-device access as the account-based
  functionality the sign-in enables, and that framing must be consistent in
  the App Store description.
- **Apple returns the user's full name only on the first authorization.** It
  must be persisted at that moment or it is lost permanently.
- **Apple users may hide their email behind a private relay address.** Email
  is therefore not a stable identity key. Key all ownership on the Supabase
  user UUID.
- Sign in with Apple requires an enrolled Apple Developer account; it cannot
  be developed or tested without one (see §5.4).
- Revoking the app's Apple credential outside the app must be handled
  gracefully on next launch.

### 5.4 Cost constraints

The app is free to users. It is not free to operate. This is stated plainly so
the plan is not built on a false assumption.

| Item | Cost | Notes |
|---|---|---|
| **Apple Developer Program** | **USD 99/year — unavoidable** | Required both for App Store distribution and to use Sign in with Apple at all. There is no free path to an iOS release. |
| Google Play Developer | USD 25 one-time | Phase 4 only. |
| Supabase | USD 0 (free tier) | Structured rows are small; the database ceiling is not the binding constraint. Free projects pause after a period of inactivity, and growth eventually forces the paid tier. **Verify current limits at bootstrap — they change.** |
| Google Sign-In / Google Cloud project | USD 0 | OAuth client and consent screen are free. |
| Flutter, Dart, FVM, GetX, Drift, Supabase SDK | USD 0 | All open source. |
| CI — GitHub Actions | USD 0 on public repos | macOS runners consume quota roughly 10x faster than Linux. A private repo will exhaust the free allowance quickly; keep the repo public or build iOS locally. |
| Crash reporting | USD 0 | Sentry free tier or Firebase Crashlytics. |

**Cost mitigation by design:** because the architecture is local-first, cloud
sync is a *feature*, not a dependency. If Supabase ever becomes a cost
problem, sync can be disabled or self-hosted and the app continues to work
completely. No design decision may violate this property.

### 5.5 Android readiness

- Keep domain models, category logic, deduplication rules, sync contracts, and
  repository interfaces in Dart.
- Keep Apple-specific code behind platform-specific adapters.
- Plan a later Android trigger such as a Quick Settings Tile or widget; do not
  assume Android can replicate iOS Back Tap behavior.

---

## 6. Technology Stack

| Area | Decision |
|---|---|
| App framework | Flutter |
| SDK management | FVM; exact version pinned in `.fvmrc` |
| Language | Dart |
| State management | GetX, presentation layer only (§7.3) |
| Dependency injection | GetX `Bindings`, presentation layer only |
| Routing | GetX named routes behind a navigation service |
| Native iOS integration | Swift |
| System shortcut integration | Apple Shortcuts + App Intents, subject to Phase 0 |
| OCR | Apple Vision, on-device, text extraction only |
| Native-to-Dart handoff | App Group inbox, JSON capture records (§7.5) |
| Local database | Drift over SQLite, owned exclusively by Dart |
| Cloud backend | Supabase |
| Authentication | Supabase Auth — Google and Apple providers only |
| Cloud database | Supabase PostgreSQL |
| Authorization | PostgreSQL Row Level Security on all user-data tables |
| Sync | Application-managed outbox; local write first, cloud sync second |
| Secure storage | Keychain via `flutter_secure_storage` for session tokens |
| Secrets | No service-role key or privileged backend secret in the app |
| CI/testing | Dart unit tests, domain-boundary lint, iOS build check |

### 6.1 FVM requirements

- Use FVM for all Flutter commands in the project.
- Pin an exact stable Flutter version in `.fvmrc` during bootstrap, selected by
  checking which current stable release satisfies the Dart constraint
  `^3.9.2` in `pubspec.yaml` and is compatible with the installed Xcode and
  the native iOS dependencies. Do not assume a version; verify with
  `fvm releases` and `fvm flutter doctor`.
- Commit `.fvmrc` and `pubspec.lock`.
- Document setup commands in `README.md`.
- Do not upgrade Flutter or major dependencies without running the test suite
  and validating the native iOS build.
- Setup workflow:
  - `fvm install <PINNED_VERSION>`
  - `fvm use <PINNED_VERSION>`
  - `fvm flutter doctor`
  - `fvm flutter pub get`
  - `fvm flutter test`

### 6.2 Repository hygiene

- Initialize git before any further work; the project is currently untracked.
- Remove the unused `web/`, `macos/`, `linux/`, and `windows/` platform
  directories generated by `flutter create` (D-05).
- Keep `.fvmrc`, `pubspec.lock`, and `analysis_options.yaml` committed.

---

## 7. Architecture

### 7.1 High-level flow

**Back Tap → Apple Shortcut → Swift App Intent → Apple Vision OCR → App Group
inbox**

**App launch / background refresh → Dart inbox drain → parser → validation →
deduplication → Drift local transaction → sync outbox → Supabase**

Flutter reads the local repository and renders the dashboard and history.
Cloud sync runs independently of UI rendering.

### 7.2 Layer structure

```
lib/
  core/            # Result/Failure types, env config, constants, utils
  domain/          # entities, repository INTERFACES, usecases, pure rules
                   #   -> zero framework imports. Enforced in CI (§7.4)
  data/            # DTOs, local (Drift) + remote (Supabase) datasources,
                   #   repository IMPLEMENTATIONS, mappers
  presentation/    # pages, widgets, GetxController, Bindings, view state
  app/             # routes, global bindings, theme, DI composition root
```

Dependency rule: `presentation -> domain <- data`. The domain layer depends on
nothing but `core` and the Dart SDK. Parsing, categorization, deduplication,
and money arithmetic all live in `domain` so they are unit-testable without a
device, a database, or a network.

### 7.3 GetX containment rules

GetX offers state management, dependency injection, routing, HTTP, and local
storage. Only the first three are adopted, and only in the presentation layer.
Unconstrained GetX usage dissolves the architecture into a service locator.

**Permitted:**
- `GetxController` subclasses in `presentation/`, holding view state.
- `Bindings` per route for lazily constructing controllers and injecting
  usecases.
- `Obx` / `GetBuilder` bound to presentation view-state objects.
- GetX named routes, invoked through a `NavigationService` interface so
  controllers remain testable without a widget tree.

**Forbidden:**
- `GetConnect` — networking belongs to `data/`, via the Supabase client.
- `GetStorage` — persistence belongs to `data/`, via Drift and Keychain.
- Any `import 'package:get/get.dart'` under `lib/domain/` or `lib/data/`.
- `Get.find()` inside entities, usecases, or repository implementations;
  dependencies are passed via constructors.
- Binding `Obx` directly to domain entities; map to view state first.

**Rationale and exit path:** GetX is less actively maintained than it once was
and the wider Flutter ecosystem has largely moved to Riverpod and Bloc. GetX
remains a productive choice, and it is the chosen one. Confining it to
`presentation/` means a future migration touches controllers and bindings only
— the domain, data, parsing, and sync layers would be untouched. This
containment is what keeps the decision cheap to reverse.

### 7.4 Boundary enforcement

The layer rule is enforced mechanically, because code review does not reliably
catch gradual drift. CI fails if either check matches:

```bash
# domain must not import any framework
! grep -rn --include='*.dart' -E \
  "package:(get|supabase_flutter|drift|sqflite|flutter)/" lib/domain/

# data must not import GetX or Flutter widgets
! grep -rn --include='*.dart' -E \
  "package:(get|flutter)/" lib/data/
```

`analysis_options.yaml` additionally enables strict analyzer settings and
treats analyzer warnings as build failures in CI.

### 7.5 Native capture handoff — App Group inbox

**This replaces v1.0's shared-SQLite requirement (D-08).**

v1.0 required both a Swift App Intent and the Flutter app to read and write
the same SQLite file through an App Group. That design has three costs: two
writers across two languages on one file, duplicated schema and migration
logic in Swift, and real multi-process locking and corruption exposure. It
also contradicted v1.0's own requirement that parsing and categorization stay
platform-independent Dart, since a Swift-only save path forces that logic into
Swift.

It was also unnecessary. v1.0 §3 step 10 already accepted that the dashboard
reflects a capture the next time the app UI opens — so no shared writable
database is needed.

**Design:**

1. The Swift App Intent receives Shortcut input, runs Apple Vision OCR, and
   writes exactly one immutable JSON capture record into the App Group
   container:

   ```
   <AppGroup>/inbox/<capture_attempt_uuid>.json
   {
     "capture_attempt_id": "<uuid>",
     "created_at": "<ISO8601>",
     "input_kind": "image" | "text",
     "raw_text": "<OCR output or passed text>",
     "ocr_engine": "vision",
     "ocr_block_confidences": [ ... ],
     "source_app_hint": "<bundle id or null>",
     "schema_version": 1
   }
   ```

2. Swift performs no parsing, no categorization, no deduplication, no
   database access, and no network calls. Writes are atomic (write to a temp
   name, then rename).
3. On launch, resume, and background refresh, Dart drains the inbox: parses,
   validates, deduplicates, persists via Drift, enqueues sync, then deletes
   the consumed file.
4. Draining is idempotent and keyed on `capture_attempt_id`, so a crash
   mid-drain cannot double-insert.
5. The inbox is the only shared surface between languages. The database has a
   single owner.

**Accepted trade-off:** a capture is not visible until the app next runs.
This was already the stated behavior.

### 7.6 Local-first transaction lifecycle

1. Capture record arrives in the inbox, or the user enters a transaction
   manually.
2. Normalize the source content; the `capture_attempt_id` is the idempotency
   key.
3. Extract candidate fields with confidence scores.
4. Validate required fields: a credible amount, a currency, and a direction.
5. Run exact and heuristic duplicate checks.
6. Save the transaction and its sync-outbox event in one local database
   transaction.
7. Update the local UI data source.
8. If online with a valid session, attempt sync.
9. Mark the outbox item synchronized only after server confirmation.
10. Retry transient failures with bounded exponential backoff; never create a
    second transaction on retry.

### 7.7 Cloud sync rules

- Local storage is the immediate source of truth for capture and UI feedback.
- Supabase is the account-backed cloud copy for recovery and future
  multi-device access.
- Every record has a stable client-generated UUID.
- Upserts use stable IDs and unique constraints so retries are idempotent.
- Track `updated_at`, sync state, and soft-delete/tombstone state.
- For MVP, transactions are append-oriented; user edits use version/timestamp
  rules and must not blindly overwrite newer server data.
- Structured transaction fields only; no receipt images (D-11).
- Network failure must never roll back a successfully saved local transaction.
- An expired session must never cause local data loss; queue and prompt for
  re-authentication.

---

## 8. Functional Requirements

### FR-01: Onboarding and setup

- Explain what Back Tap capture can and cannot do, honestly.
- Present cloud backup and recovery as the reason an account is required
  (§5.3, Guideline 5.1.1(i)).
- Guide the user through configuring Back Tap and the Shortcut.
- Explain that compatibility varies by source app.
- Allow users to test the capture flow with a sample receipt.

### FR-02: Authentication *(rewritten in v2.0)*

- Support **Google Sign-In and Sign in with Apple only**. No email/password,
  no magic links, no anonymous or guest mode (D-03, D-04).
- Both providers must be offered on iOS; Sign in with Apple is mandatory
  whenever Google sign-in is present (Guideline 4.8).
- Sign-in is required before any transaction can be recorded.
- Support sign-out and silent session restoration on launch.
- Persist the Apple-provided full name on first authorization only; it is
  never returned again.
- Treat email as non-identifying; Apple private-relay addresses are expected.
  All ownership keys on the Supabase user UUID.
- Handle externally revoked Apple credentials gracefully on next launch.
- Provide **in-app account deletion** that removes the Supabase account, all
  cloud rows, and all local data (Guideline 5.1.1(v)).
- Store session tokens in the Keychain.
- Never embed privileged Supabase service-role credentials in the app.

### FR-03: Receipt capture

- Receive only content passed through a supported iOS mechanism.
- Support text input and image input when available.
- Never present a capture as successful before it is saved locally.
- Provide a safe fallback when content is unavailable or parsing fails.
- Native side writes to the inbox only (§7.5).

### FR-04: Transaction extraction

Fields:
- Amount / total — required to auto-save
- Direction — expense or income; capture always yields expense
- Currency — required; may default from user settings but must be explicit in
  the stored record
- Merchant / payee — optional
- Source application — best-effort; store detection method and confidence
- Category — suggested, with an `Uncategorized` fallback
- Transaction date/time — optional when absent from the receipt
- Capture timestamp — always recorded
- Reference/receipt ID — optional
- Extraction confidence and review status

### FR-05: Categorization

- Begin with deterministic merchant/category mapping and keyword rules.
- Provide an `Uncategorized` category.
- Allow user edits to category.
- No external paid AI API (D-11, §5.4).
- Categorization logic lives in `domain/` and is platform-independent.

### FR-06: Duplicate prevention

Levels, in order:
1. Exact match on `capture_attempt_id`.
2. Exact match on source plus stable transaction/reference ID when available.
3. Exact normalized receipt fingerprint when one can be generated reliably.
4. Heuristic comparison of amount, currency, merchant, transaction time, and
   source.

A heuristic-only match is marked a **possible duplicate** for user review, never
auto-deleted — two legitimate purchases can look identical. Duplicate checks are
enforced locally and backed by server-side unique constraints where the data
supports them. Repeated sync attempts must be idempotent.

### FR-07: Local ledger management

- View a chronological transaction list covering income and expense.
- Record income and expense manually.
- View daily/monthly totals, net position, and category breakdowns.
- Search and filter by date, direction, category, merchant, and source.
- Edit and delete transactions.
- Review queue for drafts and possible duplicates (D-10).
- Reflect changes immediately without waiting for cloud sync.

### FR-08: Synchronization

- Show whether cloud sync is current, pending, or failed.
- Queue local writes while offline.
- Retry transient failures with bounded exponential backoff.
- Avoid duplicate cloud rows on retries.
- Handle expired sessions without losing local transactions.
- Provide a manual "Sync now" action.

### FR-09: Privacy and security

- TLS for all network communication.
- RLS enabled on every table containing user data.
- Policies restrict rows to the authenticated owner (`auth.uid()` matched to
  the row's owner ID).
- Least-privilege grants, with policies tested using multiple test users.
- Session tokens in the Keychain.
- Never log raw receipts, tokens, or full financial details in production.
- Collect only what the product functionally requires.
- Document and implement data export, data deletion, and account deletion
  before public release.
- Evaluate iOS Data Protection for local database files.
- App Group container holds only transient inbox records, deleted on consume.

---

## 9. Data Model

### 9.1 `profiles`

- `id` UUID, primary key, references the authenticated user
- `display_name` text nullable — populated from Apple's first-authorization
  name or Google profile
- `default_currency` text
- `created_at`, `updated_at` timestamps

### 9.2 `categories`

- `id` UUID, primary key
- `owner_id` UUID nullable for built-in categories
- `name` text
- `direction` text — `expense`, `income`, or `both`
- `icon_key`, `color_key` text nullable
- `is_system` boolean
- `created_at` timestamp

### 9.3 `transactions` *(renamed from `expenses` in v2.0 — D-02)*

- `id` UUID, primary key, generated client-side
- `owner_id` UUID, required
- `direction` text, required — `expense` or `income`
- `amount_minor` BIGINT, required — see §9.5
- `currency` text, required
- `currency_scale` smallint, required — frozen at write time
- `merchant_name` text nullable
- `source_app_id`, `source_app_name` text nullable
- `category_id` UUID nullable
- `transaction_at` timestamp nullable
- `captured_at` timestamp, required
- `entry_method` text — `capture`, `manual`, `fallback`
- `capture_attempt_id` UUID nullable — idempotency key for captured rows
- `reference_id` text nullable
- `receipt_fingerprint` text nullable
- `extraction_confidence` numeric nullable
- `review_status` text — `confirmed`, `needs_review`, `possible_duplicate`
- `created_at`, `updated_at` timestamps
- `deleted_at` timestamp nullable

### 9.4 `sync_outbox` (local database only)

- `id` UUID, primary key
- `entity_type`, `entity_id`, `operation` text/UUID
- `payload_version` integer
- `created_at` timestamp
- `attempt_count` integer
- `last_attempt_at` timestamp nullable
- `last_error_code` text nullable
- `sync_status` text

### 9.5 Money representation (D-12)

- Store amounts as `amount_minor` BIGINT together with an explicit
  `currency_scale`. The real value is `amount_minor / 10^currency_scale`.
- **IDR uses scale 0.** The sen subunit is obsolete in practice; treating IDR
  as two-decimal would introduce a silent 100x error.
- USD, EUR, and similar use scale 2.
- BIGINT is required, not INTEGER: IDR amounts are large and a 32-bit column
  overflows at roughly 2.1 billion.
- `currency_scale` is stored per row, not looked up at read time, so historical
  rows stay correct if a scale table is ever corrected.
- All money arithmetic lives in a `domain/` value object. No floating point
  anywhere in the money path.

### 9.6 Data-model notes

- Never use amount plus date alone as a unique key; two legitimate purchases
  can share both.
- Receipt image retention is out of MVP scope.
- Index on `owner_id`, `transaction_at`, `category_id`, `capture_attempt_id`
  (unique where not null), and sync-related columns.
- Cloud tables carry RLS; the local Drift schema mirrors them minus `owner_id`
  enforcement, which is implicit in a single-user local database.

---

## 10. Non-Functional Requirements

### Reliability

- Local save is atomic.
- The capture flow does not require network availability.
- Inbox draining is idempotent and crash-safe.
- Sync retries do not create duplicates.
- Database migrations preserve existing local data; every migration has a test.

### Performance

- The App Intent completes within the iOS execution budget — OCR plus one file
  write.
- Typical local save completes quickly after parsing and validation.
- OCR runs on-device.
- Heavy OCR, parsing, and network work must not block the Flutter UI thread.
- Dashboard summaries are computed efficiently from local data, with
  aggregation pushed into SQL rather than Dart loops.

### Security and privacy

- Strong per-user isolation in the cloud, verified with multi-user tests.
- No privileged cloud keys in client code.
- Minimal collection and transmission of receipt content.
- Clear user-facing explanation of what is captured and synchronized.

### Maintainability

- Flutter SDK pinned with FVM.
- Four-layer separation with CI-enforced boundaries (§7.4).
- Platform-specific code behind interfaces.
- Tests for parsing, categorization, deduplication, money arithmetic, sync
  retries, migrations, and RLS authorization.
- GetX confined to presentation so it remains replaceable (§7.3).

### Accessibility and localization

- Support accessible text sizes and screen-reader labels.
- Data model designed for localized dates, number formats, and currency
  formatting.
- Indonesian and English at launch *(D-13, proposed)*.

---

## 11. MVP Screens

1. **Onboarding** — product explanation, honest capability disclosure, privacy
   disclosure, account rationale, Back Tap/Shortcut setup guide.
2. **Authentication** — Google and Apple buttons only.
3. **Dashboard** — spending today/month, income/net summary, category
   breakdown, recent transactions, sync status.
4. **Transaction history** — searchable and filterable list.
5. **Transaction detail/edit** — amount, direction, merchant, category,
   date/time, source, review status.
6. **Review queue** — drafts and possible duplicates awaiting confirmation.
7. **Manual entry** — income and expense.
8. **Capture diagnostics** — last capture result, failure reason, fallback
   guidance.
9. **Settings** — account, default currency, categories, data export, sync
   status, privacy, sign-out, **delete account**.

The capture workflow must not open the Flutter UI when the native action can
process the input and write to the inbox.

---

## 12. Acceptance Criteria

**Project setup**
- [ ] Repository is under git version control.
- [ ] Project uses FVM and commits `.fvmrc` plus `pubspec.lock`.
- [ ] Unused platform directories removed.
- [ ] iOS app builds with the pinned Flutter SDK and selected Xcode.

**Architecture**
- [ ] `lib/` follows the four-layer structure in §7.2.
- [ ] CI fails on any framework import under `lib/domain/` (§7.4).
- [ ] CI fails on any GetX or Flutter import under `lib/data/`.
- [ ] No `GetConnect` or `GetStorage` usage anywhere.
- [ ] Parsing, categorization, deduplication, and money arithmetic are unit
      tested with no device, database, or network.

**Capture**
- [ ] A Shortcut can invoke the supported capture action on the tested iOS
      version.
- [ ] The App Intent writes a valid inbox record without a running Dart engine.
- [ ] Inbox draining is idempotent across a simulated mid-drain crash.
- [ ] Capture does not assume all third-party apps expose screen content.
- [ ] Supported receipt input yields parsed candidates for amount, merchant,
      category, date/time, and source where available.
- [ ] Missing or ambiguous values produce a reviewable draft, never a
      fabricated transaction.
- [ ] Repeating the same capture does not create a second transaction.
- [ ] Fallback behavior is documented and tested for unsupported source apps.

**Ledger and sync**
- [ ] A valid transaction is saved locally while the device is offline.
- [ ] Income and expense can both be recorded and are distinguished in totals.
- [ ] An IDR amount round-trips through local and cloud storage with no scale
      error.
- [ ] Local list and dashboard update immediately after a successful save.
- [ ] Reconnection synchronizes pending transactions without duplication.
- [ ] An expired session loses no local data.

**Auth, privacy, compliance**
- [ ] Google Sign-In and Sign in with Apple both work on a real device.
- [ ] No email/password or anonymous auth path exists.
- [ ] Apple's first-authorization name is persisted; a second sign-in does not
      overwrite it with null.
- [ ] An Apple private-relay email does not break identity or sync.
- [ ] Two different users cannot access each other's cloud transactions, as
      verified by a multi-user RLS test.
- [ ] In-app account deletion removes the Supabase account, all cloud rows,
      and all local data.
- [ ] Data export produces a complete, re-importable file.
- [ ] No service-role key or privileged secret is present in the built app.

---

## 13. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Third-party apps do not expose receipt content to Shortcuts | **Core capture cannot work — product thesis fails** | Phase 0 is a hard gate with a timebox and an explicit pivot criterion (§14). Share Sheet and manual fallback are built regardless. |
| OCR confuses total with subtotal or other amounts | Incorrect financial records | Confidence scoring, deterministic parsing in Dart, draft-on-ambiguity, user correction |
| Source app cannot be identified reliably | Incorrect source metadata | Treat detection as best-effort; store unknown when uncertain |
| Duplicate capture or sync retry | Inflated spending totals | `capture_attempt_id` idempotency, stable IDs, unique constraints, fingerprinting, idempotent upserts |
| App Intent runs with limited time or inputs | Capture fails in some states | Native work limited to OCR plus one atomic file write; test all app lifecycle states and OS versions |
| Local and cloud data diverge | Inconsistent history | Durable outbox, explicit conflict policy, sync status, retry handling |
| Misconfigured RLS | **Financial data exposure** | RLS on every exposed table, tested with multiple users as a CI check |
| IDR scale assumed to be 2 decimals | Silent 100x money error | Explicit per-row `currency_scale`, IDR scale 0, round-trip test in acceptance criteria |
| Sign-in wall rejected under Guideline 5.1.1(i) | App Store rejection | Frame account as enabling backup and recovery in onboarding and store listing (§5.3) |
| Missing in-app account deletion | App Store rejection | Build the flow in MVP, not post-launch |
| Apple name captured only once, then lost | Permanently blank display names | Persist on first authorization; covered by an acceptance criterion |
| Supabase free tier outgrown | Unexpected operating cost | Local-first means sync is optional; app degrades to offline-only rather than breaking |
| GetX maintenance decline | Future migration cost | GetX confined to `presentation/`; domain and data layers unaffected by a swap (§7.3) |
| Flutter/native dependency incompatibility | Build instability | Pin SDK with FVM; validate package and Xcode compatibility before upgrades |

---

## 14. Delivery Plan

### Phase 0 — Technical feasibility (hard gate)

Because capture is the product (D-01), this phase decides whether the product
as conceived exists. **Timebox: 2 weeks.**

- Initialize git, FVM, and the pinned Flutter version.
- Create the four-layer skeleton and the CI boundary check.
- Verify a Back Tap → Shortcut flow on a real iPhone.
- Determine what input content can be passed from the D-14 app list.
- Prototype App Intent execution with no Flutter UI and no Dart engine.
- Run Apple Vision OCR on representative Indonesian receipt screens.
- Validate the App Group inbox write and Dart drain, including crash
  idempotency.

**Exit criterion:** at least one reliable supported capture path is
demonstrated end to end, and unsupported cases are documented.

**Pivot criterion:** if no representative app yields usable content within the
timebox, the product reframes around Share Sheet plus fast manual entry, and
this PRD is revised before Phase 1 begins. Do not build Phase 1 on an
unvalidated capture path.

**Note:** Phase 0 requires the Apple Developer account (§5.4), because Sign in
with Apple and App Intents on-device testing both depend on it.

### Phase 1 — Local MVP

- Onboarding and setup guide.
- Drift data layer, schema, and migration tests.
- Receipt parsing and categorization rules in `domain/`, fully unit tested.
- Income/expense ledger, manual entry, edit, delete.
- Transaction list, dashboard, review queue, deduplication.
- Capture failure diagnostics and fallback path.

### Phase 2 — Online account and sync

- Supabase Auth with Google and Apple.
- PostgreSQL schema and migrations.
- RLS policies and multi-user authorization tests.
- Sync outbox, retries, idempotent upserts, sync status.
- Data export, account deletion.

### Phase 3 — Release hardening

- Device and lifecycle testing.
- Privacy disclosures and App Store requirements, including the 5.1.1(i)
  framing.
- Accessibility, localization, performance, and migration testing.
- TestFlight beta and feedback iteration.

### Phase 4 — Android

- Reuse Flutter domain, data contracts, and most UI.
- Implement an Android-native capture trigger and platform adapter.
- Define Android-specific permissions and behavior separately; do not promise
  identical Back Tap behavior.

---

## 15. Remaining Open Decisions

All seven of v1.0's open decisions are resolved in §0. These remain:

1. Confirm D-13: is IDR the default currency, and are Indonesian and English
   the launch languages?
2. Confirm D-14: which specific payment apps and bank apps go into the Phase 0
   feasibility matrix?
3. Is the repository public (free macOS CI) or private (local iOS builds)?
4. Crash reporting: Sentry or Crashlytics?
5. Is the Apple Developer Program enrollment already in place, or does Phase 0
   need to start with it?

---

## 16. References

- Supabase Flutter quickstart: https://supabase.com/docs/guides/getting-started/quickstarts/flutter
- Supabase Row Level Security: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase social login — Google: https://supabase.com/docs/guides/auth/social-login/auth-google
- Supabase social login — Apple: https://supabase.com/docs/guides/auth/social-login/auth-apple
- Supabase pricing and free-tier limits: https://supabase.com/pricing
- Drift documentation: https://drift.simonbinder.eu
- GetX package: https://pub.dev/packages/get
- FVM project/version management: https://fvm.app/documentation
- Apple App Intents: https://developer.apple.com/documentation/appintents
- Apple Shortcuts User Guide: https://support.apple.com/guide/shortcuts/welcome/ios
- Sign in with Apple: https://developer.apple.com/sign-in-with-apple/
- App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple Developer Program enrollment: https://developer.apple.com/programs/
- Flutter database selection guide: https://docs.flutter.dev/data-and-backend/persistence/choose-a-database

---

**PRD status note:** This document defines the intended product and proposed
architecture. The cross-app receipt-content handoff through Back Tap and
Shortcuts is a feasibility risk, not a guaranteed iOS capability. Because
capture is the product thesis (D-01), Phase 0 is a hard gate with an explicit
pivot criterion, and no Phase 1 work should begin until it passes.
