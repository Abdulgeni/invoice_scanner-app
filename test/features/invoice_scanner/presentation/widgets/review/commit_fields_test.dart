import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/domain/value_objects/decimal_value.dart';
import 'package:invoice_scanner/features/invoice_scanner/presentation/widgets/review/commit_fields.dart';

import '../../../../../support/pump_app.dart';

DecimalValue d(String s) => DecimalValue.tryParse(s)!;

late List<DecimalValue?> commits;
late List<bool> validity;

Widget amount(DecimalValue? value) => Scaffold(
  body: Padding(
    padding: const EdgeInsets.all(16),
    child: AmountField(
      key: const ValueKey<String>('a'),
      label: 'Amount',
      value: value,
      seed: (DecimalValue v) => 'SEEDED $v',
      problemFor: (DecimalValue v) =>
          v.exactMinorUnits(2) == null ? AmountProblem.tooManyDecimals : null,
      maxFractionDigits: 2,
      exampleCanonical: '1234.50',
      onChanged: commits.add,
      onValidityChanged: validity.add,
    ),
  ),
);

String textOf(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  setUp(() {
    commits = <DecimalValue?>[];
    validity = <bool>[];
  });

  group('AmountField', () {
    testWidgets('a valid entry is committed', (tester) async {
      await pumpLocalized(tester, amount(null));
      await tester.enterText(find.byType(TextField), '12.5');
      expect(commits, <DecimalValue?>[d('12.5')]);
      expect(validity.last, isTrue);
    });

    testWidgets('clearing the field commits null', (tester) async {
      await pumpLocalized(tester, amount(d('5')));
      await tester.enterText(find.byType(TextField), '');
      expect(commits, <DecimalValue?>[null]);
    });

    testWidgets(
      'the parent echoing the user\'s value back does not rewrite it',
      (tester) async {
        await pumpLocalized(tester, amount(null));
        await tester.enterText(find.byType(TextField), '12.5');
        await pumpLocalized(tester, amount(d('12.5')));
        expect(textOf(tester), '12.5');
      },
    );

    testWidgets('a stale echo while typing is ignored', (tester) async {
      await pumpLocalized(tester, amount(null));
      await tester.enterText(find.byType(TextField), '12.5');
      await tester.enterText(find.byType(TextField), '12.51');
      await pumpLocalized(tester, amount(d('12.5')));
      expect(textOf(tester), '12.51');
    });

    testWidgets(
      'a different incoming value refills the field',
      skip: true, // TODO(module-13): reseed across pumpWidget
      (tester) async {
        await pumpLocalized(tester, amount(d('1')));
        await pumpLocalized(tester, amount(d('99')));
        expect(textOf(tester), 'SEEDED 99');
      },
    );

    testWidgets(
      'once the parent has caught up, an old value is external again',
      (tester) async {
        await pumpLocalized(tester, amount(null));
        await tester.enterText(find.byType(TextField), '5');
        await pumpLocalized(tester, amount(d('5')));
        await tester.enterText(find.byType(TextField), '6');
        await pumpLocalized(tester, amount(d('6')));
        await pumpLocalized(tester, amount(d('5')));
        expect(textOf(tester), 'SEEDED 5');
      },
    );

    testWidgets(
      'invalid text shows an error, reports invalid, commits nothing',
      (tester) async {
        await pumpLocalized(tester, amount(d('5')));
        await tester.enterText(find.byType(TextField), '1,2');
        await tester.pump();
        expect(
          find.text('Enter a valid number, for example 1234.50.'),
          findsOneWidget,
        );
        expect(validity.last, isFalse);
        expect(commits, isEmpty);

        await tester.enterText(find.byType(TextField), '12');
        await tester.pump();
        expect(find.textContaining('Enter a valid number'), findsNothing);
        expect(validity.last, isTrue);
        expect(commits, <DecimalValue?>[d('12')]);
      },
    );

    testWidgets('too many decimals is its own message', (tester) async {
      await pumpLocalized(tester, amount(null));
      await tester.enterText(find.byType(TextField), '12.345');
      await tester.pump();
      expect(find.text('Use at most 2 decimal places.'), findsOneWidget);
      expect(commits, isEmpty);
    });

    testWidgets('invalid text survives an echo of the last good value', (
      tester,
    ) async {
      await pumpLocalized(tester, amount(d('5')));
      await tester.enterText(find.byType(TextField), '1,2');
      await pumpLocalized(tester, amount(d('5')));
      expect(textOf(tester), '1,2');
    });

    testWidgets(
      'a fix while the text is invalid clears the error',
      skip: true, // TODO(module-13): reseed across pumpWidget
      (tester) async {
        await pumpLocalized(tester, amount(d('5')));
        await tester.enterText(find.byType(TextField), '1,2');
        await tester.pump();
        await pumpLocalized(tester, amount(d('9')));
        await tester.pump();
        expect(textOf(tester), 'SEEDED 9');
        expect(find.textContaining('Enter a valid number'), findsNothing);
        expect(validity.last, isTrue);
      },
    );

    testWidgets('a field that disappears while invalid reports valid', (
      tester,
    ) async {
      await pumpLocalized(tester, amount(null));
      await tester.enterText(find.byType(TextField), '1,2');
      await pumpLocalized(tester, const Scaffold(body: SizedBox()));
      expect(validity.last, isTrue);
    });
  });

  group('TextEntryField', () {
    late List<String?> values;
    Widget text(String? value) => Scaffold(
      body: TextEntryField(
        key: const ValueKey<String>('t'),
        label: 'Vendor',
        value: value,
        onChanged: values.add,
      ),
    );

    setUp(() => values = <String?>[]);

    testWidgets('trims and reports null for blank text', (tester) async {
      await pumpLocalized(tester, text('Acme'));
      await tester.enterText(find.byType(TextField), '  Beta  ');
      await tester.enterText(find.byType(TextField), '   ');
      expect(values, <String?>['Beta', null]);
    });

    testWidgets('echoes do not rewrite, external changes do', (tester) async {
      await pumpLocalized(tester, text('Acme'));
      await tester.enterText(find.byType(TextField), 'Ac');
      await tester.enterText(find.byType(TextField), 'Acm');
      await pumpLocalized(tester, text('Ac'));
      expect(textOf(tester), 'Acm');

      await pumpLocalized(tester, text('Acm'));
      await pumpLocalized(tester, text('Other'));
      expect(textOf(tester), 'Other');
    });
  });
}
