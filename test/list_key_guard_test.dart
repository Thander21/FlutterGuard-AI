import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-KEY-001r list key guard', () {
    test('flags keyless items in map, builder, and reorderable', () {
      final violations = analyzeListKeyFile(
        'benchmark/vectors/TC-12_key.bad.dart',
      );
      expect(violations.map((v) => v.line), [15, 19, 36, 36]);
      expect(violations.first.message, contains('CartTile'));
      expect(violations.first.message, contains('no key'));
      expect(violations.first.message, contains('ValueKey'));
    });

    test('spares keyed items (zero false positives)', () {
      final violations = analyzeListKeyFile(
        'benchmark/vectors/TC-12_key.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('flags block bodies, key:null, and local shapes', () {
      final root = Directory.systemTemp.createTempSync('key_test.');
      try {
        final path = '${root.path}/blocks.dart';
        File(path).writeAsStringSync('''
Widget build(BuildContext context, List<String> items) {
  return Column(
    children: items
        .map((item) {
          return CartTile(item, key: null);
        })
        .toList(),
  );
}

Widget build2(BuildContext context, List<String> items) {
  return Column(
    children: items.map((item) {
      final tile = CartTile(item);
      return tile;
    }).toList(),
  );
}
''');
        final violations = analyzeListKeyFile(path);
        expect(violations.map((v) => v.line), [5, 14]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('skips nested creations, spares Card roots', () {
      final root = Directory.systemTemp.createTempSync('key_test.');
      try {
        final path = '${root.path}/nested.dart';
        File(path).writeAsStringSync('''
Widget build(BuildContext context, List<String> items) {
  return Column(
    children: items.map((item) => Card(child: CartTile(item))).toList(),
  );
}
''');
        expect(analyzeListKeyFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares ListTile items in builders', () {
      final root = Directory.systemTemp.createTempSync('key_test.');
      try {
        final path = '${root.path}/tiles.dart';
        File(path).writeAsStringSync('''
Widget build(BuildContext context, List<String> items) {
  return ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) => ListTile(title: Text(items[index])),
  );
}
''');
        expect(analyzeListKeyFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares tear-offs and single-child builders', () {
      final root = Directory.systemTemp.createTempSync('key_test.');
      try {
        final path = '${root.path}/tearoff.dart';
        File(path).writeAsStringSync('''
Widget build(BuildContext context, List<String> items) {
  return Column(
    children: items.map(CartTile.new).toList(),
  );
}

Widget wrap(BuildContext context) {
  return Builder(
    builder: (context) => CartTile('x'),
  );
}
''');
        expect(analyzeListKeyFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('stays strict under ReorderableListView.builder', () {
      final root = Directory.systemTemp.createTempSync('key_test.');
      try {
        final path = '${root.path}/reorder.dart';
        File(path).writeAsStringSync('''
Widget build(BuildContext context, List<String> items) {
  return ReorderableListView.builder(
    itemCount: items.length,
    onReorder: (a, b) {},
    itemBuilder: (context, index) => Text(items[index]),
  );
}
''');
        final violations = analyzeListKeyFile(path);
        expect(violations.map((v) => v.line), [5]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares Map.map and data-only maps', () {
      final root = Directory.systemTemp.createTempSync('key_test.');
      try {
        final path = '${root.path}/data.dart';
        File(path).writeAsStringSync('''
Map<String, int> lengths(Map<String, String> input) {
  return input.map((k, v) => MapEntry(k, v.length));
}

List<Record> records(List<String> ids) {
  return ids.map((id) => Record(id)).toList();
}
''');
        expect(analyzeListKeyFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
