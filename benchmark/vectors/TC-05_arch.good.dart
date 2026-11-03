// Golden passing vector for FG-ARCH-003.
// The widget delegates to a provider; persistence lives in the data layer.
// The AST gate MUST NOT flag this file.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () {
        ref.read(productFormNotifierProvider.notifier).saveProduct();
      },
      child: const Text('Save'),
    );
  }
}
