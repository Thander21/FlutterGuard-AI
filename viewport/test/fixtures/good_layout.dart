// Tier-1 .good fixture: the same row inside a horizontal scroll view
// stays clean on all six matrix cases.
import 'package:flutter/material.dart';

class GoodLayout extends StatelessWidget {
  const GoodLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ColoredBox(
                color: Colors.red,
                child: SizedBox(width: 2000, height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
