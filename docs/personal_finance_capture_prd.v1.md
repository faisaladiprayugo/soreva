# Product Requirements Document (PRD)

## Personal Finance Capture --- iOS First, Flutter + Supabase

**Document status:** Draft v1.0\
**Date:** 20 October 2026\
**Platforms:** iOS first; Android planned for a later phase\
**Product approach:** Local-first, cloud-connected, single end-user
application

------------------------------------------------------------------------

## 1. Product Overview

### 1.1 Vision

Build a personal finance app that minimizes the effort required to
record spending. The primary experience is a user performing a
transaction in another app, reaching its payment receipt or success
screen, and triggering a capture workflow through iPhone Back Tap. When
usable receipt content is available, the app extracts transaction
details, categorizes the expense, detects its source, prevents
duplicates, saves it locally, and synchronizes it to the user's cloud
account.

### 1.2 Problem

Manually recording every expense is inconvenient, so users often forget
or delay recording transactions. Existing expense trackers commonly
require users to open an app and enter the amount, merchant, category,
date, and time manually.

### 1.3 Product principles

-   **Capture with minimal friction:** Back Tap is the preferred trigger
    after a payment.
-   **Local-first reliability:** saving a valid transaction must not
    depend on an active internet connection.
-   **One user-facing app:** native iOS components are packaged as part
    of the same app experience; users do not install a separate
    companion app.
-   **Privacy by design:** process receipt content on-device whenever
    feasible and send only necessary structured transaction data to the
    cloud.
-   **Honest automation:** never invent missing values or claim that
    every third-party app's screen can be read.
-   **Cross-platform core:** keep financial rules and domain logic
    reusable for a future Android version.

## 2. Goals and Success Criteria

### 2.1 Goals

1.  Allow users to initiate receipt capture from iOS Back Tap through
    Apple Shortcuts.
2.  Extract transaction total, currency, merchant/source, expense
    category, and transaction date/time when available.
3.  Save transactions locally even when offline.
4.  Synchronize user-owned transactions with Supabase when online.
5.  Detect duplicate captures and avoid silently creating duplicate
    expense records.
6.  Provide a simple dashboard, transaction history, category breakdown,
    and settings.
7.  Use FVM to pin the Flutter SDK version for reproducible development.
8.  Keep the architecture ready for a future Android implementation
    without rebuilding the financial domain layer.

### 2.2 MVP success criteria

-   A valid capture is persisted locally before any network operation is
    attempted.
-   Re-triggering the same capture does not create another transaction.
-   A transaction created offline is queued and synchronized when
    connectivity returns.
-   Each authenticated user can only read or mutate their own cloud
    transaction records.
-   If receipt content cannot be obtained or parsed reliably, the app
    reports a capture failure or requests a fallback instead of
    fabricating a transaction.
-   Core expense management and dashboard features work without a
    network connection after initial setup.

## 3. Target Users and Primary Use Case

### Primary user

A person who makes frequent digital payments and wants to maintain an
expense record without manually entering every transaction.

### Primary user journey

1.  User pays in a third-party app.
2.  User reaches the payment receipt or transaction-success screen.
3.  User triggers Back Tap, configured to run an Apple Shortcut for
    expense capture.
4.  The Shortcut passes supported screen content or an available item to
    the capture workflow.
5.  Native iOS processing extracts text from supported text/image
    content.
6.  The parser identifies likely transaction fields and assigns
    confidence scores.
7.  Validation and deduplication run.
8.  A valid transaction is saved to local storage.
9.  The transaction is queued for cloud sync.
10. The dashboard reflects the saved transaction the next time the app
    UI is open.

### Fallback journey

If the source app does not provide usable screen content, the app must
not pretend the capture succeeded. It may offer a Share Sheet flow, a
supported image/text input, or manual entry as a fallback. The exact
fallback UX will be validated during the technical proof of concept.

## 4. Scope

### 4.1 MVP --- In scope

