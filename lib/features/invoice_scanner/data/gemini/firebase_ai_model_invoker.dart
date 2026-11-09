import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import 'package:invoice_scanner/features/invoice_scanner/data/gemini/invoice_extraction_schema.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/gemini/model_invoker.dart';

/// The only code that talks to `firebase_ai` model objects.
class FirebaseAiModelInvoker {
  FirebaseAiModelInvoker({required FirebaseAI Function() backend})
      : _backend = backend;

  final FirebaseAI Function() _backend;

  /// Pass `invoker.call` where a [ModelInvoker] is expected.
  Future<GeminiRawResult> call({
    required String modelName,
    required List<Uint8List> jpegPages,
  }) async {
    final GenerativeModel model = _backend().generativeModel(
      model: modelName,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: buildInvoiceSchema(),
      ),
      systemInstruction: Content.system(invoiceSystemInstruction),
    );

    final List<Part> parts = <Part>[const TextPart(invoicePagePrompt)];
    for (int i = 0; i < jpegPages.length; i++) {
      parts.add(TextPart('Page ${i + 1} of ${jpegPages.length}:'));
      parts.add(InlineDataPart('image/jpeg', jpegPages[i]));
    }

    final GenerateContentResponse response = await model.generateContent(
      <Content>[Content.multi(parts)],
    );
    final List<Candidate> candidates = response.candidates;
    return GeminiRawResult(
      text: response.text,
      blockReason: response.promptFeedback?.blockReason?.name,
      finishReason:
          candidates.isEmpty ? null : candidates.first.finishReason?.name,
    );
  }
}
