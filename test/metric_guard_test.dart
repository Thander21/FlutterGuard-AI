import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-MET-007 metric guard', () {
    test('flags over-deep trees and over-wide constructors', () {
      final violations =
          analyzeMetricFile('benchmark/vectors/TC-13_met.bad.dart');
      expect(violations.map((v) => v.line), [7, 32]);
      expect(violations.first.message, contains('9 parameters'));
      expect(violations.first.message, contains('advisory'));
      expect(violations.last.message, contains('depth 6'));
    });

    test('spares shallow trees (zero false positives)', () {
      final violations =
          analyzeMetricFile('benchmark/vectors/TC-13_met.good.dart');
      expect(violations, isEmpty);
    });

    test('spares the 5-deep and 7-param boundaries', () {
      final root = Directory.systemTemp.createTempSync('met_test.');
      try {
        final path = '${root.path}/boundaries.dart';
        File(path).writeAsStringSync('''
Widget build(BuildContext context, List<String> items) {
  return Column(
    children: [
      Padding(
        padding: EdgeInsets.all(8),
        child: Text(items.length.toString()),
      ),
    ],
  );
}

class SmallForm extends StatelessWidget {
  const SmallForm({
    super.key,
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
  });

  final String a;
  final String b;
  final String c;
  final String d;
  final String e;
  final String f;

  @override
  Widget build(BuildContext context) => Text(a);
}
''');
        expect(analyzeMetricFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags an 8-parameter constructor', () {
      final root = Directory.systemTemp.createTempSync('met_test.');
      try {
        final path = '${root.path}/wide.dart';
        File(path).writeAsStringSync('''
class WideForm extends StatelessWidget {
  const WideForm({
    super.key,
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
    required this.g,
  });

  final String a;
  final String b;
  final String c;
  final String d;
  final String e;
  final String f;
  final String g;

  @override
  Widget build(BuildContext context) => Text(a);
}
''');
        final violations = analyzeMetricFile(path);
        expect(violations.map((v) => v.line), [2]);
        expect(violations.single.message, contains('8 parameters'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('measures Widget functions, skips List<Widget> helpers', () {
      final root = Directory.systemTemp.createTempSync('met_test.');
      try {
        final path = '${root.path}/helpers.dart';
        File(path).writeAsStringSync('''
class Tiles {
  List<Widget> buildTiles() {
    return [Column(children: [Column(children: [Column(children: [Column(children: [Column(children: [Text('x')])])])])])];
  }
}

Widget buildDeep() {
  return Column(children: [Column(children: [Column(children: [Column(children: [Column(children: [Text('x')])])])])]);
}
''');
        final violations = analyzeMetricFile(path);
        expect(violations.map((v) => v.line), [8]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