-   iOS application built with Flutter.
-   FVM-managed and pinned Flutter SDK.
-   Swift-based native iOS integration for App Intents / Shortcuts.
-   Back Tap setup guidance for the user.
-   Receipt-content intake where iOS and the source app permit it.
-   On-device OCR using Apple Vision for supported images.
-   Receipt text parsing for total, currency, merchant, date, time, and
    reference ID where present.
-   Expense category suggestion using deterministic rules initially.
-   Local SQLite persistence.
-   Local transaction history and dashboard summaries.
-   Duplicate detection.
-   Supabase authentication.
-   Supabase PostgreSQL cloud storage and user-specific access policies.
-   Local-first synchronization queue with retry and conflict handling.
-   Basic account settings, sync status, and sign-out.
-   Export/import or another documented recovery mechanism to reduce
    local-data-loss risk.

### 4.2 Out of scope for MVP

-   Guaranteed extraction from every third-party app.
-   Direct access to all notifications from other apps.
-   Automatic access to private bank or e-wallet APIs without supported
    integrations.
-   Background capture from arbitrary screen pixels without an allowed
    system-provided input.
-   AI/LLM-based categorization requiring paid external APIs.
-   Shared household budgets or multi-user financial accounts.
-   Subscription billing and monetization.
-   Full Android capture implementation (planned future phase).
-   Financial advice, bank transfers, or initiating payments.

## 5. Platform and Technical Constraints

### 5.1 iOS capture constraints

-   Back Tap is configured by the user in iOS Accessibility settings to
    run a Shortcut; the app must not assume it can listen to Back Tap
    directly.
-   Shortcuts can only pass content that is available to the Shortcut
    workflow. The app cannot assume every third-party payment app
    exposes its receipt text or image.
-   App Intents may run without showing the Flutter UI, but the exact
    execution behavior and available inputs must be validated on
    supported iOS versions and devices.
-   The app must not rely on an active Flutter/Dart engine for a native
    App Intent to save a transaction.
-   If the receipt content is unavailable, ambiguous, or unsupported,
    the capture should fail safely or use a fallback.
-   Test at minimum with the app foregrounded, backgrounded, and not
    previously open, subject to platform behavior.

### 5.2 OCR and extraction

-   Use Apple Vision for on-device text recognition from supported image
    inputs.
-   Parse receipt text with deterministic rules and locale-aware
    number/date handling.
-   Identify likely total labels such as "Total", "Amount paid", "Grand
    total", and common localized equivalents.
-   Do not treat subtotal, discount, tax, change, or balance as the
    final amount without sufficient evidence.
-   Store extraction confidence and the source of each extracted field
    where practical.
-   If multiple possible totals exist and the correct total cannot be
    resolved, flag the capture as ambiguous rather than silently saving
    an uncertain amount.

### 5.3 Android readiness

-   Keep domain models, category logic, deduplication rules, sync
    contracts, and repository interfaces in Dart where feasible.
-   Keep Apple-specific code behind platform-specific adapters.
-   Plan a later Android trigger such as a Quick Settings Tile or
    widget; do not assume Android can use iOS Back Tap behavior.

## 6. Technology Stack

  -----------------------------------------------------------------------
  Area                                Decision
  ----------------------------------- -----------------------------------
  App framework                       Flutter

  SDK management                      FVM; pin exact Flutter version in
                                      `.fvmrc`

  Language                            Dart

  Native iOS integration              Swift

  System shortcut integration         Apple Shortcuts + App Intents,
                                      subject to proof of concept

  OCR                                 Apple Vision, on-device

  Local database                      SQLite, accessed through a
                                      Dart/native-compatible repository
                                      design

  Shared app/extension storage        App Groups if a separate native
                                      extension/target requires shared
                                      files

  Cloud backend                       Supabase

  Authentication                      Supabase Auth

  Cloud database                      Supabase PostgreSQL

  Authorization                       PostgreSQL Row Level Security (RLS)
                                      on all exposed user data tables

  Sync                                Application-managed outbox/queue;
                                      local write first, cloud sync
                                      second

  Secrets                             No service-role key or privileged
                                      backend secret embedded in the
                                      mobile app

  CI/testing                          Add automated Dart tests and iOS
                                      integration checks as the project
                                      matures
  -----------------------------------------------------------------------

