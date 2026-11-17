# Release checklist

## Automated gates
- [ ] `flutter analyze` has no issues
- [ ] `flutter test` passes (all modules)
- [ ] `RELEASE_CHECK=true flutter test test/platform` passes
- [ ] `dart run build_runner build --delete-conflicting-outputs` is clean and
      generated files are committed (or generated in CI)

## Android
- [ ] Application id is final (not `com.example`)
- [ ] `targetSdk` is 36 or higher in the built bundle (Play rejects lower for
      new apps and updates since 2026-08-31). Confirm in the AAB, not just
      Gradle
- [ ] Release signing configured; Play App Signing enrolled
- [ ] SHA-256 of the upload key AND the Play app-signing key added to the
      Firebase Android app
- [ ] Native libraries 16 KB aligned; tested on a 16 KB emulator image
- [ ] Edge-to-edge and landscape/tablet behavior checked at target 36
- [ ] Permissions in the merged manifest: INTERNET, ACCESS_NETWORK_STATE,
      CAMERA only (check `build/.../merged_manifest`)
- [ ] `allowBackup="false"` in the merged manifest
- [ ] Data safety form completed (images sent to an AI service)
- [ ] Internal testing track run with real Play Integrity attestation

## iOS
- [ ] Bundle id final; Team ID set; App Attest capability present
- [ ] Entitlement environment is `production` in the release build
- [ ] Built with the SDK version App Store Connect currently requires
- [ ] UIScene lifecycle migration complete
- [ ] Privacy nutrition label and export-compliance answers match reality
- [ ] TestFlight build reads an invoice (App Attest works on a real device)

## Firebase and Google Cloud
- [ ] App Check enforced for AI Logic (both platforms registered)
- [ ] Authenticated-users mode on; Anonymous sign-in enabled
- [ ] Per-user quota lowered; budget alerts set; monitoring on
- [ ] API keys restricted to the app and to the needed APIs
- [ ] Remote Config `model_name` set to a model that passed the accuracy test
- [ ] Rollback plan: set `model_name` back to the previous value
- [ ] Location chosen and confirmed with data-residency needs

## Legal and product
- [ ] Privacy policy published; URL in both stores
- [ ] `docs/PRIVACY_AND_RETENTION.md` reviewed; in-app privacy sheet updated
      with the real provider name
- [ ] Camera purpose string reviewed
- [ ] `docs/DEVICE_TEST_CHECKLIST.md` completed on real devices

## Known limitations to accept or fix before release
| Item | Impact | Decision |
|---|---|---|
| Local-only data, no backup or sync | Data lost with the phone | Accept for Phase 1 or build sync |
| Plaintext SQLite | Readable if the device is compromised | Accept or add encryption |
| Daily cap resets on app data clear | Not abuse protection | Accept; rely on App Check and quotas |
| Gallery import has manual crop only | Angled photos extract worse | Accept; guidance covers it |
| No real analytics or crash reporting | Blind to field problems | Choose providers |
| Fallback model never tested on real invoices | Accuracy and cost unknown | Run the accuracy evaluation |
| No custom typeface | Platform default look | Add a bundled font if wanted |
| Saved invoices are read-only | Typos can't be fixed after saving | Accept or add editing |
| Offline queue runs only while the app is open | No background retry | Accept or add WorkManager / BGTaskScheduler |
