<div align="center">

# 📱 Device Test Checklist

**Run on a real Android phone before every release.**

</div>

| Field | Value |
|---|---|
| Build | `__________` |
| Device / Android version | `__________` |
| Tester / Date | `__________` |
| Extractor | ☐ Demo (`USE_DEMO_EXTRACTOR=true`) ☐ Real Gemini |

Mark each row ✅ pass, ❌ fail, or ➖ not applicable. Note failures at the bottom.

---

## 1. Install & Launch

- [ ] Release APK installs with `adb install -r` and launches without a crash.
- [ ] App name and adaptive launcher icon (including monochrome layer) look correct.
- [ ] Cold start shows the home screen with no error banner.
- [ ] Orphaned images from a previous force-quit are cleaned on launch.

## 2. Capture

- [ ] Camera permission prompt appears and is handled when **denied**, then recoverable from settings.
- [ ] Native document scanner opens and returns a cropped page.
- [ ] Importing from gallery works.
- [ ] Stacking up to 5 pages works; adding a 6th is blocked with a clear message.
- [ ] Cancelling the scanner returns to the start state with nothing saved.
- [ ] Preview shows the pages; **Retake** and **Discard** both work.

## 3. Extraction

- [ ] Demo extractor returns sample data after about 2 seconds.
- [ ] Real extraction fills vendor, date, currency, line items, and totals.
- [ ] Processing screen can be cancelled.
- [ ] A non-invoice photo produces the "not an invoice" card.
- [ ] A blank or unreadable page produces the empty or malformed card.

## 4. Review & Save

- [ ] Every field is editable.
- [ ] Editing a line item recalculates its total; a manually set total is never overwritten.
- [ ] Changing currency reseeds the amount field correctly.
- [ ] Warnings are shown but do not block save.
- [ ] Unparseable text blocks save with a clear notice.
- [ ] Date picker works and respects the device locale.
- [ ] Decimal comma and decimal point inputs both parse as expected.
- [ ] Save succeeds and the invoice appears in History.

## 5. Offline & Failure Behaviour

- [ ] Airplane mode during extraction shows a network failure card.
- [ ] Retry after reconnecting succeeds.
- [ ] Failed(network) scans are retried automatically when the app resumes online.
- [ ] A merely-captured, never-extracted scan is **not** sent after reconnecting.
- [ ] Force-quit during extraction, then reopen: the invoice is still listed and can be resumed.
- [ ] Quota, timeout, App Check, and safety failures each show a distinct plain-language card.

## 6. History & Detail

- [ ] "In progress" and "Saved" sections group correctly.
- [ ] Each status tile shows plain-language text.
- [ ] Tapping an unfinished invoice resumes it; tapping a saved one opens it read-only.
- [ ] Delete asks for confirmation and removes the invoice and its images.
- [ ] Privacy sheet opens and reads correctly.

## 7. Privacy

- [ ] No invoice text appears in `adb logcat` during a full scan, extract, save, and delete cycle.
- [ ] App makes no network calls before the user taps Extract (check with a proxy or network monitor).
- [ ] After delete, the image directory has no leftover files for that invoice.

## 8. Accessibility

- [ ] TalkBack announces every button and field with a meaningful label.
- [ ] All tap targets are at least 48 dp.
- [ ] Text scale 200%: no clipped text or overflow on every screen. _(Known gap: `PreviewScreen` and `ReviewScreen` at 320 dp × 2× text.)_
- [ ] Dark theme is readable throughout.
- [ ] Right-to-left locale (for example Arabic) mirrors the layout correctly.
- [ ] Display size and font size set to maximum in system settings still work.

## 9. Performance

- [ ] Compression of 5 pages does not freeze the UI.
- [ ] Scrolling a History list of 100+ invoices stays smooth.
- [ ] Memory stays stable across 10 consecutive scans.
- [ ] Battery and heat are reasonable after 10 minutes of use.

## 10. Accuracy Evaluation (real Gemini only)

Test at least 20 real invoices across vendors, languages, and layouts.

| # | Vendor correct | Date correct | Total correct | Line items correct | Notes |
|---|---|---|---|---|---|
| 1 | ☐ | ☐ | ☐ | ☐ | |
| 2 | ☐ | ☐ | ☐ | ☐ | |
| 3 | ☐ | ☐ | ☐ | ☐ | |

Record the pass rate per field. Decide a minimum acceptable rate before release.

---

## Failures & Notes

```text
(describe anything that failed, with steps to reproduce)
```

**Sign-off:** ☐ Ready to ship ☐ Blocked
