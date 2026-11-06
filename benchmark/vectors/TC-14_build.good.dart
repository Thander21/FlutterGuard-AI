// TC-14 .good: async work hoisted out of build().
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CalmView extends ConsumerStatefulWidget {
  const CalmView({super.key});

  @override
  ConsumerState<CalmView> createState() => _CalmViewState();
}

class _CalmViewState extends ConsumerState<CalmView> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), _refresh);
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    return FutureBuilder(
      future: Future.value(orders),
      builder: (context, snapshot) => TextButton(
        onPressed: () async {
          await _reload();
        },
        child: const Text('reload'),
      ),
    );
  }

  void _refresh() {}
  Future<void> _reload() async {}
}

// Non-Widget builds are not widget build scope (SYS-CAL-003 R2-3).
class ReportBuilder {
  Future<void> build() async {
    await Future.delayed(const Duration(seconds: 1));
  }
}

class CacheWarmer {
  void build(Cache cache) {
    cache.entries.then(_store);
  }

  void _store(Object? entries) {}
}

// Notifier.build runs once as provider initialization (SYS-CAL-002 P1-3).
class BootNotifier extends Notifier<BootState> {
  @override
  BootState build() {
    Future.microtask(_warm);
    Timer.run(_warm);
    return const BootState();
  }

  void _warm() {}
}
