# 01. Meta Muse Spark
### Arquiteto de Especificação, Contratos Formais e Engenharia SDD

---

## 1. O que é o Meta Muse Spark?
O **Meta Muse Spark** é o modelo de fronteira da família Muse da Meta projetado especificamente para **raciocínio abstrato complexo, planejamento conceitual e decomposição de problemas multidimensionais**. Diferente de modelos que tentam cuspir código imediatamente, o Spark se destaca pela capacidade de antecipar casos de borda, inconsistências lógicas e desenhar contratos invioláveis antes da primeira linha de código.

---

## 2. Papel Específico no FlutterGuard-AI
No FlutterGuard-AI, o Muse Spark atua na **Fase 1: SDD (Spec-Driven Development)**:
1. **Interpretação de Requisitos:** Recebe a solicitação do usuário em linguagem natural (ex: *"quero uma tela de carrinho com cálculo de frete assíncrono e aplicação de cupom"*).
2. **Definição de Contratos de Estado:** Modela as máquinas de estado em Dart 3 utilizando `sealed class`, evitando estados impossíveis.
3. **Geração do Estágio RED (TDD):** Escreve os arquivos de teste unitário e de widgets (`test/cart_test.dart`) com asserções rigorosas antes mesmo de existir o arquivo de produção em `lib/`.
4. **Contrato de API do Widget:** Define quais parâmetros, streams ou controllers o widget precisa receber, sem permitir que lógica de negócio seja embutida no método `build()`.

---

## 3. Formato de Entrada e Saída (I/O)

### Payload de Entrada (Prompt Estruturado):
```json
{
  "role": "system",
  "instruction": "Você é o Arquiteto SDD do FlutterGuard-AI. Sua função é decompor o requisito do usuário em um contrato estrito de dados, estados possíveis em sealed classes e testes em Dart que falham intencionalmente (Fase RED). NUNCA gere o código de implementação da pasta lib/."
}
```

### Exemplo de Saída Esperada do Muse Spark:
```dart
// 1. Contrato de Estados Selados
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

// 2. Teste RED (test/features/cart/cart_test.dart)
void main() {
  test('Deve aplicar cupom de desconto de 10% no total com sucesso', () {
    // Esse teste falha porque CartNotifier ainda não foi implementado
    final notifier = CartNotifier();
    notifier.addItem(CartItem(price: 100.0));
    notifier.applyCoupon('PROMO10');
    expect(notifier.total, equals(90.0));
  });
}
```

---

## 4. Roteiro Prático de Estudos

1. **Modelagem de Estado com Dart 3:** Estude como `sealed class`, `pattern matching` e `switch expressions` eliminam bugs de estado no Flutter.
2. **Design de Testes de Comportamento (BDD):** Treine como transformar requisitos de tela em cenários de teste automatizados do tipo *Dado / Quando / Então*.
3. **JSON Schema Outputs:** Pratique instruir o modelo a responder estritamente no schema que seu orquestrador CLI consumirá para salvar os arquivos `.dart` de teste no disco.

