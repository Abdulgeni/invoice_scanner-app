import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice Scanner'**
  String get appTitle;

  /// No description provided for @homeLastInvoiceTotal.
  ///
  /// In en, this message translates to:
  /// **'Last invoice total'**
  String get homeLastInvoiceTotal;

  /// No description provided for @scanAction.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scanAction;

  /// No description provided for @scanInvoiceSemantics.
  ///
  /// In en, this message translates to:
  /// **'Scan invoice'**
  String get scanInvoiceSemantics;

  /// No description provided for @importFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Import from gallery'**
  String get importFromGallery;

  /// No description provided for @retakeAction.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retakeAction;

  /// No description provided for @retryAction.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retryAction;

  /// No description provided for @keepImageAction.
  ///
  /// In en, this message translates to:
  /// **'Keep image'**
  String get keepImageAction;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @confirmAndSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Save'**
  String get confirmAndSaveAction;

  /// No description provided for @stageOptimizing.
  ///
  /// In en, this message translates to:
  /// **'Optimizing image'**
  String get stageOptimizing;

  /// No description provided for @stageReading.
  ///
  /// In en, this message translates to:
  /// **'Reading invoice'**
  String get stageReading;

  /// No description provided for @stageValidating.
  ///
  /// In en, this message translates to:
  /// **'Checking totals'**
  String get stageValidating;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read this invoice'**
  String get errorTitle;

  /// Module 6 will replace this with an offline-queue promise once that queue ships.
  ///
  /// In en, this message translates to:
  /// **'You appear to be offline. Connect to the internet and try again.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'This is taking longer than expected. Check your connection and try again.'**
  String get errorTimeout;

  /// Single user-facing message for rate or usage limits. Must not mention any backend, provider, or error code.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the scanning limit for now. Please try again in a little while.'**
  String get errorQuotaExceeded;

  /// No description provided for @errorAppCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t verify this copy of the app. Update it from the official app store and try again.'**
  String get errorAppCheckFailed;

  /// No description provided for @errorSafetyBlock.
  ///
  /// In en, this message translates to:
  /// **'This image couldn\'t be processed. Try a clearer photo of the invoice.'**
  String get errorSafetyBlock;

  /// No description provided for @errorEmptyResponse.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read anything from this image. Try again, or retake the photo in better light.'**
  String get errorEmptyResponse;

  /// No description provided for @errorMalformedJson.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t make sense of the result. Please try again.'**
  String get errorMalformedJson;

  /// No description provided for @errorNotAnInvoice.
  ///
  /// In en, this message translates to:
  /// **'This doesn\'t look like an invoice. Retake the photo with the whole page in view.'**
  String get errorNotAnInvoice;

  /// No description provided for @errorCancelled.
  ///
  /// In en, this message translates to:
  /// **'Scan cancelled.'**
  String get errorCancelled;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorUnknown;

  /// No description provided for @pageLimitExceeded.
  ///
  /// In en, this message translates to:
  /// **'Invoices can have up to {max} pages. Remove some pages and try again.'**
  String pageLimitExceeded(int max);

  /// No description provided for @warningTotalMismatch.
  ///
  /// In en, this message translates to:
  /// **'The line items add up to {lineSum}, but the total says {total}.'**
  String warningTotalMismatch(String lineSum, String total);

  /// No description provided for @validationInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number, for example {example}.'**
  String validationInvalidNumber(String example);

  /// No description provided for @scanInvoiceAction.
  ///
  /// In en, this message translates to:
  /// **'Scan invoice'**
  String get scanInvoiceAction;

  /// No description provided for @homeHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan an invoice'**
  String get homeHeroTitle;

  /// No description provided for @homeHeroBody.
  ///
  /// In en, this message translates to:
  /// **'Capture it, check the details, and save it in seconds.'**
  String get homeHeroBody;

  /// No description provided for @homeTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Scanning tips'**
  String get homeTipsTitle;

  /// No description provided for @recentInvoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent invoices'**
  String get recentInvoicesTitle;

  /// No description provided for @recentInvoicesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Invoices you save will appear here.'**
  String get recentInvoicesEmpty;

  /// No description provided for @invoiceUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed invoice'**
  String get invoiceUnnamed;

  /// No description provided for @recentNoTotal.
  ///
  /// In en, this message translates to:
  /// **'No total'**
  String get recentNoTotal;

  /// No description provided for @recentNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get recentNoDate;

  /// No description provided for @guidanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you scan'**
  String get guidanceTitle;

  /// No description provided for @guidanceLighting.
  ///
  /// In en, this message translates to:
  /// **'Use even light and avoid glare or shadows.'**
  String get guidanceLighting;

  /// No description provided for @guidanceFlat.
  ///
  /// In en, this message translates to:
  /// **'Lay the page flat on a plain, dark surface.'**
  String get guidanceFlat;

  /// No description provided for @guidanceFrame.
  ///
  /// In en, this message translates to:
  /// **'Keep the whole page in the frame, edge to edge.'**
  String get guidanceFrame;

  /// No description provided for @guidanceMultiPage.
  ///
  /// In en, this message translates to:
  /// **'Long invoice? Scan up to {max} pages, in order.'**
  String guidanceMultiPage(int max);

  /// No description provided for @guidanceStart.
  ///
  /// In en, this message translates to:
  /// **'Open camera'**
  String get guidanceStart;

  /// No description provided for @previewTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your scan'**
  String get previewTitle;

  /// No description provided for @previewHint.
  ///
  /// In en, this message translates to:
  /// **'Make sure every line is readable. Pinch to zoom.'**
  String get previewHint;

  /// No description provided for @previewPageCounter.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String previewPageCounter(int current, int total);

  /// No description provided for @previewPageSemantics.
  ///
  /// In en, this message translates to:
  /// **'Invoice page {current} of {total}'**
  String previewPageSemantics(int current, int total);

  /// No description provided for @previewImageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This page couldn\'t be shown.'**
  String get previewImageUnavailable;

  /// No description provided for @readInvoiceAction.
  ///
  /// In en, this message translates to:
  /// **'Read invoice'**
  String get readInvoiceAction;

  /// No description provided for @discardAction.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardAction;

  /// No description provided for @discardConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this scan?'**
  String get discardConfirmTitle;

  /// No description provided for @discardConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The captured pages will be deleted.'**
  String get discardConfirmBody;

  /// No description provided for @capturingOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening scanner…'**
  String get capturingOpening;

  /// No description provided for @captureErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t scan'**
  String get captureErrorTitle;

  /// No description provided for @captureErrorCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access is turned off. Turn it on in your device settings to scan invoices.'**
  String get captureErrorCameraDenied;

  /// No description provided for @captureErrorScannerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The scanner couldn\'t start. Please try again.'**
  String get captureErrorScannerUnavailable;

  /// No description provided for @captureErrorStorage.
  ///
  /// In en, this message translates to:
  /// **'Your device storage isn\'t available right now. Please try again.'**
  String get captureErrorStorage;

  /// No description provided for @captureErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while scanning. Please try again.'**
  String get captureErrorUnknown;

  /// No description provided for @doneAction.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneAction;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review details'**
  String get reviewTitle;

  /// No description provided for @warningsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No warnings} =1{1 warning} other{{count} warnings}}'**
  String warningsCount(int count);

  /// No description provided for @savingLabel.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get savingLabel;

  /// No description provided for @savedTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice saved'**
  String get savedTitle;

  /// No description provided for @saveFailedNotice.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Your edits are kept. Try again.'**
  String get saveFailedNotice;

  /// No description provided for @draftNotSavedNotice.
  ///
  /// In en, this message translates to:
  /// **'Your latest edits haven\'t been saved yet.'**
  String get draftNotSavedNotice;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
