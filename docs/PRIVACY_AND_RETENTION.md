# Privacy and retention (engineering draft)

Status: describes what the code does today. It is not legal advice and needs
review by someone qualified before any store submission.

## What is stored on the device

| Data | Where | Kept until |
|---|---|---|
| Saved invoice (vendor, number, date, line items, amounts, currency) | SQLite database in `<support>/invoice_data/` | The user deletes it |
| Unfinished scan (page images, status, any extracted data and edits) | Database row plus JPEGs in `<support>/invoice_images/` | The user saves or discards it |
| Original scanner output (full resolution) | Plugin folder | Deleted right after compression; leftovers cleaned on launch and after each save |
| Extraction snapshot (what the model returned, to measure corrections) | Database, same row | Erased on save or delete |
| Deleted invoice | A tombstone: id and timestamps only | Kept for a future sync feature; contains no invoice data |
| Daily usage counter (date and count) | `<support>/invoice_data/usage_counter.json` | Overwritten daily |
| Firebase anonymous user id, App Check state, cached Remote Config | Managed by the Firebase SDKs | Until the app is uninstalled or data cleared |

No invoice content is written to logs, analytics or crash reports.
`NoopScanAnalytics` and `NoopCrashReporter` are the defaults; their
interfaces carry only counts, durations, error kinds, field names and error
type names.

## What leaves the device

When the user taps "Read invoice":
- the compressed page images (JPEG, long edge at most 1600 px, no EXIF) and a
  fixed instruction prompt go to Firebase AI Logic (Agent Platform Gemini API
  by default) over TLS;
- a Firebase anonymous-auth token and an App Check token accompany the request;
- the app fetches Remote Config (the model name) on start and about hourly.

Nothing else leaves the device. Saved invoices are not synced.

## Retention and deletion rules (and the code that enforces them)

- Page images are deleted after a successful save and on delete
  (`SaveInvoice`, `DeleteInvoice`).
- Scanner temp files: deleted after compression, after each save, and on
  launch (`CaptureInvoice`, `SaveInvoice`, `RecoverInterruptedWork`).
- Orphaned images (crash leftovers) are swept on launch
  (`RecoverInterruptedWork`).
- Deleting an invoice erases its data and images immediately (`DeleteInvoice`
  and the tombstone rules in `InvoiceRecord.markDeleted`).
- A scan that is never read or discarded stays on the device until the user
  acts. There is no automatic expiry.
- At most 5 pages per invoice are accepted.

## Backups

- Android: `allowBackup="false"`; nothing is backed up.
- iOS: the two data folders are marked "excluded from backup" at every launch.
  Consequence: invoices do not survive a lost or replaced phone.

## Provider terms (verify before release)

- Agent Platform: prompts and responses are not used to improve Google
  products; enterprise data terms apply. Confirm the data-processing terms and
  the data location with your Google Cloud contact.
- Gemini Developer API free tier: may use content to improve products and may
  involve human review. Never use it with real invoices.
- Abuse-monitoring logs may be retained by the provider for a limited period.

## Controls and limits

- The user can delete any invoice from the history list or the detail screen.
- A local daily cap (default 60 reads) and server-side per-user quotas limit
  usage. Neither is abuse protection on its own; App Check enforcement is.

## Open items for review

- Privacy policy text and URL; Play Data safety and App Store privacy answers
  (images are sent to an AI service; no data is sold; data is not linked to an
  account other than an anonymous id).
- Whether saved data should be encrypted at rest.
- Whether unfinished scans should expire automatically.
- Name the actual provider and region in the in-app privacy sheet.
