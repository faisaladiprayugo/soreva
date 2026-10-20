# Phase 0 / Stage 0A — Trigger Spike: Test Protocol & Results

**Status:** awaiting device run
**Goal:** answer the five gating questions in PRD §5.2 and decide route priority (D-17).
**Expected time:** 30–45 minutes once the app is on the phone.

> This spike is throwaway code. It lives in `AppDelegate.swift` and `lib/main.dart`
> on purpose — no App Group, no extra Xcode target, no `project.pbxproj` surgery.
> Stage 0C rebuilds it properly per PRD §7.6.

---

## What is already done

- [x] Bundle ID set to `studio.illiyin.soreva`, iOS deployment target 18.2
- [x] App Intent `SorevaCaptureSpikeIntent` with `openAppWhenRun = false`
- [x] Apple Vision OCR, on-device, language auto-detect, no autocorrection
- [x] Atomic capture-record write (temp + rename) mirroring the §7.6 schema
- [x] Intent returns a **dialog** so results are readable on-device, no debugger
- [x] Dart read-back screen listing every capture record

**No Apple portal work needed first.** With automatic signing and your paid
account, Xcode registers `studio.illiyin.soreva` when you first build to the
device. The App Group is only needed in Stage 0C.

---

## Step 1 — Build and install

Connect the iPhone (both your devices showed as offline) and trust the Mac.

```bash
cd /Users/faisaladiprayugo/Documents/IlliyinStudio/Flutter/soreva
fvm flutter devices          # confirm the phone is listed
fvm flutter run --release    # --release so Back Tap works with the app closed
```

If signing fails, open `ios/Runner.xcworkspace` in Xcode once, pick your team
under Signing & Capabilities, then re-run.

Launch the app once so iOS registers the App Intent, then close it.

---

## Step 2 — Build the Shortcut

Shortcuts app → **+** → add these three actions in order:

1. **Get Current App**
2. **Take Screenshot**
3. **Capture Expense (Spike)** — under Soreva's actions

Wire the parameters: `Screenshot` ← the Take Screenshot output,
`Current App` ← the Get Current App output (use its **Name**).

Name it `Soreva Capture`. Run it once from inside Shortcuts to clear any
first-run permission prompt.

---

## Step 3 — Bind Back Tap

Settings → Accessibility → Touch → Back Tap → **Double Tap** → choose
`Soreva Capture` under Shortcuts.

---

## Step 4 — The actual test

Open a payment app, reach a **receipt or transaction-success screen**, and
double-tap the back of the phone. Record what the dialog says.

Repeat for each app in D-14. Then reopen Soreva and pull to refresh to confirm
every capture landed in the inbox.

---

## Results — questions to answer

### Q1. Does `Take Screenshot` prompt for permission on every run?

> **Why it matters:** a prompt per capture destroys the frictionless premise and
> makes Route A primary.

- [ ] Prompts once, then never again → **Route B viable**
- [ ] Prompts every single run → **Route A becomes primary**
- [ ] Never prompts → Route B viable

**Observed:**

---

### Q2. Does it capture the payment app, or the Shortcuts overlay?

> **Why it matters:** if it captures Shortcuts' own UI, Route B cannot work.

- [ ] The payment app's receipt → **Route B viable**
- [ ] Shortcuts overlay / banner / blank → **Route A becomes primary**

**Observed:**

---

### Q3. Does `Get Current App` return the payment app, or Shortcuts?

> **Why it matters:** this decides whether `source_app` is authoritative (D-18)
> or degrades to OCR inference.

- [ ] The payment app, e.g. `GoPay` → **authoritative attribution confirmed**
- [ ] `Shortcuts` → fall back to OCR inference, update D-18
- [ ] Empty / not reported → same

**Observed per app:**

| Payment app | `Get Current App` returned |
|---|---|
| GoPay | |
| OVO | |
| DANA | |
| ShopeePay | |
| Bank (BCA / Livin) | |

---

### Q4. Tap-to-inbox latency?

> **Why it matters:** App Intents run under a short execution budget. OCR on a
> full-resolution screenshot is the main cost.

**Observed (the dialog prints ms):** ______ ms typical, ______ ms worst

- [ ] Under ~1500ms — comfortable
- [ ] Over ~3000ms — consider downscaling the image before OCR

---

### Q5. Does any of it differ when the app has never been launched?

> **Why it matters:** PRD §5.2 requires capture to work cold.

Force-quit Soreva, then reboot the phone and capture without opening the app.

- [ ] Identical behaviour
- [ ] Degrades — describe:

**Observed:**

---

## Bonus data the spike collects for free

### Does Vision support Indonesian?

The Dart screen shows `vision id-ID: SUPPORTED / not supported` per capture.
Feeds the §5.3 parser design.

**Observed:**

### OCR quality per provider

Fill from the capture records. This becomes the Stage 0D corpus baseline and
the Phase 1 parser's regression target.

| App | chars | blocks | mean conf | total found? | merchant? | date? | brand visible? |
|---|---|---|---|---|---|---|---|
| GoPay | | | | | | | |
| OVO | | | | | | | |
| DANA | | | | | | | |
| ShopeePay | | | | | | | |
| QRIS | | | | | | | |
| Bank | | | | | | | |

---

## Decision

**Route priority:**  ☐ Route B primary   ☐ Route A primary   ☐ Both failed → pivot

**Pivot trigger (PRD §14):** if *both* routes fail to capture the foreground app
unattended, reframe around Share Sheet + fast manual entry and revise the PRD
before Phase 1.

**Record the outcome in PRD D-17, then proceed to Stage 0B.**
