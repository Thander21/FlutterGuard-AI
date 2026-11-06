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

  // A redeclared `context` is not the BuildContext (SYS-CAL-003 R2-1).
  Future<void> fiscal() async {
    final context = await _fiscalContextService.getContext('sale');
    await _service.ping();
    _log.record(context.traceId);
  }

  // A foreign `x.context` property is not the BuildContext (R2-1).
  Future<void> secure() async {
    await _service.ping();
    _log.record(tlsContext.context.sessionId);
  }

  // A mounted block inside try is honored (printer_page:70 shape).
  Future<void> save() async {
    try {
      await _service.save();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      _log('save failed');
    }
  }

  // A mounted block inside a closure is honored (open_pdv_page:115 shape).
  Future<void> open() async {
    await _service.open();
    schedule(() {
      if (context.mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) => const Text('order');
}
