# Soreva — Credentials, Keys, and Third-Party Setup

**Status:** v1.0
**Date:** 20 October 2026
**Companion to:** `personal_finance_capture_prd.md` (v3.2), `implementation_plan.md`

This is the complete inventory of every account, identifier, key, and
certificate the project needs, when it is needed, and whether it is a secret.
Work through §10 first — it is the only set required to start Phase 0.

---

## 1. Master inventory

Classification: **Public** = safe to ship in the app binary. **Secret** = must
never enter the repo or the app. **Config** = not sensitive but environment-
specific.

| # | Item | Source | Needed by | Class | Goes where |
|---|---|---|---|---|---|
| A1 | Apple Developer Program membership | Apple | Phase 0 | — | Already enrolled (D-21) |
| A2 | Apple Team ID | Developer portal → Membership | Phase 0 | Config | Xcode signing |
| A3 | Bundle Identifier | Developer portal → Identifiers | Phase 0 | Public | Xcode, Supabase Apple provider |
| A4 | App Group identifier | Developer portal → Identifiers | Phase 0 | Public | Entitlements, both targets |
| A5 | Sign in with Apple capability | Enable on the App ID (A3) | Phase 2 | — | App ID + Xcode capability |
| A6 | Development signing cert + profile | Xcode-managed | Phase 0 | Secret | Local keychain |
| A7 | Distribution cert + profile | Xcode-managed or manual | Phase 3 | Secret | Local keychain / CI secrets |
| A8 | App Store Connect app record | App Store Connect | Phase 3 | — | — |
| A9 | App Store Connect API key (`.p8`) | App Store Connect → Integrations | Phase 3, optional | **Secret** | CI secrets only |
| A10 | Apple Services ID + Key ID + `.p8` | Developer portal | **Phase 4 only** | **Secret** | Supabase dashboard (not the app) |
| G1 | Google Cloud project | console.cloud.google.com | Phase 2 | — | — |
| G2 | OAuth client ID — **iOS** type | GCP → Credentials | Phase 2 | Public | `GoogleSignIn(clientId:)`, Info.plist URL scheme |
| G3 | OAuth client ID — **Web** type | GCP → Credentials | Phase 2 | Public | `GoogleSignIn(serverClientId:)`, Supabase Google provider |
| G4 | OAuth consent screen config | GCP → OAuth consent | Phase 2 | — | Needs privacy policy URL (R2) |
| S1 | Supabase account | supabase.com | Phase 2 | — | — |
| S2 | Supabase project URL | Project settings → API | Phase 2 | Public | App config |
| S3 | Supabase anon / publishable key | Project settings → API | Phase 2 | Public | App config |
| S4 | Supabase `service_role` key | Project settings → API | Phase 2 | **Secret** | Edge Function secret only |
| S5 | Database password | Set at project creation | Phase 2 | **Secret** | Local `.env`, password manager |
| S6 | Supabase CLI access token | supabase.com/dashboard/account/tokens | Phase 2 | **Secret** | Local `.env`, CI secrets |
| S7 | Apple provider config | Supabase → Auth → Providers | Phase 2 | Config | Dashboard |
| S8 | Google provider config | Supabase → Auth → Providers | Phase 2 | Config | Dashboard |
| S9 | Deep-link redirect URL | Chosen by you | Phase 2 | Public | Supabase URL config + Info.plist |
| C1 | Sentry DSN *(recommended)* | sentry.io | Phase 1 | Public | App config |
| C2 | Sentry auth token | Sentry → Auth tokens | Phase 3 | **Secret** | CI secrets (symbol upload) |
| R1 | GitHub repository | github.com | Phase 0 | — | — |
| R2 | Privacy policy URL | GitHub Pages (free) | Phase 2 | Public | GCP consent screen, App Store |
| R3 | Support URL | GitHub Pages (free) | Phase 3 | Public | App Store Connect |
| P1 | Google Play Developer account | USD 25 one-time | **Phase 4 only** | — | — |
| P2 | Android OAuth client ID | GCP → Credentials | **Phase 4 only** | Public | Android config |

