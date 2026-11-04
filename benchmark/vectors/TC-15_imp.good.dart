// TC-15 .good: legal imports only (near-misses).
import 'dart:async';
import 'data:text/plain,hello';
import '../helper.dart';

import 'package:meta/meta.dart';

part 'src/types.dart';

const backend = 'dart:mirrors'; // Just a string, not a directive.

Future<String> describe(Object? value) async => '$value';
