// Golden failing vector for FG-LAY-004.
// ListView widgets placed directly inside Column children.
// The AST gate MUST flag this file.
import 'package:flutter/widgets.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const HeaderWidget(),
        ListView.builder(
          itemCount: 10,
          itemBuilder: (context, index) => Text('Item $index'),
        ),
      ],
    );
  }
}

class SplitScreen extends StatelessWidget {
  const SplitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListView(
          children: [Text('a')],
        ),
      ],
    );
  }
}
