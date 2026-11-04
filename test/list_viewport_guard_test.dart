import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-LAY-004 list viewport guard', () {
    test('flags unbounded scrollables in every flex cell', () {
      final violations =
          analyzeListViewportFile('benchmark/vectors/TC-07_lay.bad.dart');
      expect(violations.map((v) => v.line),
          [14, 30, 45, 58, 71, 84, 97, 110, 125, 140, 155, 172]);
      expect(violations.first.message, contains('ListView'));
      expect(violations.first.message, contains('Expanded'));
      expect(violations[2].message, contains('Row'));
      expect(violations[2].message, contains('width'));
      expect(violations[4].message, contains('GridView'));
      expect(violations[6].message, contains('CustomScrollView'));
      expect(violations[8].message, contains('through Padding'));
      expect(violations[9].message, contains('through Center'));
      expect(violations[10].message, contains('Row'));
      expect(violations[10].message, contains('through Align'));
      expect(violations[11].message, contains('through Padding > Center'));
    });

    test('spares bounded lists (zero false positives)', () {
      final violations =
          analyzeListViewportFile('benchmark/vectors/TC-07_lay.good.dart');
      expect(violations, isEmpty);
    });

    test('flags shrinkWrap:false and physics-only lists', () {
      final root = Directory.systemTemp.createTempSync('lay_test.');
      try {
        final path = '${root.path}/shrink.dart';
        File(path).writeAsStringSync('''
Widget build(BuildContext context) {
  return Column(
    children: [
      ListView(shrinkWrap: false),
      ListView(physics: NeverScrollableScrollPhysics()),
    ],
  );
}
''');
        final violations = analyzeListViewportFile(path);
        expect(violations.map((v) => v.line), [4, 5]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags lists hidden in if, spread, and for elements', () {
      final root = Directory.systemTemp.createTempSync('lay_test.');
      try {
        final path = '${root.path}/collections.dart';
        File(path).writeAsStringSync('''
Widget build(BuildContext context, bool flag) {
  return Column(
    children: [
      if (flag) ListView(),
      ...[ListView()],
      for (var i = 0; i < 1; i++) ListView(),
    ],
  );
}
''');
        final violations = analyzeListViewportFile(path);
        expect(violations.map((v) => v.line), [4, 5, 6]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags Row shrinkWrap traps and ignores scrollDirection', () {
      final root = Directory.systemTemp.createTempSync('lay_test.');
      try {
        final path = '${root.path}/row_trap.dart';
        File(path).writeAsStringSync('''
Widget build(BuildContext context) {
  return Column(
    children: [
      Row(children: [GridView.count(crossAxisCount: 2, shrinkWrap: true)]),
      Row(children: [CustomScrollView(shrinkWrap: true, slivers: const [])]),
      ListView(scrollDirection: Axis.horizontal),
    ],
  );
}
''');
        final violations = analyzeListViewportFile(path);
        expect(violations.map((v) => v.line), [4, 5, 6]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags all named scrollable constructors and prefixed forms', () {
      final root = Directory.systemTemp.createTempSync('lay_test.');
      try {
        final path = '${root.path}/ctors.dart';
        File(path).writeAsStringSync('''
Widget build(BuildContext context) {
  return Column(
    children: [
      ListView.separated(itemBuilder: (c, i) => Text('x'), separatorBuilder: (c, i) => Text(','), itemCount: 1),
      ListView.custom(childrenDelegate: SliverChildListDelegate(const [])),
      GridView.builder(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2), itemBuilder: (c, i) => Text('x')),
      GridView.extent(maxCrossAxisExtent: 100),
      GridView.custom(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2), childrenDelegate: SliverChildListDelegate(const [])),
      widgets.Column(children: [widgets.ListView.builder(itemBuilder: (c, i) => Text('x'))]),
    ],
  );
}
''');
        final violations = analyzeListViewportFile(path);
        expect(violations.map((v) => v.line), [4, 5, 6, 7, 8, 9]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('judges nested Columns independently, exactly once', () {
      final root = Directory.systemTemp.createTempSync('lay_test.');
      try {
        final path = '${root.path}/nested.dart';
        File(path).writeAsStringSync('''
Widget build(BuildContext context) {
  return Column(
    children: [
      Column(
        children: [
          ListView(),
        ],
      ),
    ],
  );
}
''');
        final violations = analyzeListViewportFile(path);
        expect(violations.map((v) => v.line), [6]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags min-axis, transitive/prefixed wrappers, Row trap', () {
      final root = Directory.systemTemp.createTempSync('lay_test.');
      try {
        final path = '${root.path}/v3.dart';
        File(path).writeAsStringSync('''
Widget build(BuildContext context) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ListView(),
      Padding(
        padding: EdgeInsets.all(8),
        child: Center(
          child: GridView.count(crossAxisCount: 2),
        ),
      ),
      widgets.Padding(
        padding: const EdgeInsets.all(8),
        child: widgets.ListView(),
      ),
      Row(
        children: [
          Padding(
            padding: EdgeInsets.all(8),
            child: ListView(shrinkWrap: true),
          ),
        ],
      ),
    ],
  );
}
''');
        final violations = analyzeListViewportFile(path);
        expect(violations.map((v) => v.line), [5, 9, 14, 20]);
        expect(violations[1].message, contains('through Padding > Center'));
        expect(violations[3].message, contains('Row'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares clean wrapper edges', () {
      final root = Directory.systemTemp.createTempSync('lay_test.');
      try {
        final path = '${root.path}/v3clean.dart';
        File(path).writeAsStringSync('''
Widget build(BuildContext context) {
  return Column(
    children: [
      Center(
        child: ListView(shrinkWrap: true),
      ),
      Padding(),
      Padding(child: Text('x')),
    ],
  );
}
''');
        expect(analyzeListViewportFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('judges flexes behind wrappers independently, exactly once', () {
      final root = Directory.systemTemp.createTempSync('lay_test.');
      try {
        final path = '${root.path}/wrapflex.dart';
        File(path).writeAsStringSync('''
Widget build(BuildContext context) {
  return Column(
    children: [
      Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            ListView(),
          ],
        ),
      ),
    ],
  );
}
''');
        final violations = analyzeListViewportFile(path);
        expect(violations.map((v) => v.line), [8]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
