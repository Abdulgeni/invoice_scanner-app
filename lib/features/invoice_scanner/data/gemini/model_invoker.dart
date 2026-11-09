import 'dart:typed_data';

/// What the extractor needs from one model call, with no SDK types.
final class GeminiRawResult {
  const GeminiRawResult({this.text, this.blockReason, this.finishReason});

  /// The model's text (JSON), if any.
  final String? text;

  /// Non-null when the prompt was blocked. The value is an enum name only.
  final String? blockReason;

  /// The first candidate's finish reason as an enum name, for example
  /// `stop`, `maxTokens`, `safety`.
  final String? finishReason;
}

/// One model call: [jpegPages] in page order, with a specific model name.
typedef ModelInvoker =
    Future<GeminiRawResult> Function({
      required String modelName,
      required List<Uint8List> jpegPages,
    });
