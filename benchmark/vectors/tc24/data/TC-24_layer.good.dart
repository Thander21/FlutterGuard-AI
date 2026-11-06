// Golden passing vector for FG-LYR-024.
// A data file importing the database: out of every files scope.
// The AST gate MUST NOT flag this file.
import 'package:drift/drift.dart';

Object loadUsers() => queryAll();
