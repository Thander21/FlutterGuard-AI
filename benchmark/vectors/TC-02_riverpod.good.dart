// Golden passing vector for FG-RIV-001.
// The callback uses `ref.read`; `ref.watch` stays in the build path.
// The AST gate MUST NOT flag this file.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final counterProvider = StateProvider<int>((ref) => 0);

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