### 6.1 FVM requirements

-   Use FVM for all Flutter commands in the project.
-   Pin an exact stable Flutter version in `.fvmrc` during project
    bootstrap after confirming compatibility with required iOS
    dependencies.
-   Commit `.fvmrc` and `pubspec.lock`.
-   Document setup commands in `README.md`.
-   Do not upgrade Flutter or major dependencies without running the
    test suite and validating the native iOS build.
-   Example setup workflow (replace `<PINNED_VERSION>` with the version
    selected during bootstrap):
    -   `fvm install <PINNED_VERSION>`
    -   `fvm use <PINNED_VERSION>`
    -   `fvm flutter doctor`
    -   `fvm flutter pub get`
    -   `fvm flutter test`

## 7. Architecture

### 7.1 High-level flow

**Back Tap → Apple Shortcut → Native App Intent / capture adapter →
input validation → OCR/parser → deduplication → SQLite local transaction
→ sync outbox → Supabase**

Flutter reads the local repository and renders the dashboard/history.
Cloud sync runs independently of UI rendering.

### 7.2 Local-first transaction lifecycle

1.  Capture input arrives from a supported Shortcut path.
2.  Normalize the source content and generate a capture-attempt ID.
3.  Extract candidate fields and confidence.
4.  Validate required fields (at minimum a credible amount and
    currency).
5.  Run exact and heuristic duplicate checks.
6.  Save the transaction and sync-outbox event in one local database
    transaction.
7.  Update the local UI data source.
8.  If authenticated and online, attempt sync.
9.  Mark the outbox item as synchronized only after server confirmation.
10. Retry transient failures with backoff; do not create a second
    transaction on retry.

### 7.3 Cloud sync rules

-   Local storage is the immediate source of truth for capture and
    immediate UI feedback.
-   Supabase is the account-backed cloud copy for recovery and future
    multi-device access.
-   Every record has a stable UUID generated on the client.
-   Upserts use stable IDs and appropriate unique constraints to make
    retries idempotent.
-   Track `updated_at`, sync state, and soft-delete/tombstone state
    where needed.
-   Define conflict rules explicitly. For MVP, transactions should
    generally be append-oriented; user edits use version/timestamp rules
    and must not overwrite newer server data blindly.
-   Do not upload raw receipt images by default. Upload structured
    transaction fields only unless the user explicitly opts into a
    receipt-storage feature in a later release.
-   Network failure must not roll back a successfully saved local
    transaction.

## 8. Functional Requirements

### FR-01: Onboarding and setup

-   Explain what Back Tap capture can and cannot do.
-   Guide the user through configuring Back Tap and the Shortcut.
-   Explain that compatibility varies by source app.
-   Allow users to test the capture flow with a sample receipt or
    supported input.

### FR-02: Authentication

-   Support account creation, sign-in, sign-out, and session restoration
    through Supabase Auth.
-   Users can use local functionality according to the product's chosen
    guest/account policy.
-   Define account-linking and local-data migration behavior before
    enabling guest-to-account sync.
-   Never expose privileged Supabase service-role credentials in the
    app.

### FR-03: Receipt capture

-   Receive only content passed through a supported iOS mechanism.
-   Support text input and image input when available.
-   Avoid presenting the capture as successful until the transaction has
    been saved locally.
-   Provide a safe fallback when content is unavailable or parsing
    fails.

### FR-04: Transaction extraction

Fields: - Amount / total (required to auto-save) - Currency (required;
default currency may be suggested based on user settings but must be
explicit in the stored record) - Merchant / payee (optional if not
detected) - Source application (best-effort; store detection
method/confidence) - Category (suggested, with an "Uncategorized"
fallback) - Transaction date/time (optional when absent from receipt) -
Capture timestamp (always recorded) - Reference/receipt ID (optional) -
Extraction confidence and review status

