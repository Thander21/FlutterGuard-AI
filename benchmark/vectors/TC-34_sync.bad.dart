// TC-34 .bad: blocking sync I/O in frame-critical scopes.
import 'dart:io';

import 'package:flutter/widgets.dart';

class JankyView extends StatefulWidget {
  const JankyView({super.key});

  @override
  State<JankyView> createState() => _JankyViewState();
}

class _JankyViewState extends State<JankyView> {
  @override
  Widget build(BuildContext context) {
    final title = File('title.txt').readAsStringSync();
    File('build.log').writeAsStringSync(title);
    sleep(const Duration(milliseconds: 50));
    return TextButton(
      onPressed: () {
        if (File('flag.txt').existsSync()) {
          _arm();
        }
      },
      child: const Text('arm'),
    );
  }

  void _arm() {}
}

class TappyRow extends StatelessWidget {
  const TappyRow({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final entries = Directory('notes').listSync();
        _show(entries.length);
      },
      child: const Text('notes'),
    );
  }

  void _show(int count) {}
}

// Untyped build() stays measured (fail-closed, TS-14 doctrine).
class SketchyCache extends StatelessWidget {
  const SketchyCache({super.key});

  @override
  build(BuildContext context) {
    return Text(File('sketch.txt').readAsStringSync());
  }
}
