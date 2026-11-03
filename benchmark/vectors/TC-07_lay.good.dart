// Golden passing vector for FG-LAY-004.
// Every ListView inside a Column is bounded (Expanded or shrinkWrap).
// The AST gate MUST NOT flag this file.
import 'package:flutter/widgets.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const HeaderWidget(),
        Expanded(
          child: ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) => Text('Item $index'),
          ),
        ),
        ListView(
          shrinkWrap: true,
          children: [Text('a')],
        ),
      ],
    );
  }
}
