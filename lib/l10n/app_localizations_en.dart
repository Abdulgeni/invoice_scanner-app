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
}
