/// Fixed vocabulary for `InvoiceFailure.debugCode` in the Gemini layer.
/// Never build one of these from an error message.
abstract final class GeminiDebugCodes {
  static const String badPageCount = 'bad_page_count';
  static const String pageEmpty = 'page_empty';
  static const String modelUnavailable = 'model_unavailable';
  static const String promptBlocked = 'prompt_blocked';
  static const String finishBlocked = 'finish_blocked';
  static const String truncated = 'truncated';
  static const String emptyText = 'empty_text';
  static const String badJson = 'bad_json';
  static const String notInvoice = 'not_invoice';
  static const String configInvalidKey = 'config_invalid_key';
  static const String configApiDisabled = 'config_api_disabled';
  static const String unsupportedLocation = 'unsupported_location';
  static const String sdkError = 'sdk_error';
  static const String aiError = 'ai_error';
  static const String authRejected = 'auth_rejected';
  static const String quota = 'quota_exceeded';
  static const String serverUnavailable = 'server_unavailable';
  static const String serverError = 'server_error';
  static const String timeout = 'timeout';
  static const String ioError = 'io_error';
  static const String clientError = 'client_error';
}
