import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-LIFE-001 resource symmetry guard', () {
    test('flags unreleased fields and unpaired listeners', () {
      final violations = analyzeLifecycleFile(
        'benchmark/vectors/TC-04_life.bad.dart',
      );
      expect(violations.map((v) => v.line), [4, 5, 6, 7, 10, 11, 18, 19]);
      expect(violations.first.message, contains('StreamSubscription'));
      expect(violations.first.message, contains('dispose'));
      expect(violations[5].message, contains('StreamSubscription'));
      expect(violations[5].message, contains('_lateSub'));
      expect(violations.last.message, contains('removeListener'));
    });

    test('spares fully released resources (zero false positives)', () {
      final violations = analyzeLifecycleFile(
        'benchmark/vectors/TC-04_life.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('close() calls release tracked fields (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('life_test.');
      try {
        final path = '${root.path}/closer.dart';
        File(path).writeAsStringSync('''
class Panel extends State<Widget> {
  StreamSubscription? _sub;
  void init() {
    _sub = stream.listen(handler);
  }
  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }
}
''');
        expect(analyzeLifecycleFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('cancel() and close() methods release in plain classes (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('life_test.');
      try {
        final path = '${root.path}/worker.dart';
        File(path).writeAsStringSync('''
class A {
  StreamSubscription? _sub;
  void init() {
    _sub = stream.listen(handler);
  }
  void close() {
    _sub?.cancel();
  }
}

class B {
  Timer? _timer;
  void init() {
    _timer = Timer(Duration(seconds: 1), handler);
  }
  void cancel() {
    _timer?.cancel();
  }
}
''');
        expect(analyzeLifecycleFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('opaque acquires with declared types still flag (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('life_test.');
      try {
        final path = '${root.path}/opaque.dart';
        File(path).writeAsStringSync('''
class Holder {
  StreamSubscription? _sub;
  void init() {
    _sub = makeSub();
  }
}
''');
        final violations = analyzeLifecycleFile(path);
        expect(violations.map((v) => v.line), [2]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('State subclasses keep the dispose-only rule (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('life_test.');
      try {
        final path = '${root.path}/panel.dart';
        File(path).writeAsStringSync('''
class Panel extends State<Widget> {
  StreamSubscription? _sub;
  void init() {
    _sub = stream.listen(handler);
  }
  void close() {
    _sub?.cancel();
  }
}
''');
        final violations = analyzeLifecycleFile(path);
        expect(violations.map((v) => v.line), [2]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('construction overrides borrowed receipt (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('life_test.');
      try {
        final path = '${root.path}/box.dart';
        File(path).writeAsStringSync('''
class Box {
  Box(this.controller);
  TextEditingController controller;
  void reset() {
    controller = TextEditingController();
  }
}
''');
        final violations = analyzeLifecycleFile(path);
        expect(violations.map((v) => v.line), [3]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test(
      'borrows fields assigned from constructor params in bodies (R2-3)',
      () {
        final root = Directory.systemTemp.createTempSync('life_test.');
        try {
          final path = '${root.path}/field.dart';
          File(path).writeAsStringSync('''
class Field {
  Field(TextEditingController controller) {
    _controller = controller;
  }
  late final TextEditingController _controller;
}
''');
          expect(analyzeLifecycleFile(path), isEmpty);
        } finally {
          root.deleteSync(recursive: true);
        }
      },
    );
  });
}
