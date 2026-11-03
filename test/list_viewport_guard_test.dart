import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-LAY-004 list viewport guard', () {
    test('flags unbounded ListViews directly inside Column', () {
      final violations =
          analyzeListViewportFile('benchmark/vectors/TC-07_lay.bad.dart');
      expect(violations.map((v) => v.line), [14, 30]);
      expect(violations.first.message, contains('ListView'));
      expect(violations.first.message, contains('Expanded'));
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
