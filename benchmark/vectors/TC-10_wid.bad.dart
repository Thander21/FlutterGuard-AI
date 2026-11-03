// Golden failing vector for FG-WID-008.
// A StatelessWidget with mutable instance fields.
// The AST gate MUST flag this file.
import 'package:flutter/widgets.dart';

class CounterLabel extends StatelessWidget {
  CounterLabel({super.key, required this.count});

  int count;
  var label = 'count';

  @override
  Widget build(BuildContext context) {
    return Text('$label: $count');
  }
}