### FR-05: Categorization

-   Begin with a deterministic merchant/category mapping and keyword
    rules.
-   Provide an "Uncategorized" category.
-   Allow user edits to category.
-   Do not require an external paid AI API for MVP.
-   Keep categorization logic platform-independent.

### FR-06: Duplicate prevention

Use multiple levels: 1. Exact match on source + stable
transaction/reference ID when available. 2. Exact normalized receipt
fingerprint when a reliable fingerprint can be generated. 3. Heuristic
comparison of amount, currency, merchant, transaction time, and source.
4. If only a heuristic match exists, mark as a possible duplicate rather
than automatically deleting a potentially legitimate second purchase.

Duplicate checks must be enforced locally and supported by server-side
unique constraints where the data supports them. Repeated sync attempts
must be idempotent.

### FR-07: Local expense management

-   View a chronological transaction list.
-   View daily/monthly totals and category breakdowns.
-   Search and filter by date, category, merchant, and source.
-   Edit and delete transactions.
-   Reflect changes immediately without waiting for cloud sync.

### FR-08: Synchronization

-   Show whether cloud sync is current, pending, or failed.
-   Queue local writes while offline.
-   Retry transient failures with bounded exponential backoff.
-   Avoid duplicate cloud rows on retries.
-   Handle expired sessions without losing local transactions.
-   Provide a manual "Sync now" action for troubleshooting.

### FR-09: Privacy and security

