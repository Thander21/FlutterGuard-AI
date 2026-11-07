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

  // A use after the awaited dialog statement is past the gap (K4).
  Future<void> remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => const Text('remove'),
    );
    if (ok == true) {
      Navigator.of(context).pop();
    }
  }

  // A nested block without its own guard is still past the gap (K2).
  Future<void> delete() async {
    await _service.confirm();
    try {
      await _service.delete();
      Navigator.of(context).pop();
    } catch (_) {
      _log('delete failed');
    }
  }

  @override
  Widget build(BuildContext context) => const Text('order');
}

// Top-level helpers count too: no file gate (SYS-CAL-003 R2-1).
Future<void> submitOrder(BuildContext context) async {
  await _service.process();
  Navigator.of(context).pop();
}
