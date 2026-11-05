// Golden failing vector for FG-ARCH-003.
// A widget file importing persistence/network packages directly.
// The AST gate MUST flag this file.
import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Future<void> save() async {
    final db = AppDatabase();
    await db.into(db.products).insert(const ProductsCompanion());
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: save, child: const Text('Save'));
  }
}
