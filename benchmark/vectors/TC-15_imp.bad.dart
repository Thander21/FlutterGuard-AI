// TC-15 .bad: illegal mirrors import and export.
import 'dart:mirrors';

export 'dart:mirrors';

String describe(Object? value) => '$value';
