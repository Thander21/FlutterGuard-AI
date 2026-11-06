import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-KEY-001r list key guard', () {
    test('flags state-bearing items in map, builder, and reorderable', () {
      final violations = analyzeListKeyFile(
        'benchmark/vectors/TC-12_key.bad.dart',
      );
      expect(violations.map((v) => v.line), [30, 35, 50, 50]);
      expect(violations.first.message, contains('CartTile'));
      expect(violations.first.message, contains('no key'));
      expect(violations.first.message, contains('ValueKey'));
    });

    test('spares keyed and non-load-bearing items (zero false positives)', () {
      final violations = analyzeListKeyFile(
        'benchmark/vectors/TC-12_key.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('flags key:null and local shapes on stateful tiles', () {
      final root = Directory.systemTemp.createTempSync('key_test.');
      try {
        final path = '${root.path}/blocks.dart';
        File(path).writeAsStringSync('''
import 'package:flutter/widgets.dart';

class CartTile extends StatefulWidget {
  const CartTile(this.item, {super.key, this.controller});
  final String item;
  final Object? controller;
  @override
  State<CartTile> createState() => _CartTileState();
}

class _CartTileState extends State<CartTile> {
  @override
  Widget build(BuildContext context) => Text('t');
}

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
      final tile = CartTile(item, controller: ctrl);
      return tile;
    }).toList(),
  );
}
''');
        final violations = analyzeListKeyFile(path);
        expect(violations.map((v) => v.line), [20, 29]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('skips nested creations, spares unknown Card roots', () {
      final root = Directory.systemTemp.createTempSync('key_test.');
      try {
        final path = '${root.path}/nested.dart';
        File(path).writeAsStringSync('''
import 'package:flutter/widgets.dart';

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

    test('spares stateless ListTile items in builders', () {
      final root = Directory.systemTemp.createTempSync('key_test.');
      try {
        final path = '${root.path}/tiles.dart';
        File(path).writeAsStringSync('''
import 'package:flutter/widgets.dart';

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
import 'package:flutter/widgets.dart';

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
import 'package:flutter/widgets.dart';

Widget build(BuildContext context, List<String> items) {
  return ReorderableListView.builder(
    itemCount: items.length,
    onReorder: (a, b) {},
    itemBuilder: (context, index) => Text(items[index]),
  );
}
''');
        final violations = analyzeListKeyFile(path);
        expect(violations.map((v) => v.line), [7]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares Map.map and data-only maps', () {
      final root = Directory.systemTemp.createTempSync('key_test.');
      try {
        final path = '${root.path}/data.dart';
        File(path).writeAsStringSync('''
import 'package:flutter/widgets.dart';

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

    test('passes unknown cross-file tiles (fail-open)', () {
      final root = Directory.systemTemp.createTempSync('key_test.');
      try {
        final path = '${root.path}/unknown.dart';
        File(path).writeAsStringSync('''
import 'package:flutter/widgets.dart';

Widget build(BuildContext context, List<String> items) {
  return Column(
    children: [
      ...items.map((item) => OrderTile(item)),
      Expanded(
        child: ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) =>
              OrderTile(items[index], title: 't', onTap: handleTap),
        ),
      ),
    ],
  );
}
''');
        expect(analyzeListKeyFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('ignores foreign targets and non-Flutter files', () {
      final root = Directory.systemTemp.createTempSync('key_test.');
      try {
        final foreign = '${root.path}/foreign.dart';
        File(foreign).writeAsStringSync('''
import 'package:flutter/widgets.dart';
import 'package:pdf/widgets.dart' as pw;

Widget build(BuildContext context, List<String> items) {
  return Column(
    children: items.map((item) => pw.Padding(child: Text(item))).toList(),
  );
}

Widget build2(BuildContext context, List<String> items) {
  return Column(
    children: items.map((item) => zz.Tile(item)).toList(),
  );
}
''');
        expect(
          analyzeListKeyFile(foreign),
          isEmpty,
          reason: 'pdf-prefixed and unmapped-prefixed roots are foreign',
        );

        final service = '${root.path}/danfe_service.dart';
        File(service).writeAsStringSync('''
import 'package:pdf/widgets.dart' as pw;

Object build(List<String> items) {
  return pw.Table(
    children: items.map((item) => pw.TableRow(item)).toList(),
  );
}
''');
        expect(
          analyzeListKeyFile(service),
          isEmpty,
          reason: 'no Flutter import: the file gate silences the rule',
        );

        final pure = '${root.path}/pure.dart';
        File(pure).writeAsStringSync('''
Object build(List<String> items, Object ctrl) {
  return Report(
    children: items.map((item) => Handler(item, controller: ctrl)).toList(),
  );
}
''');
        expect(
          analyzeListKeyFile(pure),
          isEmpty,
          reason:
              'a controller-carrying root with no Flutter import '
              'is gated, not flagged',
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags _Tile creations, spares _getName helpers', () {
      final root = Directory.systemTemp.createTempSync('key_test.');
      try {
        final path = '${root.path}/underscores.dart';
        File(path).writeAsStringSync('''
import 'package:flutter/widgets.dart';
import 'tiles.dart' as tiles;

class _Tile extends StatefulWidget {
  const _Tile(this.item, {super.key});

  final String item;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  @override
  Widget build(BuildContext context) => Text('t');
}

String _getName(String item) => item;

Widget build(BuildContext context, List<String> items) {
  return Column(
    children: [
      ...items.map((item) => _getName(item)),
      ...items.map((item) => _Tile(item)),
      ...items.map((item) => tiles.OrderTile(item, focusNode: node)),
    ],
  );
}
''');
        final violations = analyzeListKeyFile(path);
        expect(violations.map((v) => v.line), [24, 25]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
