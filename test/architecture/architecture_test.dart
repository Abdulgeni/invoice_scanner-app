@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

/// Static rules over the source tree. They fail with the offending file, so
/// a rule that is broken by a new change is found immediately. Run from the
/// project root, as `flutter test` does.

const String domainDir = 'lib/features/invoice_scanner/domain';
const String dataDir = 'lib/features/invoice_scanner/data';
const String presentationDir = 'lib/features/invoice_scanner/presentation';

String norm(String path) => path.replaceAll('\\', '/');

List<File> dartFiles(String dir) {
  final Directory d = Directory(dir);
  if (!d.existsSync()) return <File>[];
  return d.listSync(recursive: true).whereType<File>().where((File f) {
    final String p = norm(f.path);
    return p.endsWith('.dart') && !p.endsWith('.g.dart');
  }).toList();
}

String stripComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//.*'), '');

final RegExp _import = RegExp(
  r'''^\s*import\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

Iterable<String> importsOf(File f) => _import
    .allMatches(f.readAsStringSync())
    .map((RegExpMatch m) => m.group(1)!);

List<String> importViolations(
  Iterable<File> files,
  bool Function(String import) forbidden,
) {
  return <String>[
    for (final File f in files)
      for (final String i in importsOf(f))
        if (forbidden(i)) '${norm(f.path)} imports $i',
  ];
}

List<String> patternViolations(
  Iterable<File> files,
  RegExp pattern, {
  bool stripFirst = true,
}) {
  return <String>[
    for (final File f in files)
      for (final RegExpMatch m in pattern.allMatches(
        stripFirst ? stripComments(f.readAsStringSync()) : f.readAsStringSync(),
      ))
        '${norm(f.path)}: ${m.group(0)}',
  ];
}

void expectNone(List<String> violations) =>
    expect(violations, isEmpty, reason: '\n${violations.join('\n')}');

void main() {
  final List<File> allLib = dartFiles('lib');
  final List<File> nonL10nLib = allLib
      .where((File f) => !norm(f.path).startsWith('lib/l10n/'))
      .toList();
  final List<File> domain = <File>[
    ...dartFiles(domainDir),
    ...dartFiles('lib/core/async'),
    ...dartFiles('lib/core/util'),
  ];
  final List<File> presentation = dartFiles(presentationDir);
  final List<File> data = dartFiles(dataDir);
  final List<File> ui = <File>[
    ...presentation,
    ...dartFiles('lib/core/design_system'),
    ...dartFiles('lib/core/theme'),
    ...dartFiles('lib/app'),
  ];

  group('layers', () {
    test('domain depends only on plain Dart and itself', () {
      const List<String> forbidden = <String>[
        'package:flutter/',
        'package:drift',
        'package:firebase',
        'package:cunning_document_scanner',
        'package:image/',
        'package:path_provider',
        'package:connectivity_plus',
        'package:intl',
        'dart:io',
        'dart:ui',
        'dart:isolate',
        '/data/',
        '/presentation/',
        'package:invoice_scanner/app/',
      ];
      expectNone(
        importViolations(domain, (String i) => forbidden.any(i.contains)),
      );
    });

    test('domain never uses double or reads the clock', () {
      expectNone(patternViolations(domain, RegExp(r'\bdouble\b')));
      expectNone(
        patternViolations(domain, RegExp(r'DateTime\.(now|timestamp)\(')),
      );
    });

    test('presentation never imports the data layer', () {
      expectNone(
        importViolations(
          presentation,
          (String i) =>
              i.contains('/features/invoice_scanner/data/') ||
              i.contains('package:drift') ||
              i.contains('package:firebase') ||
              i.contains('package:cunning_document_scanner'),
        ),
      );
    });

    test('the data layer knows no widgets', () {
      expectNone(
        importViolations(
          data,
          (String i) =>
              i == 'package:flutter/material.dart' ||
              i == 'package:flutter/widgets.dart' ||
              i == 'package:flutter/cupertino.dart',
        ),
      );
    });

    test('capture knows nothing about extraction, and the reverse', () {
      final List<File> capture = <File>[
        ...dartFiles('$dataDir/image'),
        File('$dataDir/datasources/document_scanner_datasource.dart'),
      ];
      expectNone(
        importViolations(
          capture,
          (String i) => i.contains('/data/gemini/') || i.contains('firebase'),
        ),
      );
      final List<File> extraction = <File>[
        ...dartFiles('$dataDir/gemini'),
        File('$dataDir/datasources/gemini_invoice_extractor.dart'),
      ];
      expectNone(
        importViolations(
          extraction,
          (String i) =>
              i.contains('/data/image/') ||
              i.contains('cunning_document_scanner') ||
              i.contains('document_scanner_datasource'),
        ),
      );
    });
  });

  group('SDK confinement', () {
    List<String> outsideAllowlist(String prefix, Set<String> allowed) {
      return <String>[
        for (final File f in nonL10nLib)
          if (importsOf(f).any((String i) => i.startsWith(prefix)) &&
              !allowed.contains(norm(f.path)))
            '${norm(f.path)} imports $prefix*',
      ];
    }

    test('Firebase is imported only where it is meant to be', () {
      expectNone(
        outsideAllowlist('package:firebase_', <String>{
          'lib/app/firebase_bootstrap.dart',
          'lib/firebase_options.dart',
          '$dataDir/auth/anonymous_auth_gate.dart',
          '$dataDir/gemini/firebase_ai_model_invoker.dart',
          '$dataDir/gemini/gemini_error_classifier.dart',
          '$dataDir/gemini/invoice_extraction_schema.dart',
          '$dataDir/gemini/model_name_resolver.dart',
        }),
      );
    });

    test('the scanner plugin is imported only by its two adapters', () {
      expectNone(
        outsideAllowlist('package:cunning_document_scanner', <String>{
          '$dataDir/datasources/document_scanner_datasource.dart',
          '$dataDir/image/managed_image_store.dart',
        }),
      );
    });

    test('Drift is imported only inside the data layer', () {
      expectNone(<String>[
        for (final File f in nonL10nLib)
          if (importsOf(f).any((String i) => i.startsWith('package:drift')) &&
              !norm(f.path).startsWith('$dataDir/'))
            norm(f.path),
      ]);
    });
  });

  group('privacy and security', () {
    test('nothing prints or logs except guarded debug output', () {
      expectNone(patternViolations(nonL10nLib, RegExp(r'(?<![\w.])print\(')));
      expectNone(patternViolations(nonL10nLib, RegExp(r'developer\.log\(')));

      const Set<String> debugPrintAllowed = <String>{
        'lib/app/app_composition.dart',
        'lib/app/firebase_bootstrap.dart',
      };
      final List<String> bad = <String>[];
      for (final File f in nonL10nLib) {
        final List<String> lines = f.readAsStringSync().split('\n');
        for (int i = 0; i < lines.length; i++) {
          if (!lines[i].contains('debugPrint(')) continue;
          final String window = lines
              .sublist(math.max(0, i - 3), i + 1)
              .join('\n');
          if (!debugPrintAllowed.contains(norm(f.path)) ||
              !window.contains('kDebugMode')) {
            bad.add('${norm(f.path)}:${i + 1}');
          }
        }
      }
      expectNone(bad);
    });

    test('no provider API key is embedded in source', () {
      final RegExp key = RegExp(r'AIza[0-9A-Za-z_\-]{20,}');
      expectNone(
        patternViolations(
          nonL10nLib.where(
            (File f) => norm(f.path) != 'lib/firebase_options.dart',
          ),
          key,
          stripFirst: false,
        ),
      );
      expectNone(
        patternViolations(
          nonL10nLib,
          RegExp(r'generativelanguage\.googleapis\.com'),
          stripFirst: false,
        ),
      );
    });

    test('forbidden packages stay out of pubspec.yaml', () {
      final String pubspec = File('pubspec.yaml').readAsStringSync();
      final RegExp forbidden = RegExp(
        r'^\s{2}(google_generative_ai|firebase_vertexai|image_picker|image_cropper|ack|ack_firebase_ai)\s*:',
        multiLine: true,
      );
      expectNone(
        forbidden
            .allMatches(pubspec)
            .map((RegExpMatch m) => m.group(1)!)
            .toList(),
      );
    });
  });

  group('interface text and layout rules', () {
    test('no user-visible text is hard-coded outside the ARB', () {
      final RegExp literalText = RegExp(
        r"""\bText\(\s*(?:const\s+)?'[^'$]*[A-Za-z]{3}""",
      );
      final RegExp literalLabel = RegExp(
        r"""\b(?:tooltip|labelText|hintText|helperText|errorText|semanticLabel|semanticsLabel)\s*:\s*'[^'$]*[A-Za-z]{3}""",
      );
      final List<File> files = <File>[
        ...presentation,
        ...dartFiles('lib/core/design_system'),
      ];
      expectNone(patternViolations(files, literalText));
      expectNone(patternViolations(files, literalLabel));
    });

    test('every ARB message is used somewhere', () {
      final Map<String, dynamic> arb =
          jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
      final String usage = nonL10nLib
          .map((File f) => f.readAsStringSync())
          .join('\n');
      final List<String> unused = <String>[
        for (final String key in arb.keys)
          if (!key.startsWith('@') && !RegExp('\\.$key\\b').hasMatch(usage))
            key,
      ];
      expectNone(unused);
    });

    test('layout is directional: nothing assumes left-to-right', () {
      final RegExp ltr = RegExp(
        r'EdgeInsets\.(?:only|fromLTRB)\(|'
        r'Alignment\.(?:topLeft|topRight|centerLeft|centerRight|bottomLeft|bottomRight)\b|'
        r'\bPositioned\(|'
        r'TextAlign\.(?:left|right)\b|'
        r'BorderRadius\.only\(|'
        r'Icons\.(?:arrow_back|arrow_forward|chevron_left|chevron_right|navigate_before|navigate_next)\b',
      );
      expectNone(patternViolations(ui, ltr));
    });
  });
}
