// Golden failing vector for FG-LYR-024.
// A ui file importing the database (see ../flutterguard.yaml).
// The AST gate MUST flag this file.
import 'package:drift/drift.dart';

Object loadUsers() => queryAll();
