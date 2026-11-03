// Golden passing vector for FG-ASYNC-002.
// Every post-await context use sits behind a mounted guard.
// The AST gate MUST NOT flag this file.
import 'package:flutter/widgets.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  Future<void> submit() async {
    final navigator = Navigator.of(context);
    await _service.process();
    if (!context.mounted) return;
    navigator.pop();
  }

  Future<void> refresh() async {
    await _service.reload();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> guarded() async {
    await _service.ping();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => const Text('order');
}
