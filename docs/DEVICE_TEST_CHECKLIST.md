# Device test checklist

Run on at least: one low-end Android phone, one recent Android phone, one
iPhone (after Module 12b). Use a release or profile build. Record result,
device and build for every row.

## Capture and extraction

| # | Scenario | Steps | Expected |
|---|---|---|---|
| C1 | Good invoice | Flat A4 invoice, good light, camera | Edges found, preview sharp, read succeeds, review fields match the paper |
| C2 | Poor light | Dim room, then glare from a lamp | Either a usable scan or a clear "retake" error; never a crash or silent wrong total |
| C3 | Skewed page | Photograph at ~30 degrees | Scanner straightens it; extraction still correct |
| C4 | Multi-page | 2, then 5 pages | Pages in order in preview and review; one invoice |
| C5 | Too many pages | Try 6 pages (iOS: scan 6) | "Up to 5 pages" message, nothing stored |
| C6 | Gallery import | Import a photo, including a rotated one (EXIF) | Upright in preview and in the sent image |
| C7 | Not an invoice | Scan a menu or a landscape photo | "Doesn't look like an invoice", retake offered |
| C8 | Receipt with tax included | Retail receipt | No false total-mismatch alarm |
| C9 | Camera permission | Deny, then grant in settings | Clear message when denied; works after granting |
| C10 | Cancel | Cancel at: scanner, optimizing, reading | Back to a sensible screen; reading can be retried |

## Offline and recovery

| # | Scenario | Steps | Expected |
|---|---|---|---|
| O1 | Offline at read | Airplane mode, scan, Read | "You're offline" card; scan is kept |
| O2 | Reconnect | Turn airplane mode off with the app open | Invoice moves to review without tapping |
| O3 | Airplane mode mid-read | Start a read, then enable airplane mode | Typed failure, record stays retryable |
| O4 | Kill mid-read | Force-quit while reading, reopen | Record resumes or is retryable; no duplicate; no stuck spinner |
| O5 | Background during review | Edit fields, background 1 minute, return | Edits intact; kill the app too and reopen: draft restored |
| O6 | Double tap | Double-tap Read invoice and Save | One read, one saved invoice |

## Failures and limits

| # | Scenario | Expected |
|---|---|---|
| F1 | App Check rejected (remove the debug token) | "Update needed"; no raw error text |
| F2 | Server quota hit (set a tiny quota) | "Scanning limit reached" only; no provider names |
| F3 | Local daily cap (set `DAILY_EXTRACTION_CAP=2`) | Third read shows the same limit message |
| F4 | Model name invalid in Remote Config | Falls back automatically; read still works |
| F5 | Firebase misconfigured (placeholder options) | App starts; capture, history and delete work; reading says something went wrong |

## Data and privacy

| # | Check | How |
|---|---|---|
| P1 | Images deleted after save | `adb shell run-as <id> ls files/invoice_images` is empty after saving |
| P2 | Images deleted on delete | Delete an unfinished scan; folder shrinks |
| P3 | Scanner temp cleaned | Plugin folder empty after save and after relaunch |
| P4 | No backups (Android) | `adb shell dumpsys backup` shows nothing for the app; manifest has `allowBackup=false` |
| P5 | Backup exclusion (iOS) | Debug output has no "Could not exclude"; check the attribute in a device backup |
| P6 | No content in logs | `adb logcat` during a full flow: no vendor names or amounts |
| P7 | Release build has network | Release APK reads an invoice (INTERNET declared) |

## Accessibility and layout

| # | Check |
|---|---|
| A1 | TalkBack / VoiceOver: complete a scan, fix a warning, save, delete. Every control is announced with a name; notes are read right after their field |
| A2 | Largest system font: home, review, failure, history. Nothing clipped; everything reachable by scrolling |
| A3 | Display size at maximum on a small phone |
| A4 | Dark mode on every screen; text readable |
| A5 | Rotate on every screen (phones and a tablet or foldable) |
| A6 | "Remove animations" on: sweep and shimmer stop; nothing waits on animation |
| A7 | One-handed reach: primary buttons reachable at the bottom |

## Performance (profile mode, DevTools)

| # | Check | Target |
|---|---|---|
| X1 | Scroll the review form with 30 line items | No dropped-frame bursts |
| X2 | Typing in a field with warnings showing | No visible lag |
| X3 | Scan sweep while reading | Smooth; CPU not pegged |
| X4 | 5-page scan, then open the review | No out-of-memory; memory settles afterwards |

## Accuracy evaluation (needed before choosing the model)

Collect 20 real invoices (mixed layouts, currencies, quality). For each field
record right / wrong / missing. Report per-field accuracy and how often the
user had to correct a field. Repeat with each candidate model and with image
size 1600 versus 2000. Decide the fallback model constant from this, not from
documentation defaults.
