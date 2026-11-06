// Golden failing vector for FG-RIV-001.
// `ref.watch` inside an event callback. The AST gate MUST flag this file.
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
        final current = ref.watch(counterProvider);
        debugPrint('$current');
      },
      child: Text('$count'),
    );
  }
}

// Event listeners stay callbacks: builder-scope never applies (R2-3).
class MuteButton extends ConsumerWidget {
  const MuteButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocListener<AudioBloc, AudioState>(
      listener: (context, state) {
        final volume = ref.watch(counterProvider);
        debugPrint('$volume');
      },
      child: const Text('mute'),
    );
  }
}
