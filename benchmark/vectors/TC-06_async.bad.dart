// Golden failing vector for FG-ASYNC-002.
// BuildContext and setState used after an async gap without a mounted guard.
// The AST gate MUST flag this file.
import 'package:flutter/widgets.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  Future<void> submit() async {
    await _service.process();
    Navigator.of(context).pop();
  }

  Future<void> refresh() async {
    await _service.reload();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => const Text('order');
}

// Top-level helpers count too: no file gate (SYS-CAL-003 R2-1).
Future<void> submitOrder(BuildContext context) async {
  await _service.process();
  Navigator.of(context).pop();
}
