// Golden passing vector for FG-KEY-001r.
// Every load-bearing item carries a key; static, foreign, and
// unknown shapes stay clean.
// The AST gate MUST NOT flag this file.
import 'package:flutter/widgets.dart';
import 'package:pdf/widgets.dart' as pw;

class CartTile extends StatefulWidget {
  const CartTile(this.item, {super.key});

  final String item;

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
        ...items.map((item) => CartTile(item, key: ValueKey(item))),
        ...items.map((item) => OrderTile(item)),
        ...items.map((item) => Text(item)),
        ...items.map((item) => pw.Padding(child: Text(item))),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) =>
                OrderTile(items[index], title: items[index]),
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
      children: [CartTile('a', key: ValueKey('a'))],
    );
  }
}
