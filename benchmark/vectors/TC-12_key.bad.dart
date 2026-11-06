// Golden failing vector for FG-KEY-001r.
// Load-bearing list items built without keys.
// The AST gate MUST flag this file.
import 'package:flutter/widgets.dart';

class CartTile extends StatefulWidget {
  const CartTile(this.item, {super.key, this.controller});

  final String item;
  final Object? controller;

  @override
  State<CartTile> createState() => _CartTileState();
}

class _CartTileState extends State<CartTile> {
  @override
  Widget build(BuildContext context) => Text(widget.item);
}

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
            itemBuilder: (context, index) =>
                CartTile(items[index], controller: searchCtrl),
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
      children: [CartTile('a'), const Text('b')],
    );
  }
}
