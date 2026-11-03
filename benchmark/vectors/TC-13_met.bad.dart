// Golden failing vector for FG-MET-007.
// An over-deep widget tree and an over-wide constructor.
// The AST gate MUST flag this file (advisory findings).
import 'package:flutter/widgets.dart';

class BigForm extends StatelessWidget {
  const BigForm({
    super.key,
    required this.title,
    required String a,
    required String b,
    required String c,
    required String d,
    required String e,
    required String f,
    required Widget badge,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    child: Text('deep'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
