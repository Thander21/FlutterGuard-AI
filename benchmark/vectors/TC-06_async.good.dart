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

  // Uses before the first await are not past a gap (K1).
  Future<void> load() async {
    try {
      setState(() {});
      final navigator = Navigator.of(context);
      await _service.load();
      if (mounted) {
        navigator.pop();
      }
    } catch (_) {
      _log('load failed');
    }
  }

  // Early returns clear the gap inside nested blocks (K2).
  Future<void> delete() async {
    final ok = await _service.confirm();
    if (ok != true || !context.mounted) return;
    try {
      await _service.delete();
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {});
    }
  }

  // Mounted checks chained with && guard their block (K3).
  Future<void> check(bool quiet) async {
    final ready = await _service.ping();
    if (!quiet && ready && context.mounted) {
      Navigator.of(context).pop();
    }
    if (ready) {
      _log('ready');
      if (mounted) {
        setState(() {});
      }
    }
  }

  // The awaited call's own arguments and builder run before the gap (K4).
  Future<void> pick(bool remote) async {
    await _service.ping();
    if (!mounted) return;
    if (remote) {
      await showDialog<bool>(
        context: context,
        builder: (ctx) => Text(Theme.of(context).toString()),
      );
    }
  }

  @override
  Widget build(BuildContext context) => const Text('order');
}
