// Golden passing vector for FG-KEY-001r.
// Every list item carries a key.
// The AST gate MUST NOT flag this file.
import 'package:flutter/widgets.dart';

class CartList extends StatelessWidget {
  const CartList({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...items.map((item) => CartTile(item, key: ValueKey(item))),
        ...items.map((item) => Text(item)),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) =>
                CartTile(items[index], key: ValueKey(items[index])),
          ),
        ),
      ],
    );
  }
}

class OrderList extends StatelessWidget {
  const OrderList({super.key});

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      onReorder: (oldIndex, newIndex) {},
      children: [
        CartTile('a', key: ValueKey('a')),
      ],
    );
  }
}