---

## 2. What you do NOT need

Worth stating, because each of these is a cost or a delay people assume:

- **No OCR API key.** Apple Vision is on-device and part of the OS. No account,
  no quota, no bill, works offline. This is normally the expensive part of a
  receipt-scanning product.
- **No payment provider credentials.** No GoPay, OVO, DANA, ShopeePay, or bank
  API access, partnership, or developer account. The screenshot approach needs
  nothing from them — that is the whole point of D-16.
- **No Apple Services ID or `.p8` for MVP.** Native iOS Sign in with Apple
  sends an identity token straight to Supabase, which validates it against
  Apple's public keys. You only add your **bundle ID** to Supabase's Client IDs
  field. Services ID, Key ID, and `.p8` become necessary only for web or
  Android (A10, Phase 4).
- **No Google API key.** You are only authenticating, not calling Google APIs.
- **No OAuth app verification.** You request `email` and `profile` only, which
  are non-sensitive scopes. Google's verification review is not triggered.
- **No push notification certificates.** Push is out of scope.
- **No Firebase project** — unless you choose Crashlytics over Sentry, which
  would pull in the whole Firebase SDK. See §7.
- **No paid CI.** See §8.

---

## 3. Apple

### 3.1 Identifiers to register (Phase 0)

In the Developer portal → Certificates, Identifiers & Profiles → Identifiers:

1. **App ID** with an explicit bundle identifier. Suggested:
   `studio.illiyin.soreva`. Avoid wildcards — App Groups and Sign in with Apple
   both need an explicit ID.
2. **App Group**, conventionally the bundle ID prefixed with `group.`:
   `group.studio.illiyin.soreva`.

Then in Xcode, add the App Group capability to **both** the main app target and
the App Intent target, selecting the same group. The inbox (PRD §7.6) does not
work unless both targets carry the identical entitlement — this is the single
most common cause of a silently empty inbox.

### 3.2 Sign in with Apple (Phase 2)

- Enable the **Sign in with Apple** capability on the App ID (A5).
- Add the capability in Xcode to the main app target.
- In Supabase → Auth → Providers → Apple: enable it and put your **bundle ID**
  in the Client IDs field. Leave Services ID, Secret Key, and Key ID empty —
  they are for the web/Android flow only.

### 3.3 Signing

Xcode-managed automatic signing is fine through Phase 2. You need manual
certificate export only if you add CI builds in Phase 3 (A7, A9).

---

## 4. Google — the two-client-ID trap

**You must create two OAuth clients, not one.** This is the most common setup
failure for Supabase + Google on iOS.

| Client type | Field it fills | Why |
|---|---|---|
| **iOS** (G2) | `GoogleSignIn(clientId: ...)` | Identifies the app to Google on-device |
| **Web** (G3) | `GoogleSignIn(serverClientId: ...)` **and** Supabase's Google provider | The ID token's audience must be the web client, because Supabase's auth server is what verifies the token |

If you create only the iOS client, sign-in appears to work on-device and then
Supabase rejects the token with an audience mismatch.

### 4.1 Steps (Phase 2)

1. Create a Google Cloud project (G1).
2. Configure the OAuth consent screen (G4): app name, support email, and a
   privacy policy URL (R2). Scopes: `email`, `profile` only.
3. Create an **iOS** OAuth client (G2) using bundle ID A3. Note the client ID
   and its reversed form.
4. Create a **Web** OAuth client (G3). Note the client ID.
5. Add the reversed iOS client ID to `Info.plist` as a URL scheme.
6. In Supabase → Auth → Providers → Google: enable, paste the **web** client ID
   (G3) into Client IDs.
7. **Turn on "Skip nonce check"** in that same Supabase Google provider panel.
   Native iOS Google sign-in does not supply a nonce Supabase can verify, and
   sign-in fails without this. Non-obvious and easy to lose hours to.

---

## 5. Supabase

### 5.1 Keys and their boundaries

