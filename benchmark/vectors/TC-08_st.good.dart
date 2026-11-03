// Golden passing vector for FG-ST-005.
// State is always replaced via copyWith-style assignment.
// The AST gate MUST NOT flag this file.
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartState {
  CartState(this.items);
  final List<String> items;

  CartState copyWith({List<String>? items}) {
    return CartState(items ?? this.items);
  }
}

class CartItems extends Notifier<CartState> {
  @override
  CartState build() => CartState([]);

  void addItem(String item) {
    state = state.copyWith(
      items: [...state.items, item],
    );
  }

  int get count {
    return state.items.length;
  }
}
