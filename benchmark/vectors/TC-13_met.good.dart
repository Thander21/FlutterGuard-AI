// Golden passing vector for FG-MET-007.
// A shallow tree and a narrow constructor.
// The AST gate MUST NOT flag this file.
import 'package:flutter/widgets.dart';

class SmallForm extends StatelessWidget {
  const SmallForm({
    super.key,
    required this.title,
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
  });

  final String title;
  final String a;
  final String b;
  final String c;
  final String d;
  final String e;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Column(children: [Text('ok')]),
            ],
          ),
        ),
      ],
    );
  }
}

// v4: const all-named entity with a domain method (field shape).
class ComplementGroup {
  const new({
    required this.id,
    required this.tenancyId,
    required this.nome,
    this.limiteMinimo = 0,
    this.limiteMaximo = 1,
    this.obrigatorio = false,
    this.permiteRepetirItem = false,
    this.ordemExibicao = 0,
    this.isActive = true,
  });

  final String id;
  final int tenancyId;
  final String nome;
  final int limiteMinimo;
  final int limiteMaximo;
  final bool obrigatorio;
  final bool permiteRepetirItem;
  final int ordemExibicao;
  final bool isActive;

  bool isValidSelection(int selectedCount) {
    return selectedCount <= limiteMaximo;
  }
}
