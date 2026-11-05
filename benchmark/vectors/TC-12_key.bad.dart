// Golden failing vector for FG-KEY-001r.
// List items built without keys.
// The AST gate MUST flag this file.
import 'package:flutter/widgets.dart';

class CartList extends StatelessWidget {
  const CartList({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...items.map((item) => CartTile(item)),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => CartTile(items[index]),
          ),
        ),
      ],
    );
  }
}

class OrderList extends StatelessWidget {
  const OrderList({super.key, required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      onReorder: (oldIndex, newIndex) {},
      children: [CartTile('a'), const Text('b')],
    );
  }
}
