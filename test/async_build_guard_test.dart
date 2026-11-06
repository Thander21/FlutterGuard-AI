// FG-BUILD-014 contract test: flags fire-and-forget async work
// directly in build(), spares handlers/declarative widgets.
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-BUILD-014 async-in-build guard', () {
    test('flags the .bad vector at exact lines', () {
      final violations = analyzeAsyncBuildFile(
        'benchmark/vectors/TC-14_build.bad.dart',
      );
      expect(violations.map((v) => v.line), [17, 18, 19, 20, 35]);
      expect(violations.first.message, contains('Future.delayed'));
    });

    test('spares the .good vector (zero false positives)', () {
      final violations = analyzeAsyncBuildFile(
        'benchmark/vectors/TC-14_build.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('flags unawaited, spares closures and pure shapes', () {
      final root = Directory.systemTemp.createTempSync('build_test.');
      try {
        final path = '${root.path}/shapes.dart';
        File(path).writeAsStringSync('''
import 'package:flutter/widgets.dart';
class V extends StatelessWidget {
  const V({super.key});
  @override
  Widget build(BuildContext context) {
    unawaited(api.load());
    return TextButton(
      onPressed: () {
        Future.delayed(const Duration(seconds: 1), _refresh);
      },
      child: const Text('go'),
    );
  }
}
''');
        final violations = analyzeAsyncBuildFile(path);
        expect(violations.map((v) => v.line), [6]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('covers Widget functions, spares plain methods', () {
      final root = Directory.systemTemp.createTempSync('build_test.');
      try {
        final path = '${root.path}/scopes.dart';
        File(path).writeAsStringSync('''
import 'package:flutter/widgets.dart';
Widget badge(String label) {
  Future.microtask(_warm);
  return Text(label);
}
void helper() {
  Future.microtask(_warm);
}
''');
        final violations = analyzeAsyncBuildFile(path);
        expect(violations.map((v) => v.line), [3]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares dynamic, typedef, and Future Widget builds (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('build_test.');
      try {
        final path = '${root.path}/returns.dart';
        File(path).writeAsStringSync('''
class A {
  dynamic build() {
    Future.delayed(const Duration(seconds: 1), _tick);
  }
  void _tick() {}
}

class B {
  MyWidget build() {
    Future.delayed(const Duration(seconds: 1), _tick);
  }
  void _tick() {}
}

class C {
  Future<Widget> build() async {
    await Future.delayed(const Duration(seconds: 1));
  }
}
''');
        expect(analyzeAsyncBuildFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
