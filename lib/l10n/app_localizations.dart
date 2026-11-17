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

  /// Module 6 will replace this with an offline-queue promise once that queue ships.
  ///
  /// In en, this message translates to:
  /// **'You appear to be offline. Your scan is saved, so you can try again once you\'re back online.'**
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

  /// No description provided for @capturedPagesLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page} other{{count} pages}}'**
  String capturedPagesLabel(int count);

  /// No description provided for @capturedInvoiceSemantics.
  ///
  /// In en, this message translates to:
  /// **'Captured invoice, {pages}'**
  String capturedInvoiceSemantics(String pages);

  /// No description provided for @stageStepCounter.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stageStepCounter(int current, int total);

  /// No description provided for @stageSemantics.
  ///
  /// In en, this message translates to:
  /// **'{step}, {label}'**
  String stageSemantics(String step, String label);

  /// No description provided for @errorTitleNetwork.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get errorTitleNetwork;

  /// No description provided for @errorTitleTimeout.
  ///
  /// In en, this message translates to:
  /// **'That took too long'**
  String get errorTitleTimeout;

  /// No description provided for @errorTitleQuota.
  ///
  /// In en, this message translates to:
  /// **'Scanning limit reached'**
  String get errorTitleQuota;

  /// No description provided for @errorTitleAppCheck.
  ///
  /// In en, this message translates to:
  /// **'Update needed'**
  String get errorTitleAppCheck;

  /// No description provided for @errorTitleSafety.
  ///
  /// In en, this message translates to:
  /// **'This image can\'t be used'**
  String get errorTitleSafety;

  /// No description provided for @errorTitleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to read here'**
  String get errorTitleEmpty;

  /// No description provided for @errorTitleMalformed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t make sense of it'**
  String get errorTitleMalformed;

  /// No description provided for @errorTitleNotInvoice.
  ///
  /// In en, this message translates to:
  /// **'This doesn\'t look like an invoice'**
  String get errorTitleNotInvoice;

  /// No description provided for @errorTitleCancelled.
  ///
  /// In en, this message translates to:
  /// **'Scan cancelled'**
  String get errorTitleCancelled;

  /// No description provided for @errorTitleUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitleUnknown;

  /// No description provided for @reviewSectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get reviewSectionDetails;

  /// No description provided for @reviewSectionLines.
  ///
  /// In en, this message translates to:
  /// **'Line items'**
  String get reviewSectionLines;

  /// No description provided for @reviewSectionTotals.
  ///
  /// In en, this message translates to:
  /// **'Totals'**
  String get reviewSectionTotals;

  /// No description provided for @vendorLabel.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get vendorLabel;

  /// No description provided for @invoiceNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice number'**
  String get invoiceNumberLabel;

  /// No description provided for @invoiceDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get invoiceDateLabel;

  /// No description provided for @dateNotSet.
  ///
  /// In en, this message translates to:
  /// **'Select a date'**
  String get dateNotSet;

  /// No description provided for @currencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currencyLabel;

  /// No description provided for @currencyPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose currency'**
  String get currencyPickerTitle;

  /// No description provided for @currencyCustomLabel.
  ///
  /// In en, this message translates to:
  /// **'Other currency code'**
  String get currencyCustomLabel;

  /// No description provided for @currencyUseCode.
  ///
  /// In en, this message translates to:
  /// **'Use code'**
  String get currencyUseCode;

  /// No description provided for @subtotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotalLabel;

  /// No description provided for @taxLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get taxLabel;

  /// No description provided for @totalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// No description provided for @lineNumberTitle.
  ///
  /// In en, this message translates to:
  /// **'Line {number}'**
  String lineNumberTitle(int number);

  /// No description provided for @lineDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get lineDescriptionLabel;

  /// No description provided for @lineQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get lineQuantityLabel;

  /// No description provided for @lineUnitPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get lineUnitPriceLabel;

  /// No description provided for @lineTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Line total'**
  String get lineTotalLabel;

  /// No description provided for @addLineAction.
  ///
  /// In en, this message translates to:
  /// **'Add line'**
  String get addLineAction;

  /// No description provided for @removeLineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove line {number}'**
  String removeLineTooltip(int number);

  /// No description provided for @lineRemovedNotice.
  ///
  /// In en, this message translates to:
  /// **'Line {number} removed'**
  String lineRemovedNotice(int number);

  /// No description provided for @undoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoAction;

  /// No description provided for @lineItemsSumLabel.
  ///
  /// In en, this message translates to:
  /// **'Items add up to'**
  String get lineItemsSumLabel;

  /// No description provided for @lineItemsSumUnknown.
  ///
  /// In en, this message translates to:
  /// **'Fill in every line total to see the sum'**
  String get lineItemsSumUnknown;

  /// No description provided for @validationTooManyDecimals.
  ///
  /// In en, this message translates to:
  /// **'Use at most {digits} decimal places.'**
  String validationTooManyDecimals(int digits);

  /// No description provided for @validationWholeNumberOnly.
  ///
  /// In en, this message translates to:
  /// **'Use a whole number.'**
  String get validationWholeNumberOnly;

  /// No description provided for @validationNumberTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That number is too large.'**
  String get validationNumberTooLarge;

  /// No description provided for @saveBlockedInvalid.
  ///
  /// In en, this message translates to:
  /// **'Fix the highlighted fields to save.'**
  String get saveBlockedInvalid;

  /// No description provided for @scanPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Your scan'**
  String get scanPanelTitle;

  /// No description provided for @scanPanelHide.
  ///
  /// In en, this message translates to:
  /// **'Hide scan'**
  String get scanPanelHide;

  /// No description provided for @scanPanelShow.
  ///
  /// In en, this message translates to:
  /// **'Show scan'**
  String get scanPanelShow;

  /// No description provided for @scanPanelFullScreen.
  ///
  /// In en, this message translates to:
  /// **'View full screen'**
  String get scanPanelFullScreen;

  /// No description provided for @noteWarningPrefix.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get noteWarningPrefix;

  /// No description provided for @noteInfoPrefix.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteInfoPrefix;

  /// No description provided for @dismissUnreadableAction.
  ///
  /// In en, this message translates to:
  /// **'It\'s empty'**
  String get dismissUnreadableAction;

  /// No description provided for @confirmCurrencyAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm {currency}'**
  String confirmCurrencyAction(String currency);

  /// No description provided for @fixSetSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Set subtotal to {value}'**
  String fixSetSubtotal(String value);

  /// No description provided for @fixSetTax.
  ///
  /// In en, this message translates to:
  /// **'Set tax to {value}'**
  String fixSetTax(String value);

  /// No description provided for @fixSetTotal.
  ///
  /// In en, this message translates to:
  /// **'Set total to {value}'**
  String fixSetTotal(String value);

  /// No description provided for @hintDiscount.
  ///
  /// In en, this message translates to:
  /// **'A discount could explain this.'**
  String get hintDiscount;

  /// No description provided for @hintExtraCharge.
  ///
  /// In en, this message translates to:
  /// **'Shipping or fees could explain this.'**
  String get hintExtraCharge;

  /// No description provided for @warningCurrencyAssumed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t tell the currency, so we used {currency}. Please check it.'**
  String warningCurrencyAssumed(String currency);

  /// No description provided for @warningCurrencyInconsistent.
  ///
  /// In en, this message translates to:
  /// **'This amount is in a different currency than the invoice.'**
  String get warningCurrencyInconsistent;

  /// No description provided for @warningUnreadable.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read this value exactly. Enter it, or confirm it\'s empty.'**
  String get warningUnreadable;

  /// No description provided for @warningUnreadableLines.
  ///
  /// In en, this message translates to:
  /// **'Some line items couldn\'t be read exactly. Check them against your scan.'**
  String get warningUnreadableLines;

  /// No description provided for @warningMissingVendor.
  ///
  /// In en, this message translates to:
  /// **'No vendor found.'**
  String get warningMissingVendor;

  /// No description provided for @warningMissingDate.
  ///
  /// In en, this message translates to:
  /// **'No date found.'**
  String get warningMissingDate;

  /// No description provided for @warningMissingTotal.
  ///
  /// In en, this message translates to:
  /// **'No total found.'**
  String get warningMissingTotal;

  /// No description provided for @warningMissingSubtotal.
  ///
  /// In en, this message translates to:
  /// **'No subtotal found.'**
  String get warningMissingSubtotal;

  /// No description provided for @warningMissingTax.
  ///
  /// In en, this message translates to:
  /// **'No tax found.'**
  String get warningMissingTax;

  /// No description provided for @warningMissingLineDescription.
  ///
  /// In en, this message translates to:
  /// **'No description.'**
  String get warningMissingLineDescription;

  /// No description provided for @warningMissingLineTotal.
  ///
  /// In en, this message translates to:
  /// **'No amount for this line.'**
  String get warningMissingLineTotal;

  /// No description provided for @warningNoLineItems.
  ///
  /// In en, this message translates to:
  /// **'No line items were found.'**
  String get warningNoLineItems;

  /// No description provided for @warningFutureDate.
  ///
  /// In en, this message translates to:
  /// **'This date is in the future.'**
  String get warningFutureDate;

  /// No description provided for @warningOldDate.
  ///
  /// In en, this message translates to:
  /// **'This date is quite old.'**
  String get warningOldDate;

  /// No description provided for @warningZeroTotal.
  ///
  /// In en, this message translates to:
  /// **'The total is zero.'**
  String get warningZeroTotal;

  /// No description provided for @warningNegativeAmount.
  ///
  /// In en, this message translates to:
  /// **'This amount is negative, which is normal for a credit note.'**
  String get warningNegativeAmount;

  /// No description provided for @warningLineMathMismatch.
  ///
  /// In en, this message translates to:
  /// **'Quantity times unit price is {expected}, but this line says {actual}.'**
  String warningLineMathMismatch(String expected, String actual);

  /// No description provided for @warningLineSumMismatch.
  ///
  /// In en, this message translates to:
  /// **'The line items add up to {expected}, but this says {actual}. {hint}'**
  String warningLineSumMismatch(String expected, String actual, String hint);

  /// No description provided for @warningTotalMismatchSum.
  ///
  /// In en, this message translates to:
  /// **'Subtotal plus tax is {expected}, but the total says {actual}. {hint}'**
  String warningTotalMismatchSum(String expected, String actual, String hint);

  /// No description provided for @savedScanAnother.
  ///
  /// In en, this message translates to:
  /// **'Scan another'**
  String get savedScanAnother;

  /// No description provided for @savedSummary.
  ///
  /// In en, this message translates to:
  /// **'{vendor} · {total}'**
  String savedSummary(String vendor, String total);

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get historyTitle;

  /// No description provided for @historyViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get historyViewAll;

  /// No description provided for @historyAttentionTitle.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get historyAttentionTitle;

  /// No description provided for @historySavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get historySavedTitle;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No invoices yet'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Scan an invoice from the home screen and it will show up here.'**
  String get historyEmptyBody;

  /// No description provided for @historyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your invoices.'**
  String get historyLoadFailed;

  /// No description provided for @historyUnreadInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice scan'**
  String get historyUnreadInvoice;

  /// No description provided for @historyContinueHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to continue'**
  String get historyContinueHint;

  /// No description provided for @statusNotRead.
  ///
  /// In en, this message translates to:
  /// **'Not read yet'**
  String get statusNotRead;

  /// No description provided for @statusReading.
  ///
  /// In en, this message translates to:
  /// **'Reading…'**
  String get statusReading;

  /// No description provided for @statusNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get statusNeedsReview;

  /// No description provided for @statusSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get statusSaved;

  /// No description provided for @deleteInvoiceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}'**
  String deleteInvoiceTooltip(String name);

  /// No description provided for @deleteInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this invoice?'**
  String get deleteInvoiceTitle;

  /// No description provided for @deleteInvoiceBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes the invoice and its images from this device. It can\'t be undone.'**
  String get deleteInvoiceBody;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @deleteFailedNotice.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete. Please try again.'**
  String get deleteFailedNotice;

  /// No description provided for @invoiceDeletedNotice.
  ///
  /// In en, this message translates to:
  /// **'Invoice deleted'**
  String get invoiceDeletedNotice;

  /// No description provided for @privacyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Data and privacy'**
  String get privacyTooltip;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get privacyTitle;

  /// No description provided for @privacyOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Saved invoices stay on this device. Nothing is synced to an account.'**
  String get privacyOnDevice;

  /// No description provided for @privacyScanImages.
  ///
  /// In en, this message translates to:
  /// **'To read an invoice, its page images are sent over an encrypted connection to an AI service. This app doesn\'t keep them after you save or discard the scan.'**
  String get privacyScanImages;

  /// No description provided for @privacyRetention.
  ///
  /// In en, this message translates to:
  /// **'Page images are deleted as soon as you save or discard a scan. Scans you haven\'t finished stay here until you do.'**
  String get privacyRetention;

  /// No description provided for @privacyDelete.
  ///
  /// In en, this message translates to:
  /// **'Deleting an invoice erases its data and images from this device right away.'**
  String get privacyDelete;

  /// No description provided for @detailTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get detailTitle;

  /// No description provided for @detailQuantityTimesPrice.
  ///
  /// In en, this message translates to:
  /// **'{quantity} × {price}'**
  String detailQuantityTimesPrice(String quantity, String price);

  /// No description provided for @detailNoLines.
  ///
  /// In en, this message translates to:
  /// **'No line items were saved.'**
  String get detailNoLines;

  /// No description provided for @detailNothingToShow.
  ///
  /// In en, this message translates to:
  /// **'This invoice has no details to show.'**
  String get detailNothingToShow;
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
