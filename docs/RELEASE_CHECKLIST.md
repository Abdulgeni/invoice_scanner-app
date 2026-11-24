<div align="center">

# 🚀 Release Checklist

**Every gate that must be green before shipping Invoice Scanner.**

</div>

---

## 1. Automated Gates

- [ ] `flutter analyze` reports **0 issues**.
- [ ] Full suite passes:
  ```bash
  flutter test test/features/invoice_scanner test/core test/app test/platform test/architecture test/accessibility
  ```
- [ ] Skipped tests are understood and listed under *Known Limitations* (currently 9).
- [ ] Release-safety gate passes once Firebase is configured:
  ```bash
  RELEASE_CHECK=true flutter test test/platform
  ```

## 2. Android

- [ ] `applicationId` is `io.github.abdulgeni.invoicescanner` and will not change.
- [ ] `minSdk 24`, `targetSdk 36`.
- [ ] `android/key.properties` and `android/app/upload-keystore.jks` exist locally and are **not** in git.
- [ ] Keystore and passwords are backed up in a secure place.
- [ ] Release build succeeds and fails if the signing key is missing (no debug fallback):
  ```bash
  flutter build apk --release
  ```
- [ ] Signature verifies:
  ```bash
  apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
  ```
- [ ] Manifest requests only the permissions the app needs.
- [ ] Version name and code bumped in `pubspec.yaml`.
- [ ] Installed and exercised on a physical device (see `DEVICE_TEST_CHECKLIST.md`).

## 3. Firebase & Gemini (required for real extraction)

- [ ] Firebase project created.
- [ ] `flutterfire configure` run; real `firebase_options.dart` committed and placeholders removed.
- [ ] Firebase AI Logic enabled and the Gemini API provisioned.
- [ ] **App Check** enforced (Play Integrity for release builds).
- [ ] Remote Config model-name key created, with a safe default.
- [ ] Budget alerts and quotas set for the project.
- [ ] Local daily usage cap value reviewed.
- [ ] Release build no longer needs `USE_DEMO_EXTRACTOR=true`.

## 4. Legal & Privacy

- [ ] `PRIVACY_AND_RETENTION.md` provider-terms checklist is fully answered.
- [ ] Privacy policy is hosted at a public URL.
- [ ] In-app privacy sheet matches the policy.
- [ ] Google Play **Data safety** form matches what the app really does.
- [ ] Third-party licenses are displayed or accessible.

## 5. Play Store Submission

- [ ] Developer account and app entry created.
- [ ] Store listing: title, short and full description, screenshots, feature graphic.
- [ ] App icon and category set.
- [ ] Content rating questionnaire completed.
- [ ] Target audience and ads declarations completed.
- [ ] Privacy policy URL added.
- [ ] Release uploaded as an AAB (`flutter build appbundle --release`) to an internal test track first.

## 6. GitHub Release (sideload)

- [ ] Git tag matches the version.
- [ ] Signed APK attached to the GitHub Release.
- [ ] Release notes written, including known limitations.
- [ ] README badges (test count, APK size) match the shipped build.

## 7. iOS (not shipped yet)

Invoice Scanner is Android-first by design. Before an iOS release:

- [ ] iOS platform folder added and builds.
- [ ] Camera and photo-library usage strings added.
- [ ] Document scanner plugin verified on iOS.
- [ ] App Check configured with App Attest or DeviceCheck.
- [ ] App Store privacy labels completed.
- [ ] Device checklist re-run on an iPhone.

## 8. Known Limitations (keep honest)

- 9 skipped tests: 3 `RELEASE_CHECK`-gated, 2 screen-matrix overflows at 320 dp × 2× text (`PreviewScreen`, `ReviewScreen`), 4 deferred review/echo edge cases.
- Firebase AI Logic is not configured in the current released APK; it falls back to the demo or unavailable extractor.
- No Play Store listing yet.
- No iOS build.

---

**Final sign-off:** ☐ All gates green ☐ Exceptions documented ☐ Approved by: `__________`  Date: `__________`
