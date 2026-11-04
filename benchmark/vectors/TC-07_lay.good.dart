// Golden passing vector for FG-LAY-004 (v2).
// Every scrollable in Column/Row is bounded (Expanded/Flexible,
// SizedBox, shrinkWrap in Column). The gate MUST NOT flag this file.
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

class RowBoundedScreen extends StatelessWidget {
  const RowBoundedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ListView(),
        ),
      ],
    );
  }
}

class GridShrinkScreen extends StatelessWidget {
  const GridShrinkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
        ),
      ],
    );
  }
}

class SliverShrinkScreen extends StatelessWidget {
  const SliverShrinkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomScrollView(
          shrinkWrap: true,
          slivers: const [],
        ),
      ],
    );
  }
}

class FlexWrapScreen extends StatelessWidget {
  const FlexWrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Flexible(
          child: ListView(),
        ),
      ],
    );
  }
}

class BoxWrapScreen extends StatelessWidget {
  const BoxWrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: GridView.count(crossAxisCount: 2),
        ),
      ],
    );
  }
}
