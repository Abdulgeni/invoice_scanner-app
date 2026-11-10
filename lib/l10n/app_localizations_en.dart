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
      'You appear to be offline. Connect to the internet and try again.';

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
}
