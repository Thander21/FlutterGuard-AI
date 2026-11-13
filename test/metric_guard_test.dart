import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-MET-007 metric guard', () {
    test('flags over-deep trees and over-wide constructors', () {
      final violations = analyzeMetricFile(
        'benchmark/vectors/TC-13_met.bad.dart',
      );
      expect(violations.map((v) => v.line), [7, 29]);
      expect(violations.first.message, contains('9 parameters'));
      expect(violations.first.message, contains('advisory'));
      expect(violations.last.message, contains('depth 6'));
    });

    test('spares shallow trees (zero false positives)', () {
      final violations = analyzeMetricFile(
        'benchmark/vectors/TC-13_met.good.dart',
      );
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
  WideForm({
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

    test('treats scaffold levels as transparent (closed set)', () {
      final root = Directory.systemTemp.createTempSync('met_test.');
      try {
        final path = '${root.path}/scaffold.dart';
        File(path).writeAsStringSync('''
Widget buildScaffoldClean(BuildContext context) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Row(
          children: [
            ColoredBox(
              color: 0,
              child: SizedBox(width: 1, height: 1),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget buildCupertinoFlagged(BuildContext context) {
  return CupertinoApp(
    home: Column(
      children: [
        Column(
          children: [
            Column(
              children: [
                Column(
                  children: [
                    Text('x'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

Widget buildDeepScaffoldFlagged(BuildContext context) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          Column(
            children: [
              Column(
                children: [
                  Column(
                    children: [
                      Column(
                        children: [
                          Text('y'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
''');
        final violations = analyzeMetricFile(path);
        expect(violations.map((v) => v.line), [28, 53]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('exempts data-holder constructors, flags behavioral ones', () {
      final root = Directory.systemTemp.createTempSync('met_test.');
      try {
        final path = '${root.path}/holders.dart';
        File(path).writeAsStringSync('''
class Point9 {
  const Point9({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
    required this.g,
    required this.h,
    required this.i,
  });

  final int a;
  final int b;
  final int c;
  final int d;
  final int e;
  final int f;
  final int g;
  final int h;
  final int i;

  @override
  String toString() => 'Point9';
}

class Behavior9 {
  Behavior9({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
    required this.g,
    required this.h,
    required this.i,
  });

  final int a;
  final int b;
  final int c;
  final int d;
  final int e;
  final int f;
  final int g;
  final int h;
  final int i;

  int sum() => a + b;
}
''');
        final violations = analyzeMetricFile(path);
        expect(violations.map((v) => v.line), [29]);
        expect(violations.single.message, contains('9 parameters'));
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

    test('exempts models with serialization and Equatable companions', () {
      final root = Directory.systemTemp.createTempSync('met_test.');
      try {
        final path = '${root.path}/companions.dart';
        File(path).writeAsStringSync('''
class HandModel {
  const HandModel.new({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
    required this.g,
    required this.h,
    required this.i,
  });

  final int a;
  final int b;
  final int c;
  final int d;
  final int e;
  final int f;
  final int g;
  final int h;
  final int i;

  Map<String, int> toJson() => {'a': a};
  HandModel copyWith({int? a}) => this;
}

class EquatableModel extends Equatable {
  const EquatableModel({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
    required this.g,
    required this.h,
    required this.i,
  });

  final int a;
  final int b;
  final int c;
  final int d;
  final int e;
  final int f;
  final int g;
  final int h;
  final int i;

  @override
  List<Object?> get props => [a, b, c, d, e, f, g, h, i];

  @override
  bool get stringify => true;
}

class JsonModel {
  const JsonModel({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
    required this.g,
    required this.h,
    required this.i,
  });

  final int a;
  final int b;
  final int c;
  final int d;
  final int e;
  final int f;
  final int g;
  final int h;
  final int i;

  factory JsonModel.fromJson(Map<String, int> json) => JsonModel(
        a: 0,
        b: 0,
        c: 0,
        d: 0,
        e: 0,
        f: 0,
        g: 0,
        h: 0,
        i: 0,
      );

  Map<String, int> toJson() => {'a': a};
}

class FreezedModel {
  const factory FreezedModel({
    required int a,
    required int b,
    required int c,
    required int d,
    required int e,
    required int f,
    required int g,
    required int h,
    required int i,
  }) = _FreezedModel;

  factory FreezedModel.fromJson(Map<String, int> json) =>
      const FreezedModel(a: 0, b: 0, c: 0, d: 0, e: 0, f: 0, g: 0, h: 0, i: 0);
}
''');
        expect(analyzeMetricFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags display getters and setters (fail-closed)', () {
      final root = Directory.systemTemp.createTempSync('met_test.');
      try {
        final path = '${root.path}/getters.dart';
        File(path).writeAsStringSync('''
class DisplayModel {
  const DisplayModel({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
    required this.g,
    required this.h,
    required this.i,
  });

  final int a;
  final int b;
  final int c;
  final int d;
  final int e;
  final int f;
  final int g;
  final int h;
  final int i;

  String get displayName => 'd';
}

class SetterModel {
  const SetterModel({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
    required this.g,
    required this.h,
    required this.i,
  });

  final int a;
  final int b;
  final int c;
  final int d;
  final int e;
  final int f;
  final int g;
  final int h;
  final int i;

  set cache(Object? value) {}
}
''');
        final violations = analyzeMetricFile(path);
        expect(violations.map((v) => v.line), [2, 28]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares true primary constructors and the cited ERP screen', () {
      final root = Directory.systemTemp.createTempSync('met_test.');
      try {
        final path = '${root.path}/primary.dart';
        File(path).writeAsStringSync('''
class CompanyModel(
  final String f0,
  final String f1,
  final String f2,
  final String f3,
  final String f4,
  final String f5,
  final String f6,
  final String f7,
  final String f8,
  final String f9,
  final String f10,
  final String f11,
  final String f12,
  final String f13,
  final String f14,
  final String f15,
  final String f16,
  final String f17,
  final String f18,
  final String f19,
  final String f20,
  final String f21,
  final String f22,
  final String f23,
  final String f24,
  final String f25,
  final String f26,
  final String f27,
  final String f28,
);

Widget buildErpScreen(BuildContext context) {
  return Scaffold(
    body: Padding(
      padding: EdgeInsets.all(8),
      child: Column(
        children: [
          Card(
            child: Row(
              children: [Text('x')],
            ),
          ),
        ],
      ),
    ),
  );
}
''');
        expect(analyzeMetricFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('exempts const all-named entities with methods (R3)', () {
      final root = Directory.systemTemp.createTempSync('met_test.');
      try {
        final path = '${root.path}/entity.dart';
        File(path).writeAsStringSync('''
class ComplementGroup {
  const new({
    required this.id,
    required this.tenancyId,
    required this.nome,
    this.limiteMinimo = 0,
    this.limiteMaximo = 1,
    this.obrigatorio = false,
    this.permiteRepetirItem = false,
    this.ordemExibicao = 0,
    this.isActive = true,
  });

  final String id;
  final int tenancyId;
  final String nome;
  final int limiteMinimo;
  final int limiteMaximo;
  final bool obrigatorio;
  final bool permiteRepetirItem;
  final int ordemExibicao;
  final bool isActive;

  bool isValidSelection(int selectedCount) {
    return selectedCount <= limiteMaximo;
  }

  Map<String, Object?> toJson() => {'id': id};
}
''');
        expect(analyzeMetricFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('still flags const all-named with getters (R3 partial)', () {
      final root = Directory.systemTemp.createTempSync('met_test.');
      try {
        final path = '${root.path}/session.dart';
        File(path).writeAsStringSync('''
class TableSession {
  const new({
    required this.id,
    required this.tenancyId,
    required this.numeroMesa,
    this.capacidade = 4,
    this.status = 0,
    this.abertaEm,
    this.garcomNome,
    this.clienteNome,
    this.itens = const [],
  });

  final String id;
  final int tenancyId;
  final int numeroMesa;
  final int capacidade;
  final int status;
  final String? abertaEm;
  final String? garcomNome;
  final String? clienteNome;
  final List<String> itens;

  int get itemCount => itens.length;
}
''');
        final violations = analyzeMetricFile(path);
        expect(violations.map((v) => v.line), [2]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags const ctors with positional params (R3)', () {
      final root = Directory.systemTemp.createTempSync('met_test.');
      try {
        final path = '${root.path}/mixed.dart';
        File(path).writeAsStringSync('''
class Mixed9 {
  const Mixed9(
    this.a, {
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
    required this.g,
    required this.h,
    required this.i,
  });

  final int a;
  final int b;
  final int c;
  final int d;
  final int e;
  final int f;
  final int g;
  final int h;
  final int i;

  int sum() => a + b;
}
''');
        final violations = analyzeMetricFile(path);
        expect(violations.map((v) => v.line), [2]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('exempts const all-named widget constructors (R3)', () {
      final root = Directory.systemTemp.createTempSync('met_test.');
      try {
        final path = '${root.path}/widget.dart';
        File(path).writeAsStringSync('''
class WideWidget extends StatelessWidget {
  const WideWidget({
    super.key,
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
    required this.g,
    required this.h,
  });

  final String a;
  final String b;
  final String c;
  final String d;
  final String e;
  final String f;
  final String g;
  final String h;

  @override
  Widget build(BuildContext context) => Text(a);
}
''');
        expect(analyzeMetricFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
