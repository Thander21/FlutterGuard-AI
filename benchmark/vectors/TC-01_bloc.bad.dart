// Golden failing vector for FG-BLOC-001.
// This code violates the invariant: `emit` after `await` without an
// `isClosed` guard. The AST gate MUST flag this file.
import 'package:bloc/bloc.dart';

sealed class CartState {}

final class CartInitial extends CartState {}

final class CartSaving extends CartState {}

final class CartSaved extends CartState {}

class CartRepository {
  Future<void> save() async {}
}

class CartCubit extends Cubit<CartState> {
  CartCubit(this._repository) : super(CartInitial());

  final CartRepository _repository;

  Future<void> checkout() async {
    emit(CartSaving());
    await _repository.save();
    emit(CartSaved());
  }
}
