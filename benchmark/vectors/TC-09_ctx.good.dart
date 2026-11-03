// Golden passing vector for FG-CTX-006.
// BuildContext flows through widgets, State, and free helpers only.
// The AST gate MUST NOT flag this file.
import 'package:flutter/widgets.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => submitOrder(context),
      child: const Text('Pay'),
    );
  }
}

Future<void> submitOrder(BuildContext context) async {
  await _api.pay();
  if (!context.mounted) return;
  Navigator.of(context).pop();
}
