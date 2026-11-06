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

// Method parameters pass in any class (SYS-CAL-003 R2-3).
class CartHolder extends Cubit<CartState> {
  CartHolder() : super(CartState());

  void rename(BuildContext context, String name) {
    emit(state.copyWith(name: name));
  }
}

// Builder signatures pass: context flows through, nothing stored (R2-3).
class TileFactory {
  Widget tile(BuildContext context, String label) {
    return Text(label);
  }
}
