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

  // A named-argument label is not a BuildContext read (SYS-CAL-002 P1-4).
  Future<void> audit() async {
    await _service.ping();
    _log.record(context: 'user session');
  }

  @override
  Widget build(BuildContext context) => const Text('order');
}
