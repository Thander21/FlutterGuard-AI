// Golden failing vector for FG-CTX-006.
// BuildContext stored in fields and globals.
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

// Stored globals flag in any scope (R2-3).
BuildContext? lastContext;
