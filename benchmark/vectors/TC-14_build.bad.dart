// TC-14 .bad: fire-and-forget async work directly in build().
import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

class StormyView extends StatefulWidget {
  const StormyView({super.key});

  @override
  State<StormyView> createState() => _StormyViewState();
}

class _StormyViewState extends State<StormyView> {
  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 1), _refresh);
    Timer.periodic(const Duration(seconds: 30), _poll);
    Socket.connect('10.0.0.1', 8080);
    api.fetchOrders().then(_showOrders);
    return const Text('storm');
  }

  void _refresh() {}
  void _poll(Timer timer) {}
  void _showOrders(Object? orders) {}
}