- **S2 project URL + S3 anon key** are designed to be public. They ship in the
  app. Their safety depends entirely on RLS being correct — which is why PRD
  §12 makes a multi-user RLS test a release gate, not a nice-to-have.
- **S4 `service_role` key bypasses RLS completely.** It must never appear in
  the app, the repo, or any client-reachable config. Its only legitimate home
  in this project is an Edge Function secret (§6).
- **S5 database password** and **S6 CLI token** are local tooling secrets for
  migrations.

### 5.2 Configuration

- S9 deep-link scheme, e.g. `studio.illiyin.soreva://login-callback`, added to
  Supabase → Auth → URL Configuration and to `Info.plist`. The native
  id-token flow mostly bypasses it, but password-less recovery paths and future
  providers need it registered.

---

## 6. Account deletion needs server-side code (easy to miss)

App Store Guideline 5.1.1(v) requires in-app account deletion. Deleting a
Supabase auth user requires the **admin API**, which requires the
`service_role` key — which cannot be in the app.

So in-app account deletion is **not** a pure client feature. It needs:

- A **Supabase Edge Function** (free tier), e.g. `delete-account`.
- The `service_role` key (S4) stored as an Edge Function **secret**, set via
  `supabase secrets set`, never committed.
- The function verifies the caller's JWT, derives their user ID from it —
  never from a request parameter — deletes their rows, then deletes the auth
  user.
- The client calls it with the user's session, then clears all local data.

Plan this into Phase 2, not Phase 3. Discovering it during release prep is a
common way to slip a submission.

---

## 7. Crash reporting — pick Sentry

Both are free. **Recommended: Sentry.**

- **Sentry:** one DSN (C1), a single Flutter package, no platform config files.
- **Crashlytics:** free and excellent, but pulls in the Firebase SDK,
  `GoogleService-Info.plist`, and a second Google project to maintain alongside
  Supabase — meaningful weight for one feature.

Resolves §15 item 4 of the PRD if you agree.

---

## 8. CI and release

- GitHub Actions is free on **public** repos. macOS runners consume quota about
  10x faster than Linux, so a private repo will exhaust the free allowance
  quickly.
- **Recommendation:** run Dart tests and the §7.4 boundary lint on Linux
  runners (fast, cheap, works on private repos) and build iOS locally through
  Phase 2. Add macOS CI only in Phase 3 if you want automated TestFlight
  uploads, which is when A7 and A9 become necessary.
- R2 privacy policy and R3 support page both host free on GitHub Pages.

---

## 9. Secret handling

**Never commit:** S4, S5, S6, C2, A9, A10, and any `.p8` or `.p12`.

Recommended layout:

```
config/
  example.json      # committed — keys present, values empty
  dev.json          # gitignored
  prod.json         # gitignored
.env                # gitignored — CLI/tooling secrets (S5, S6)
```

Load app config with `--dart-define-from-file=config/dev.json` so values never
live in Dart source. Add `config/dev.json`, `config/prod.json`, and `.env` to
`.gitignore` **before** the first commit that touches them.

Even though S2 and S3 are public by design, routing them through config keeps
environment separation and key rotation trivial.

---

## 10. Phase 0 minimal set — what to get now

Phase 0 touches no cloud service at all. You need exactly four things:

- [ ] **A2** Apple Team ID — read it off the portal
- [ ] **A3** Bundle Identifier registered, e.g. `studio.illiyin.soreva`
- [ ] **A4** App Group registered, e.g. `group.studio.illiyin.soreva`
- [ ] **R1** GitHub repository created, `.gitignore` in place

Everything Google and Supabase waits for Phase 2. Do not create those accounts
yet — if Phase 0 hits its pivot criterion, the cloud design may change.

---

## 11. Full checklist by phase

**Phase 0** — A2, A3, A4, A6, R1
**Phase 1** — C1 (Sentry DSN)
**Phase 2** — A5, G1, G2, G3, G4, S1, S2, S3, S4, S5, S6, S7, S8, S9, R2
**Phase 3** — A7, A8, A9 (optional), C2, R3
**Phase 4** — A10, P1, P2
