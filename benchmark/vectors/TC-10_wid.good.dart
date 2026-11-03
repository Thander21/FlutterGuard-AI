// Golden passing vector for FG-WID-008.
// Immutable StatelessWidget: final fields and static state only.
// The AST gate MUST NOT flag this file.
import 'package:flutter/widgets.dart';

class CounterLabel extends StatelessWidget {
  const CounterLabel({super.key, required this.count});

  final int count;
  static int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    return Text('count: $count');
  }
}
