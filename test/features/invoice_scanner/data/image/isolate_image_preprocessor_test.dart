import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:invoice_scanner/core/async/cancellation_token.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/image/isolate_image_preprocessor.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/debug_codes.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/failures/invoice_failure.dart';

import '../../../../support/image_fixtures.dart';

void main() {
  late Directory temp;
  late Directory out;
  late CancellationToken cancel;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('invoice_pre_test');
    out = Directory('${temp.path}${Platform.pathSeparator}out');
    cancel = CancellationToken();
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  String writeSource(String name, Uint8List bytes) {
    final File file = File('${temp.path}${Platform.pathSeparator}$name')
      ..writeAsBytesSync(bytes);
    return file.path;
  }

  String upright(String name) => writeSource(
    name,
    Uint8List.fromList(img.encodeJpg(uprightQuadrants(300, 200))),
  );

  List<String> outFiles() => out.existsSync()
      ? out.listSync().map((FileSystemEntity e) => e.path).toList()
      : <String>[];

  Matcher failsWith(String code) => throwsA(
    isA<InvoiceFailure>()
        .having((InvoiceFailure f) => f.kind, 'kind', InvoiceErrorKind.unknown)
        .having((InvoiceFailure f) => f.debugCode, 'debugCode', code),
  );

  Future<void> settle() => Future<void>.delayed(const Duration(seconds: 2));

  test('compresses pages in order, with names from id and index', () async {
    final IsolateImagePreprocessor pre = IsolateImagePreprocessor(
      outputDir: out,
    );
    final List<String> paths = await pre.compress(
      invoiceId: 'abc-123',
      sourcePaths: <String>[
        upright('a.jpg'),
        upright('b.jpg'),
        upright('c.jpg'),
      ],
      cancel: cancel,
    );
    expect(
      paths.map((String p) => p.split(Platform.pathSeparator).last),
      <String>['abc-123_0.jpg', 'abc-123_1.jpg', 'abc-123_2.jpg'],
    );
    for (final String path in paths) {
      final img.Image decoded = img.decodeJpg(File(path).readAsBytesSync())!;
      expect(quadrantsOf(decoded), 'RGBY');
    }
    expect(outFiles(), hasLength(3));
    expect(() => paths.add('x'), throwsUnsupportedError);
  });

  test('a repeat run overwrites instead of leaking files', () async {
    final IsolateImagePreprocessor pre = IsolateImagePreprocessor(
      outputDir: out,
    );
    final String source = upright('a.jpg');
    for (int i = 0; i < 2; i++) {
      await pre.compress(
        invoiceId: 'same',
        sourcePaths: <String>[source],
        cancel: cancel,
      );
    }
    expect(outFiles(), hasLength(1));
  });

  test('no temp files remain after success', () async {
    final IsolateImagePreprocessor pre = IsolateImagePreprocessor(
      outputDir: out,
    );
    await pre.compress(
      invoiceId: 'x',
      sourcePaths: <String>[upright('a.jpg')],
      cancel: cancel,
    );
    expect(outFiles().where((String p) => p.endsWith('.tmp')), isEmpty);
  });

  test('a corrupt page fails and removes the pages already written', () async {
    final IsolateImagePreprocessor pre = IsolateImagePreprocessor(
      outputDir: out,
    );
    final String bad = writeSource(
      'bad.jpg',
      Uint8List.fromList(<int>[1, 2, 3]),
    );
    await expectLater(
      pre.compress(
        invoiceId: 'x',
        sourcePaths: <String>[upright('a.jpg'), bad],
        cancel: cancel,
      ),
      failsWith(DebugCodes.decodeFailed),
    );
    expect(outFiles(), isEmpty);
  });

  test('a missing source fails with io_failed', () async {
    final IsolateImagePreprocessor pre = IsolateImagePreprocessor(
      outputDir: out,
    );
    await expectLater(
      pre.compress(
        invoiceId: 'x',
        sourcePaths: <String>['${temp.path}/does-not-exist.jpg'],
        cancel: cancel,
      ),
      failsWith(DebugCodes.ioFailed),
    );
  });

  test('an oversized source fails without being decoded', () async {
    final IsolateImagePreprocessor pre = IsolateImagePreprocessor(
      outputDir: out,
      maxSourceBytes: 10,
    );
    await expectLater(
      pre.compress(
        invoiceId: 'x',
        sourcePaths: <String>[upright('a.jpg')],
        cancel: cancel,
      ),
      failsWith(DebugCodes.decodeFailed),
    );
    expect(outFiles(), isEmpty);
  });

  test('an unsafe invoice id is rejected before touching the disk', () async {
    final IsolateImagePreprocessor pre = IsolateImagePreprocessor(
      outputDir: out,
    );
    for (final String id in <String>['../evil', 'a/b', '', 'a b']) {
      await expectLater(
        pre.compress(
          invoiceId: id,
          sourcePaths: <String>[upright('a.jpg')],
          cancel: cancel,
        ),
        failsWith(DebugCodes.ioFailed),
        reason: id,
      );
    }
    expect(out.existsSync(), isFalse);
  });

  test('an empty page list is rejected', () async {
    final IsolateImagePreprocessor pre = IsolateImagePreprocessor(
      outputDir: out,
    );
    await expectLater(
      pre.compress(
        invoiceId: 'x',
        sourcePaths: const <String>[],
        cancel: cancel,
      ),
      failsWith(DebugCodes.ioFailed),
    );
  });

  test('a token cancelled up front writes nothing', () async {
    final IsolateImagePreprocessor pre = IsolateImagePreprocessor(
      outputDir: out,
    );
    cancel.cancel();
    await expectLater(
      pre.compress(
        invoiceId: 'x',
        sourcePaths: <String>[upright('a.jpg')],
        cancel: cancel,
      ),
      throwsA(isA<CancelledException>()),
    );
    expect(outFiles(), isEmpty);
  });

  test('cancelling mid-flight deletes a page that finishes late', () async {
    final IsolateImagePreprocessor pre = IsolateImagePreprocessor(
      outputDir: out,
    );
    final Future<List<String>> pending = pre.compress(
      invoiceId: 'x',
      sourcePaths: <String>[upright('a.jpg'), upright('b.jpg')],
      cancel: cancel,
    );
    cancel.cancel();
    await expectLater(pending, throwsA(isA<CancelledException>()));
    await settle();
    expect(outFiles(), isEmpty);
  });
}
