import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-RIV-001 riverpod watch guard', () {
    test('flags the golden failing vector', () {
      final violations = analyzeRiverpodFile(
        'benchmark/vectors/TC-02_riverpod.bad.dart',
      );
      expect(violations.map((v) => v.line), [16, 32, 51]);
      expect(
        violations.map((v) => v.message),
        everyElement(contains('ref.read')),
      );
    });

    test('spares the golden passing vector (zero false positives)', () {
      final violations = analyzeRiverpodFile(
        'benchmark/vectors/TC-02_riverpod.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('spares factory chains with const and prefixed spellings (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('riv_test.');
      try {
        final path = '${root.path}/chains.dart';
        File(path).writeAsStringSync('''
const pinned = FutureProvider.autoDispose<int>((ref) => ref.watch(x));
final names = riverpod.FutureProvider.autoDispose.family<String, int>(
  (ref, id) async => fetch(ref.watch(x), id),
);
''');
        expect(analyzeRiverpodFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares BlocBuilder builder closures (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('riv_test.');
      try {
        final path = '${root.path}/panel.dart';
        File(path).writeAsStringSync('''
class Panel extends ConsumerWidget {
  const Panel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocBuilder<FooBloc, FooState>(
      builder: (context, state) => Text(ref.watch(x).toString()),
    );
  }
}
''');
        expect(analyzeRiverpodFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares HookConsumerWidget build methods (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('riv_test.');
      try {
        final path = '${root.path}/hook.dart';
        File(path).writeAsStringSync('''
class Panel extends HookConsumerWidget {
  const Panel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(x);
    return Text('\$value');
  }
}
''');
        expect(analyzeRiverpodFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags nested closures inside callbacks (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('riv_test.');
      try {
        final path = '${root.path}/nested.dart';
        File(path).writeAsStringSync('''
void setup() {
  run(() {
    run(() {
      ref.watch(x);
    });
  });
}
''');
        final violations = analyzeRiverpodFile(path);
        expect(violations.map((v) => v.line), [4]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('still flags non-factory chains (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('riv_test.');
      try {
        final path = '${root.path}/foreign.dart';
        File(path).writeAsStringSync('''
final a = foo.autoDispose((ref) => ref.watch(x));
final b = foo.family((ref, id) => ref.watch(x));
''');
        final violations = analyzeRiverpodFile(path);
        expect(violations.map((v) => v.line), [1, 2]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares build-time builders and ref-rebinding closures (K3)', () {
      final root = Directory.systemTemp.createTempSync('riv_test.');
      try {
        final path = '${root.path}/k3.dart';
        File(path).writeAsStringSync('''
class Page extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(idProvider).when(
      data: (id) => TextButton(
        onPressed: () => ref.read(allProvider.notifier).toggle(),
        child: Text(ref.watch(allProvider) ? 'Mine' : 'All'),
      ),
      loading: () => Text(ref.watch(labelProvider)),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

Widget list(WidgetRef ref) => ListView.builder(
  itemBuilder: (context, i) => Text(ref.watch(rowProvider(i))),
);

class Badge extends ConsumerWidget {
  void _showDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(healthProvider);
            return Text('\$state');
          },
        );
      },
    );
  }
}

Widget button(WidgetRef ref) => TextButton(
  onPressed: () {
    ref.watch(allProvider);
    showDialog<void>(builder: (ctx) => Text(ref.watch(allProvider)));
  },
  child: const Text('x'),
);
''');
        final violations = analyzeRiverpodFile(path);
        expect(violations.map((v) => v.line), [37, 38]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