-   Use TLS for network communication.
-   Enable RLS for every exposed table containing user data.
-   Policy must restrict rows to the authenticated owner (`auth.uid()`
    matched to the row's owner ID).
-   Use least-privilege grants and test policies.
-   Keep session tokens in platform-appropriate secure storage.
-   Do not log raw receipts, tokens, or full financial details in
    production logs.
-   Collect only data required for product functionality.
-   Document data deletion, account deletion, and export behavior before
    public release.
-   Evaluate iOS Data Protection for local files and Keychain for
    sensitive secrets.
-   If a native App Intent/extension needs shared data, configure App
    Groups and test concurrent database access.

## 9. Data Model (Initial Proposal)

### `profiles`

-   `id` UUID, primary key, references authenticated user
-   `display_name` nullable
-   `default_currency` text
-   `created_at` timestamp
-   `updated_at` timestamp

### `categories`

-   `id` UUID, primary key
-   `owner_id` UUID nullable for built-in categories
-   `name` text
-   `icon_key` text nullable
-   `color_key` text nullable
-   `is_system` boolean
-   `created_at` timestamp

### `expenses`

-   `id` UUID, primary key, generated client-side
-   `owner_id` UUID, required
-   `amount_minor` integer/bigint, required; document the currency scale
    convention
-   `currency` text, required
-   `merchant_name` text nullable
-   `source_app_id` text nullable
-   `source_app_name` text nullable
-   `category_id` UUID nullable
-   `transaction_at` timestamp nullable
-   `captured_at` timestamp, required
-   `reference_id` text nullable
-   `receipt_fingerprint` text nullable
-   `extraction_confidence` numeric nullable
-   `review_status` text
-   `created_at` timestamp
-   `updated_at` timestamp
-   `deleted_at` timestamp nullable

### `sync_outbox` (local database only)

-   `id` UUID, primary key
-   `entity_type` text
-   `entity_id` UUID
-   `operation` text
-   `payload_version` integer
-   `created_at` timestamp
-   `attempt_count` integer
-   `last_attempt_at` timestamp nullable
-   `last_error_code` text nullable
-   `sync_status` text

### Data-model notes

-   Store money in integer minor units according to a documented
    currency-specific scale. For IDR, define and test the chosen
    convention explicitly rather than assuming every currency uses two
    decimal places.
-   Do not use amount + date alone as a unique key; two legitimate
    purchases can share these fields.
-   Keep receipt image retention out of the MVP by default.
-   Add indexes for owner, transaction date, category, and sync-related
    queries.

## 10. Non-Functional Requirements

### Reliability

-   Local save is atomic.
-   The capture flow does not require network availability.
-   Sync retries do not create duplicates.
-   Database migrations preserve existing local data.

### Performance

-   Typical local transaction save should complete quickly after parsing
    and validation.
-   OCR should run on-device for supported images.
-   Heavy OCR and network work must not block the Flutter UI thread.
-   Dashboard summaries should be computed efficiently from local data.

### Security and privacy

-   Strong per-user isolation in the cloud.
-   No privileged cloud keys in client code.
-   Minimize collection and transmission of receipt content.
-   Clear user-facing explanation of what is captured and synchronized.

### Maintainability

-   Pin Flutter SDK with FVM.
-   Separate domain, data, presentation, and platform-integration
    layers.
-   Keep platform-specific code behind interfaces.
-   Add tests for parsing, deduplication, sync retries, and
    authorization.

### Accessibility and localization

-   Support accessible text sizes and screen-reader labels.
-   Design the data model for localized dates, number formats, and
    currency formatting.
-   Initial UI language and supported locales must be confirmed before
    release.

## 11. MVP Screens

1.  **Onboarding:** product explanation, privacy disclosure, Back
    Tap/Shortcut setup guide.
2.  **Dashboard:** total spending today/month, category summary, recent
    transactions, sync status.
3.  **Transaction history:** searchable/filterable list.
4.  **Transaction detail/edit:** amount, merchant, category, date/time,
    source, review status.
5.  **Capture diagnostics:** last capture result, failure reason, and
    fallback guidance.
6.  **Settings:** account, default currency, categories, data export,
    sync status, privacy, sign-out.
7.  **Authentication:** sign-in and account creation, if
    account-required mode is selected.

The capture workflow should avoid opening the full Flutter UI when the
native background action can successfully process and save the input.

## 12. Acceptance Criteria

-   [ ] Project uses FVM and commits `.fvmrc` plus `pubspec.lock`.
-   [ ] iOS app builds with the pinned Flutter SDK and selected Xcode
    environment.
-   [ ] A Shortcut can invoke the supported capture action on the tested
    iOS version.
-   [ ] Capture does not assume that all third-party apps expose screen
    content.
-   [ ] Supported receipt input yields parsed candidates for amount,
    merchant, category, date/time, and source where available.
-   [ ] Missing or ambiguous required values do not result in fabricated
    transactions.
-   [ ] A valid transaction is saved locally while the device is
    offline.
-   [ ] Repeating the same capture does not create a second transaction.
-   [ ] Reconnection synchronizes pending transactions without
    duplication.
-   [ ] Two different users cannot access each other's cloud
    transactions.
-   [ ] Local transaction list and dashboard update immediately after a
    successful save.
-   [ ] OCR/parser and deduplication logic have automated tests.
-   [ ] Fallback behavior is documented and tested for unsupported
    source apps.

## 13. Risks and Mitigations

  -----------------------------------------------------------------------
  Risk                    Impact                  Mitigation
  ----------------------- ----------------------- -----------------------
  Third-party apps do not Core capture cannot     Build a proof of
  expose receipt content  work consistently       concept with
  to Shortcuts            across all apps         representative apps
                                                  before committing to
                                                  universal support; add
                                                  Share Sheet/manual
                                                  fallback

  OCR confuses total with Incorrect financial     Confidence scoring,
  subtotal or other       records                 deterministic parsing,
  amounts                                         ambiguity handling,
                                                  user correction

  Source app cannot be    Incorrect source        Treat source detection
  identified reliably     metadata                as best-effort and
                                                  store unknown when
                                                  uncertain

  Duplicate capture or    Inflated spending       Stable IDs, unique
  sync retry              totals                  constraints, local
                                                  fingerprinting,
                                                  idempotent upserts

  App Intent runs with    Capture may fail in     Keep processing short,
  limited time or inputs  some states             use native code, test
                                                  app lifecycle states
                                                  and OS versions

  Local and cloud data    Inconsistent history    Durable outbox,
  diverge                 across devices          explicit conflict
                                                  policy, sync status,
                                                  retry handling

  Misconfigured RLS       Financial data exposure Enable RLS on exposed
                                                  user-data tables and
                                                  test policies with
                                                  multiple test users

  Flutter/native          Build instability       Pin SDK with FVM;
  dependency                                      validate package and
  incompatibility                                 Xcode compatibility
                                                  before upgrades
  -----------------------------------------------------------------------

## 14. Delivery Plan

### Phase 0 --- Technical feasibility (required)

-   Create a minimal Flutter project using FVM.
-   Verify a Back Tap → Shortcut flow on a real iPhone.
-   Determine what input content can be passed from representative
    payment apps.
-   Prototype App Intent execution without opening Flutter UI.
-   Run Apple Vision OCR on supported receipt images.
-   Validate shared local persistence and duplicate prevention.

**Exit criterion:** demonstrate at least one reliable supported capture
path and document unsupported cases before building the full product.

### Phase 1 --- Local MVP

-   Onboarding and setup guide.
-   Local SQLite data layer.
-   Receipt parsing and categorization rules.
-   Transaction list, dashboard, edit, delete, and deduplication.
-   Capture failure diagnostics and fallback path.

### Phase 2 --- Online account and sync

-   Supabase Auth.
-   PostgreSQL schema and migrations.
-   RLS policies and authorization tests.
-   Sync outbox, retries, idempotent upserts, and sync status.
-   Account/data export and deletion flows.

### Phase 3 --- Release hardening

-   Device and lifecycle testing.
-   Privacy disclosures and App Store requirements.
-   Accessibility, localization, performance, and migration testing.
-   TestFlight beta and feedback iteration.

### Phase 4 --- Android

-   Reuse Flutter domain, data contracts, and most UI.
-   Implement Android-native capture trigger and platform adapter.
-   Define Android-specific permissions and behavior separately; do not
    promise identical Back Tap behavior.

## 15. Open Decisions

These decisions should be confirmed before implementation: 1. Is an
account required before the user can record expenses, or can users start
in guest/local mode and link an account later? 2. What is the initial
default currency and UI language? 3. Which payment/source apps should be
included in the first feasibility test? 4. Should uncertain transactions
be saved as drafts for review, or rejected until the user supplies
better input? 5. Should cloud sync include only structured transaction
data (recommended for MVP), or should users be able to opt into
receipt-image backup later? 6. What is the chosen local database package
and the exact sharing approach for the native capture target? 7. Which
exact stable Flutter version is compatible with the selected Xcode and
native dependencies at project bootstrap?

## 16. References

-   Supabase Flutter quickstart:
    https://supabase.com/docs/guides/getting-started/quickstarts/flutter
-   Supabase Row Level Security:
    https://supabase.com/docs/guides/database/postgres/row-level-security
-   Supabase Flutter installation:
    https://supabase.com/docs/reference/dart/installing
-   Flutter database selection guide:
    https://docs.flutter.dev/data-and-backend/persistence/choose-a-database
-   Firebase Firestore offline persistence (comparison):
    https://firebase.google.com/docs/firestore/manage-data/enable-offline
-   FVM project/version management: https://fvm.app/documentation
-   Apple App Intents documentation:
    https://developer.apple.com/documentation/appintents
-   Apple Shortcuts User Guide:
    https://support.apple.com/guide/shortcuts/welcome/ios

------------------------------------------------------------------------

**PRD status note:** This document defines the intended product and
proposed architecture. The cross-app receipt-content handoff through
Back Tap/Shortcuts is a feasibility risk, not a guaranteed iOS
capability. Phase 0 must validate it on real devices before universal
capture is promised.
