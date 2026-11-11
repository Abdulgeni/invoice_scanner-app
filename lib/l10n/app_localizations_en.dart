// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Invoice Scanner';

  @override
  String get homeLastInvoiceTotal => 'Last invoice total';

  @override
  String get scanAction => 'Scan';

  @override
  String get scanInvoiceSemantics => 'Scan invoice';

  @override
  String get importFromGallery => 'Import from gallery';

  @override
  String get retakeAction => 'Retake';

  @override
  String get retryAction => 'Try again';

  @override
  String get keepImageAction => 'Keep image';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get confirmAndSaveAction => 'Confirm & Save';

  @override
  String get stageOptimizing => 'Optimizing image';

  @override
  String get stageReading => 'Reading invoice';

  @override
  String get stageValidating => 'Checking totals';

  @override
  String get errorTitle => 'Couldn\'t read this invoice';

  @override
  String get errorNetwork =>
      'You appear to be offline. Your scan is saved, so you can try again once you\'re back online.';

  @override
  String get errorTimeout =>
      'This is taking longer than expected. Check your connection and try again.';

  @override
  String get errorQuotaExceeded =>
      'You\'ve reached the scanning limit for now. Please try again in a little while.';

  @override
  String get errorAppCheckFailed =>
      'We couldn\'t verify this copy of the app. Update it from the official app store and try again.';

  @override
  String get errorSafetyBlock =>
      'This image couldn\'t be processed. Try a clearer photo of the invoice.';

  @override
  String get errorEmptyResponse =>
      'We couldn\'t read anything from this image. Try again, or retake the photo in better light.';

  @override
  String get errorMalformedJson =>
      'We couldn\'t make sense of the result. Please try again.';

  @override
  String get errorNotAnInvoice =>
      'This doesn\'t look like an invoice. Retake the photo with the whole page in view.';

  @override
  String get errorCancelled => 'Scan cancelled.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';

  @override
  String pageLimitExceeded(int max) {
    return 'Invoices can have up to $max pages. Remove some pages and try again.';
  }

  @override
  String warningTotalMismatch(String lineSum, String total) {
    return 'The line items add up to $lineSum, but the total says $total.';
  }

  @override
  String validationInvalidNumber(String example) {
    return 'Enter a valid number, for example $example.';
  }

  @override
  String get scanInvoiceAction => 'Scan invoice';

  @override
  String get homeHeroTitle => 'Scan an invoice';

  @override
  String get homeHeroBody =>
      'Capture it, check the details, and save it in seconds.';

  @override
  String get homeTipsTitle => 'Scanning tips';

  @override
  String get recentInvoicesTitle => 'Recent invoices';

  @override
  String get recentInvoicesEmpty => 'Invoices you save will appear here.';

  @override
  String get invoiceUnnamed => 'Unnamed invoice';

  @override
  String get recentNoTotal => 'No total';

  @override
  String get recentNoDate => 'No date';

  @override
  String get guidanceTitle => 'Before you scan';

  @override
  String get guidanceLighting => 'Use even light and avoid glare or shadows.';

  @override
  String get guidanceFlat => 'Lay the page flat on a plain, dark surface.';

  @override
  String get guidanceFrame => 'Keep the whole page in the frame, edge to edge.';

  @override
  String guidanceMultiPage(int max) {
    return 'Long invoice? Scan up to $max pages, in order.';
  }

  @override
  String get guidanceStart => 'Open camera';

  @override
  String get previewTitle => 'Check your scan';

  @override
  String get previewHint => 'Make sure every line is readable. Pinch to zoom.';

  @override
  String previewPageCounter(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String previewPageSemantics(int current, int total) {
    return 'Invoice page $current of $total';
  }

  @override
  String get previewImageUnavailable => 'This page couldn\'t be shown.';

  @override
  String get readInvoiceAction => 'Read invoice';

  @override
  String get discardAction => 'Discard';

  @override
  String get discardConfirmTitle => 'Discard this scan?';

  @override
  String get discardConfirmBody => 'The captured pages will be deleted.';

  @override
  String get capturingOpening => 'Opening scanner…';

  @override
  String get captureErrorTitle => 'Couldn\'t scan';

  @override
  String get captureErrorCameraDenied =>
      'Camera access is turned off. Turn it on in your device settings to scan invoices.';

  @override
  String get captureErrorScannerUnavailable =>
      'The scanner couldn\'t start. Please try again.';

  @override
  String get captureErrorStorage =>
      'Your device storage isn\'t available right now. Please try again.';

  @override
  String get captureErrorUnknown =>
      'Something went wrong while scanning. Please try again.';

  @override
  String get doneAction => 'Done';

  @override
  String get reviewTitle => 'Review details';

  @override
  String warningsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count warnings',
      one: '1 warning',
      zero: 'No warnings',
    );
    return '$_temp0';
  }

  @override
  String get savingLabel => 'Saving…';

  @override
  String get savedTitle => 'Invoice saved';

  @override
  String get saveFailedNotice =>
      'Couldn\'t save. Your edits are kept. Try again.';

  @override
  String get draftNotSavedNotice =>
      'Your latest edits haven\'t been saved yet.';

  @override
  String capturedPagesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String capturedInvoiceSemantics(String pages) {
    return 'Captured invoice, $pages';
  }

  @override
  String stageStepCounter(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String stageSemantics(String step, String label) {
    return '$step, $label';
  }

  @override
  String get errorTitleNetwork => 'You\'re offline';

  @override
  String get errorTitleTimeout => 'That took too long';

  @override
  String get errorTitleQuota => 'Scanning limit reached';

  @override
  String get errorTitleAppCheck => 'Update needed';

  @override
  String get errorTitleSafety => 'This image can\'t be used';

  @override
  String get errorTitleEmpty => 'Nothing to read here';

  @override
  String get errorTitleMalformed => 'We couldn\'t make sense of it';

  @override
  String get errorTitleNotInvoice => 'This doesn\'t look like an invoice';

  @override
  String get errorTitleCancelled => 'Scan cancelled';

  @override
  String get errorTitleUnknown => 'Something went wrong';

  @override
  String get reviewSectionDetails => 'Details';

  @override
  String get reviewSectionLines => 'Line items';

  @override
  String get reviewSectionTotals => 'Totals';

  @override
  String get vendorLabel => 'Vendor';

  @override
  String get invoiceNumberLabel => 'Invoice number';

  @override
  String get invoiceDateLabel => 'Date';

  @override
  String get dateNotSet => 'Select a date';

  @override
  String get currencyLabel => 'Currency';

  @override
  String get currencyPickerTitle => 'Choose currency';

  @override
  String get currencyCustomLabel => 'Other currency code';

  @override
  String get currencyUseCode => 'Use code';

  @override
  String get subtotalLabel => 'Subtotal';

  @override
  String get taxLabel => 'Tax';

  @override
  String get totalLabel => 'Total';

  @override
  String lineNumberTitle(int number) {
    return 'Line $number';
  }

  @override
  String get lineDescriptionLabel => 'Description';

  @override
  String get lineQuantityLabel => 'Quantity';

  @override
  String get lineUnitPriceLabel => 'Unit price';

  @override
  String get lineTotalLabel => 'Line total';

  @override
  String get addLineAction => 'Add line';

  @override
  String removeLineTooltip(int number) {
    return 'Remove line $number';
  }

  @override
  String lineRemovedNotice(int number) {
    return 'Line $number removed';
  }

  @override
  String get undoAction => 'Undo';

  @override
  String get lineItemsSumLabel => 'Items add up to';

  @override
  String get lineItemsSumUnknown => 'Fill in every line total to see the sum';

  @override
  String validationTooManyDecimals(int digits) {
    return 'Use at most $digits decimal places.';
  }

  @override
  String get validationWholeNumberOnly => 'Use a whole number.';

  @override
  String get validationNumberTooLarge => 'That number is too large.';

  @override
  String get saveBlockedInvalid => 'Fix the highlighted fields to save.';

  @override
  String get scanPanelTitle => 'Your scan';

  @override
  String get scanPanelHide => 'Hide scan';

  @override
  String get scanPanelShow => 'Show scan';

  @override
  String get scanPanelFullScreen => 'View full screen';

  @override
  String get noteWarningPrefix => 'Warning';

  @override
  String get noteInfoPrefix => 'Note';

  @override
  String get dismissUnreadableAction => 'It\'s empty';

  @override
  String confirmCurrencyAction(String currency) {
    return 'Confirm $currency';
  }

  @override
  String fixSetSubtotal(String value) {
    return 'Set subtotal to $value';
  }

  @override
  String fixSetTax(String value) {
    return 'Set tax to $value';
  }

  @override
  String fixSetTotal(String value) {
    return 'Set total to $value';
  }

  @override
  String get hintDiscount => 'A discount could explain this.';

  @override
  String get hintExtraCharge => 'Shipping or fees could explain this.';

  @override
  String warningCurrencyAssumed(String currency) {
    return 'We couldn\'t tell the currency, so we used $currency. Please check it.';
  }

  @override
  String get warningCurrencyInconsistent =>
      'This amount is in a different currency than the invoice.';

  @override
  String get warningUnreadable =>
      'We couldn\'t read this value exactly. Enter it, or confirm it\'s empty.';

  @override
  String get warningUnreadableLines =>
      'Some line items couldn\'t be read exactly. Check them against your scan.';

  @override
  String get warningMissingVendor => 'No vendor found.';

  @override
  String get warningMissingDate => 'No date found.';

  @override
  String get warningMissingTotal => 'No total found.';

  @override
  String get warningMissingSubtotal => 'No subtotal found.';

  @override
  String get warningMissingTax => 'No tax found.';

  @override
  String get warningMissingLineDescription => 'No description.';

  @override
  String get warningMissingLineTotal => 'No amount for this line.';

  @override
  String get warningNoLineItems => 'No line items were found.';

  @override
  String get warningFutureDate => 'This date is in the future.';

  @override
  String get warningOldDate => 'This date is quite old.';

  @override
  String get warningZeroTotal => 'The total is zero.';

  @override
  String get warningNegativeAmount =>
      'This amount is negative, which is normal for a credit note.';

  @override
  String warningLineMathMismatch(String expected, String actual) {
    return 'Quantity times unit price is $expected, but this line says $actual.';
  }

  @override
  String warningLineSumMismatch(String expected, String actual, String hint) {
    return 'The line items add up to $expected, but this says $actual. $hint';
  }

  @override
  String warningTotalMismatchSum(String expected, String actual, String hint) {
    return 'Subtotal plus tax is $expected, but the total says $actual. $hint';
  }

  @override
  String get savedScanAnother => 'Scan another';

  @override
  String savedSummary(String vendor, String total) {
    return '$vendor · $total';
  }
}
