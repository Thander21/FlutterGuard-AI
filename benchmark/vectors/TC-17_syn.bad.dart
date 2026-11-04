// TC-17 .bad: a single syntactic error.
import 'dart:async';

Future<String> describe(Object? value) async {
  var greeting = ;
  return '$value';
}
