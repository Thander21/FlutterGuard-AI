// Golden failing vector for FG-CTX-006.
// BuildContext bound to service objects and stored in fields.
// The AST gate MUST flag this file.
import 'package:flutter/widgets.dart';

class CartService {
  CartService(this.context);

  final BuildContext context;

  void checkout() {
    _api.pay();
    Navigator.of(context).pop();
  }
}

class CartHolder extends Cubit<CartState> {
  CartHolder() : super(CartState());

  void rename(BuildContext context, String name) {
    emit(state.copyWith(name: name));
  }
}
