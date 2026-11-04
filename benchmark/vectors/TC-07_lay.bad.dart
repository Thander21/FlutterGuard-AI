// Golden failing vector for FG-LAY-004 (v2: all flex/scrollable cells).
// Scrollables placed directly inside Column/Row children.
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

class RowListScreen extends StatelessWidget {
  const RowListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ListView(),
      ],
    );
  }
}

class RowShrinkTrapScreen extends StatelessWidget {
  const RowShrinkTrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ListView(shrinkWrap: true),
      ],
    );
  }
}

class GridColumnScreen extends StatelessWidget {
  const GridColumnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GridView.count(crossAxisCount: 2),
      ],
    );
  }
}

class GridRowScreen extends StatelessWidget {
  const GridRowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GridView.count(crossAxisCount: 2),
      ],
    );
  }
}

class SliverColumnScreen extends StatelessWidget {
  const SliverColumnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomScrollView(slivers: const []),
      ],
    );
  }
}

class SliverRowScreen extends StatelessWidget {
  const SliverRowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CustomScrollView(slivers: const []),
      ],
    );
  }
}

class PaddedListScreen extends StatelessWidget {
  const PaddedListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(8),
          child: ListView(),
        ),
      ],
    );
  }
}

class CenteredGridScreen extends StatelessWidget {
  const CenteredGridScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: GridView.count(crossAxisCount: 2),
        ),
      ],
    );
  }
}

class AlignedSliverRowScreen extends StatelessWidget {
  const AlignedSliverRowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Align(
          child: CustomScrollView(slivers: const []),
        ),
      ],
    );
  }
}

class NestedWrapScreen extends StatelessWidget {
  const NestedWrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(8),
          child: Center(
            child: ListView(),
          ),
        ),
      ],
    );
  }
}
