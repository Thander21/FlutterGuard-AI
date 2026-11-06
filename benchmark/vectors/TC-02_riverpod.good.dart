// Golden passing vector for FG-RIV-001.
// The callback uses `ref.read`; `ref.watch` stays in the build path.
// The AST gate MUST NOT flag this file.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final counterProvider = StateProvider<int>((ref) => 0);

// Provider builders run as builds, not event callbacks (SYS-CAL-002 P1-1).
final doubledProvider = Provider<int>((ref) => ref.watch(counterProvider) * 2);
final tickProvider = FutureProvider<int>(
  (ref) async => ref.watch(counterProvider),
);
final overriddenProvider = counterProvider.overrideWith(
  (ref) => ref.watch(doubledProvider),
);

// Modifier chains are factories too (SYS-CAL-003 R2-3).
final companyProvider = FutureProvider.autoDispose.family<Company, String>(
  (ref, id) async => fetchCompany(ref.watch(authProvider), id),
);
final categoryProvider = FutureProvider.autoDispose<Category>(
  (ref) async => fetchCategory(ref.watch(authProvider)),
);

// Widget builders run at build time, not as callbacks (R2-3).
final panel = Consumer(
  builder: (context, ref, child) => Text(ref.watch(counterProvider).toString()),
);

class CounterButton extends ConsumerWidget {
  const CounterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return GestureDetector(
      onTap: () {
        final current = ref.read(counterProvider);
        debugPrint('$current');
      },
      child: Text('$count'),
    );
  }
}
