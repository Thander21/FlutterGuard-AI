import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-ARCH-003 arch layer guard', () {
    test('flags persistence/network imports in a widget file', () {
      final violations = analyzeArchFile(
        'benchmark/vectors/TC-05_arch.bad.dart',
      );
      expect(violations.map((v) => v.line), [4, 6]);
      expect(violations.first.message, contains('drift'));
      expect(violations.last.message, contains('dio'));
      expect(violations.first.message, contains('data layer'));
    });

    test('spares the delegating widget (zero false positives)', () {
      final violations = analyzeArchFile(
        'benchmark/vectors/TC-05_arch.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('spares denylisted imports in a non-widget file', () {
      final root = Directory.systemTemp.createTempSync('arch_test.');
      try {
        final path = '${root.path}/app_db.dart';
        File(path).writeAsStringSync('''
import 'package:drift/drift.dart';

class AppDatabase extends Database {
  AppDatabase(super.executor);
}
''');
        expect(analyzeArchFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags a denylisted export in a widget file', () {
      final root = Directory.systemTemp.createTempSync('arch_test.');
      try {
        final path = '${root.path}/cart_screen.dart';
        File(path).writeAsStringSync('''
import 'package:flutter/widgets.dart';
export 'package:dio/dio.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) => const Text('cart');
}
''');
        final violations = analyzeArchFile(path);
        expect(violations.map((v) => v.line), [2]);
        expect(violations.single.message, contains('dio'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('matches custom widget bases by the Widget suffix', () {
      final root = Directory.systemTemp.createTempSync('arch_test.');
      try {
        final path = '${root.path}/base_button.dart';
        File(path).writeAsStringSync('''
import 'package:sqlite3/sqlite3.dart';

class BaseButton extends AppButtonWidget {
  const BaseButton({super.key});
}
''');
        final violations = analyzeArchFile(path);
        expect(violations.map((v) => v.line), [1]);
        expect(violations.single.message, contains('sqlite3'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('carves show-listed exception-only imports (R3)', () {
      final root = Directory.systemTemp.createTempSync('arch_test.');
      try {
        final path = '${root.path}/login_page.dart';
        File(path).writeAsStringSync('''
import 'package:dio/dio.dart' show DioException;
import 'package:flutter/widgets.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) => const Text('login');
  Future<void> signIn() async {
    try {
      await api.login();
    } on DioException catch (_) {
      rethrow;
    }
  }
}
''');
        expect(analyzeArchFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags show imports used beyond catch positions (R3)', () {
      final root = Directory.systemTemp.createTempSync('arch_test.');
      try {
        final path = '${root.path}/search_page.dart';
        File(path).writeAsStringSync('''
import 'package:dio/dio.dart' show DioException, Dio;
import 'package:flutter/widgets.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});
  @override
  Widget build(BuildContext context) => const Text('search');
  Future<void> run() async {
    final client = Dio();
    try {
      await client.get('/x');
    } on DioException catch (_) {
      rethrow;
    }
  }
}
''');
        final violations = analyzeArchFile(path);
        expect(violations.map((v) => v.line), [1]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags shown-but-unused imports (R3)', () {
      final root = Directory.systemTemp.createTempSync('arch_test.');
      try {
        final path = '${root.path}/idle_page.dart';
        File(path).writeAsStringSync('''
import 'package:dio/dio.dart' show DioException;
import 'package:flutter/widgets.dart';

class IdlePage extends StatelessWidget {
  const IdlePage({super.key});
  @override
  Widget build(BuildContext context) => const Text('idle');
}
''');
        final violations = analyzeArchFile(path);
        expect(violations.map((v) => v.line), [1]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags shown names thrown outside type positions (R3)', () {
      final root = Directory.systemTemp.createTempSync('arch_test.');
      try {
        final path = '${root.path}/retry_page.dart';
        File(path).writeAsStringSync('''
import 'package:dio/dio.dart' show DioException;
import 'package:flutter/widgets.dart';

class RetryPage extends StatelessWidget {
  const RetryPage({super.key});
  @override
  Widget build(BuildContext context) => const Text('retry');
  Never fail() {
    throw DioException(requestOptions: RequestOptions());
  }
}
''');
        final violations = analyzeArchFile(path);
        expect(violations.map((v) => v.line), [1]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('carves prefixed imports used only in on positions (R3)', () {
      final root = Directory.systemTemp.createTempSync('arch_test.');
      try {
        final path = '${root.path}/login_view.dart';
        File(path).writeAsStringSync('''
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:flutter/widgets.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});
  @override
  Widget build(BuildContext context) => const Text('login');
  Future<void> signIn() async {
    try {
      await api.login();
    } on sb.AuthException catch (_) {
      rethrow;
    }
  }
}
''');
        expect(analyzeArchFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags prefixed imports with value uses (R3)', () {
      final root = Directory.systemTemp.createTempSync('arch_test.');
      try {
        final path = '${root.path}/user_form.dart';
        File(path).writeAsStringSync('''
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:flutter/widgets.dart';

class UserForm extends StatelessWidget {
  const UserForm({super.key});
  @override
  Widget build(BuildContext context) => const Text('form');
  Future<void> load() async {
    final client = sb.Supabase.instance.client;
    await client.from('users').select();
  }
}
''');
        final violations = analyzeArchFile(path);
        expect(violations.map((v) => v.line), [1]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags unused prefixes (R3)', () {
      final root = Directory.systemTemp.createTempSync('arch_test.');
      try {
        final path = '${root.path}/idle_view.dart';
        File(path).writeAsStringSync('''
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:flutter/widgets.dart';

class IdleView extends StatelessWidget {
  const IdleView({super.key});
  @override
  Widget build(BuildContext context) => const Text('idle');
}
''');
        final violations = analyzeArchFile(path);
        expect(violations.map((v) => v.line), [1]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('bare exception-only imports still flag (known gap, R3)', () {
      final root = Directory.systemTemp.createTempSync('arch_test.');
      try {
        final path = '${root.path}/web_login.dart';
        File(path).writeAsStringSync('''
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/widgets.dart';

class WebLogin extends StatelessWidget {
  const WebLogin({super.key});
  @override
  Widget build(BuildContext context) => const Text('login');
  Future<void> signIn() async {
    try {
      await api.login();
    } on AuthException catch (_) {
      rethrow;
    }
  }
}
''');
        final violations = analyzeArchFile(path);
        expect(violations.map((v) => v.line), [1]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags hide-only and export shapes (R3)', () {
      final root = Directory.systemTemp.createTempSync('arch_test.');
      try {
        final path = '${root.path}/hide_view.dart';
        File(path).writeAsStringSync('''
import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart' hide Dio;
export 'package:dio/dio.dart' show DioException;

class HideView extends StatelessWidget {
  const HideView({super.key});
  @override
  Widget build(BuildContext context) => const Text('hide');
  Future<void> run() async {
    try {
      await api.run();
    } on DioException catch (_) {
      rethrow;
    }
  }
}
''');
        final violations = analyzeArchFile(path);
        expect(violations.map((v) => v.line), [2, 3]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
