import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_scanner/features/invoice_scanner/data/image/managed_image_store.dart';

void main() {
  late Directory temp;
  late Directory managed;
  late int cleanCalls;
  late Object? cleanError;
  late ManagedImageStore store;

  File put(String name, {String content = 'data'}) =>
      File('${managed.path}${Platform.pathSeparator}$name')
        ..writeAsStringSync(content);

  Set<String> names() => managed
      .listSync()
      .map((FileSystemEntity e) => e.path.split(Platform.pathSeparator).last)
      .toSet();

  setUp(() {
    temp = Directory.systemTemp.createTempSync('invoice_store_test');
    managed = Directory('${temp.path}${Platform.pathSeparator}managed')
      ..createSync();
    cleanCalls = 0;
    cleanError = null;
    store = ManagedImageStore(
      managedDir: managed,
      cleanScannerCache: () async {
        cleanCalls++;
        final Object? e = cleanError;
        if (e != null) throw e;
      },
    );
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  group('allExist', () {
    test('true only when every file exists and is non-empty', () async {
      final File a = put('a.jpg');
      final File b = put('b.jpg');
      expect(await store.allExist(<String>[a.path, b.path]), isTrue);
      expect(
        await store.allExist(<String>[a.path, '${temp.path}/nope']),
        isFalse,
      );
      expect(
        await store.allExist(<String>[put('empty.jpg', content: '').path]),
        isFalse,
      );
    });

    test('an empty list is false', () async {
      expect(await store.allExist(const <String>[]), isFalse);
    });
  });

  group('deleteFiles', () {
    test('deletes the given files and tolerates missing ones', () async {
      final File a = put('a.jpg');
      final File b = put('b.jpg');
      await store.deleteFiles(<String>[a.path, '${temp.path}/nope', b.path]);
      expect(names(), isEmpty);
    });

    test('never throws, and deleting twice is fine', () async {
      final File a = put('a.jpg');
      await store.deleteFiles(<String>[a.path]);
      await store.deleteFiles(<String>[a.path]);
      await store.deleteFiles(const <String>[]);
    });
  });

  group('deleteManagedFilesExcept', () {
    test(
      'keeps referenced files, removes orphans and temp leftovers',
      () async {
        final File keepA = put('keep_0.jpg');
        put('keep_1.jpg');
        put('orphan_0.jpg');
        put('half_0.jpg.tmp');
        await store.deleteManagedFilesExcept(<String>{
          keepA.path,
          '/some/old/container/keep_1.jpg',
        });
        expect(names(), <String>{'keep_0.jpg', 'keep_1.jpg'});
      },
    );

    test('an empty keep set removes everything', () async {
      put('a.jpg');
      put('b.jpg');
      await store.deleteManagedFilesExcept(const <String>{});
      expect(names(), isEmpty);
    });

    test('leaves subdirectories alone', () async {
      Directory('${managed.path}${Platform.pathSeparator}sub').createSync();
      await store.deleteManagedFilesExcept(const <String>{});
      expect(managed.listSync().whereType<Directory>(), hasLength(1));
    });

    test('a missing directory is not an error', () async {
      temp.deleteSync(recursive: true);
      await store.deleteManagedFilesExcept(const <String>{});
      temp.createSync();
    });
  });

  group('cleanScannerTemp', () {
    test('calls the scanner cache cleanup', () async {
      await store.cleanScannerTemp();
      expect(cleanCalls, 1);
    });

    test('swallows its errors', () async {
      cleanError = Exception('plugin failed');
      await store.cleanScannerTemp();
      expect(cleanCalls, 1);
    });
  });
}
