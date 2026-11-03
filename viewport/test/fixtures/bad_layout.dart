// Tier-1 .bad fixture: a fixed 2000px row overflows every matrix case
// (the widest case is 1024px).
import 'package:flutter/material.dart';

class BadLayout extends StatelessWidget {
  const BadLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            ColoredBox(
              color: Colors.red,
              child: SizedBox(width: 2000, height: 100),
            ),
          ],
        ),
      ),
    );
  }
}
