// Golden failing vector for FG-ST-005.
// State mutated in place instead of replaced.
// The AST gate MUST flag this file.
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartItems extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void addItem(String item) {
    state.add(item);
    state = state;
  }
}

class CartState {
  CartState(this.items);
  final List<String> items;
}

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(CartState([]));

  void addItem(String item) {
    state.items.add(item);
  }
}
