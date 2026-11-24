<div align="center">

# 🔐 Privacy & Retention

**What Invoice Scanner stores, what leaves the device, and how deletion works.**

</div>

> **Principle:** invoices are financial documents. The app keeps them on the device, sends a scan off the device only when the user asks for it to be read, and never writes invoice content to logs or crash reports.

---

## 1. Data Stored on the Device

| Data | Location | Retention |
|---|---|---|
| Scanned page images (JPEG, long edge ≤ 1600 px, ≤ 5 pages) | Managed app image directory | Removed on save, on discard, and swept on launch for orphans |
| Invoice records (vendor, dates, line items, totals) | Local Drift SQLite database | Until the user deletes the invoice |
| Money values | Same database | Stored as integer minor units with an explicit currency |
| Extraction queue state (status, attempt count) | Same database | Cleared when the extraction succeeds, fails permanently, or the invoice is deleted |
| Daily usage counter | Local storage | Rolls over daily |

No account profile, contacts, location, or advertising identifiers are collected by the app code.

## 2. Data That Leaves the Device

| When | What is sent | To whom | Why |
|---|---|---|---|
| The user taps **Extract** (or a queued retry the user previously requested) | The compressed invoice page images | Gemini via Firebase AI Logic | Read the invoice into structured fields |
| Each extraction request | An App Check token | Firebase | Reject requests from tampered or unofficial clients |
| App start (if configured) | Remote Config fetch | Firebase | Optional model-name override |
| Uncaught error (if a reporter is installed) | Error `runtimeType` and stack trace only | Crash reporting backend | Diagnose crashes |

**A scan that is merely captured never leaves the device.** The offline queue only retries scans the user explicitly asked to read: `failed(network)` or an interrupted `pendingExtraction` with `attemptCount > 0`.

## 3. What Is Never Collected or Logged

- Invoice content (vendor names, amounts, line items) in logs, errors, or crash reports.
- `print` and `developer.log` calls outside a guarded `debugPrint` allowlist, enforced by `architecture_test.dart`.
- `InvoiceFailure.debugCode` and the crash reporter carry only type names and short codes.

## 4. Deletion

1. The user opens a saved invoice and chooses **Delete**, then confirms.
2. The record is removed through a tombstone delete so an in-flight queue run cannot resurrect it or lose it silently.
3. Associated page images are removed from the managed directory.
4. Uninstalling the app removes all local data.

> Data already sent to the AI provider is governed by the provider's terms, not by the app. See section 5.

## 5. Provider Terms to Verify Before Release

Fill these in against the current provider documents; do not ship with them blank.

- [ ] Whether Gemini API inputs sent through Firebase AI Logic are used for model training, and under which plan or setting.
- [ ] Provider retention period for request content (including abuse-monitoring logs).
- [ ] Data-processing region and any data-residency commitments.
- [ ] Whether a data processing agreement is required for your users.
- [ ] Firebase and Google Play data-safety declarations match this document.

## 6. User-Facing Privacy Sheet

The in-app privacy sheet should state, in plain language:

1. Invoices are stored on this device.
2. A scan is sent for reading only when you tap Extract.
3. You can delete any invoice at any time.
4. The app does not log what is on your invoices.

## 7. Policy URL

Google Play requires a hosted privacy policy URL. Publish this document (or a user-friendly derivative) and link it from the store listing and the app.

_Last reviewed: update this date at every release._
