// Golden failing vector for FG-ST-001.
// Controllers created inside build() are rebuilt on every frame and never
// disposed. The AST gate MUST flag this file.
import 'package:flutter/widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();
    return Column(
      children: [
        TextField(controller: searchController),
        Expanded(
          child: ListView(controller: ScrollController()),
        ),
      ],
    );
  }
}
