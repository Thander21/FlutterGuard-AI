// TC-34 .good: sync I/O kept out of frame-critical scopes.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SmoothView extends StatefulWidget {
  const SmoothView({super.key});

  @override
  State<SmoothView> createState() => _SmoothViewState();
}

class _SmoothViewState extends State<SmoothView> {
  @override
  void initState() {
    super.initState();
    final seed = File('seed.txt').readAsStringSync();
    _warm(seed);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: File('title.txt').readAsString(),
      builder: (context, snapshot) => TextButton(
        onPressed: () async {
          final text = await File('note.txt').readAsString();
          _show(text);
        },
        child: const Text('load'),
      ),
    );
  }

  void _warm(String seed) {}
  void _show(String text) {}
}

// Sync work in top-level functions and isolate callbacks is unmeasured.
String loadConfig() {
  return File('config.txt').readAsStringSync();
}

void warmCache() {
  compute(_readSeed);
}

String _readSeed(String path) {
  return File(path).readAsStringSync();
}

// Lowercase (non-constructor) calls are outside the handler proxy.
void watchStream(Stream<int> stream) {
  stream.listen(
    (_) {},
    onDone: () {
      File('done.flag').deleteSync();
    },
  );
}

// Loops and decodes are profiler questions, not sync triggers.
class StatsView extends StatelessWidget {
  const StatsView({super.key});

  @override
  Widget build(BuildContext context) {
    var total = 0;
    for (var i = 0; i < 10; i++) {
      total += i;
    }
    final data = jsonDecode('{"total": 1}');
    return Text('$total ${data['total']}');
  }
}

// Notifier.build runs once as provider initialization (TS-14 doctrine).
class SeedNotifier extends Notifier<String> {
  @override
  String build() {
    return File('seed.txt').readAsStringSync();
  }
}

// Non-Widget builds are not widget build scope (TS-14 doctrine).
class ReportBuilder {
  Future<void> build() async {
    File('report.txt').writeAsStringSync('done');
  }
}
