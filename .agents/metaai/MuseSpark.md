# 01. Meta Muse Spark
### Specification Architect, Formal Contracts, and SDD Engineering

---

## 1. What Is Meta Muse Spark?
**Meta Muse Spark** is the frontier model of Meta's Muse family, designed specifically for **complex abstract reasoning, conceptual planning, and multidimensional problem decomposition**. Unlike models that try to spit out code immediately, Spark stands out for anticipating edge cases, logical inconsistencies, and drawing inviolable contracts before the first line of code.

---

## 2. Specific Role in FlutterGuard-AI
In FlutterGuard-AI, Muse Spark acts in **Phase 1: SDD (Spec-Driven Development)**:
1. **Requirement Interpretation:** Receives the user request in natural language (e.g. *"I want a cart screen with async shipping calculation and coupon support"*).
2. **State Contract Definition:** Models state machines in Dart 3 using `sealed class`, ruling out impossible states.
3. **RED Stage Generation (TDD):** Writes unit and widget test files (`test/cart_test.dart`) with rigorous assertions before the production file in `lib/` even exists.
4. **Widget API Contract:** Defines which parameters, streams, or controllers the widget must receive, without allowing business logic inside the `build()` method.

---

## 3. Input and Output Format (I/O)

### Input Payload (Structured Prompt):
```json
{
  "role": "system",
  "instruction": "You are the FlutterGuard-AI SDD Architect. Your job is to decompose the user requirement into a strict data contract, possible states as sealed classes, and intentionally failing Dart tests (RED phase). NEVER generate implementation code for the lib/ folder."
}
```

### Expected Muse Spark Output Example:
```dart
// 1. Sealed State Contract
sealed class CartState {}
class CartInitial extends CartState {}
class CartLoading extends CartState {}
class CartLoaded extends CartState {
  final List<CartItem> items;
  final double discount;
  CartLoaded({required this.items, this.discount = 0.0});
}
class CartError extends CartState {
  final String message;
  CartError(this.message);
}

// 2. RED Test (test/features/cart/cart_test.dart)
void main() {
  test('Applies a 10% discount coupon to the total successfully', () {
    // This test fails because CartNotifier is not implemented yet
    final notifier = CartNotifier();
    notifier.addItem(CartItem(price: 100.0));
    notifier.applyCoupon('PROMO10');
    expect(notifier.total, equals(90.0));
  });
}
```

---

## 4. Hands-On Study Roadmap

1. **State Modeling with Dart 3:** Study how `sealed class`, `pattern matching`, and `switch expressions` eliminate state bugs in Flutter.
2. **Behavior Test Design (BDD):** Practice turning screen requirements into automated *Given / When / Then* test scenarios.
3. **JSON Schema Outputs:** Practice instructing the model to reply strictly in the schema your CLI orchestrator consumes to save `.dart` test files to disk.
