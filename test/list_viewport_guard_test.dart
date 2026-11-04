import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-LAY-004 list viewport guard', () {
    test('flags unbounded scrollables in every flex cell', () {
      final violations =
          analyzeListViewportFile('benchmark/vectors/TC-07_lay.bad.dart');
      expect(violations.map((v) => v.line), [14, 30, 45, 58, 71, 84, 97, 110]);
      expect(violations.first.message, contains('ListView'));
      expect(violations.first.message, contains('Expanded'));
      expect(violations[2].message, contains('Row'));
      expect(violations[2].message, contains('width'));
      expect(violations[4].message, contains('GridView'));
      expect(violations[6].message, contains('CustomScrollView'));
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
  });
}
