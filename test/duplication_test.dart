// SYS-DRY-001 contract test: normalization/Jaccard units plus
// end-to-end verdicts on exact-line fixtures (each fixture is a line
// list joined with '\n', so spans are unambiguous).
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

/// 16-line clone, alpha names/literals.
const _cloneA = [
  'int alphaFirst(int alphaArg) {',
  '  var alphaTotal = 0;',
  '  if (alphaArg > 0) {',
  '    alphaTotal = alphaArg * 2;',
  '  } else {',
  '    alphaTotal = 10;',
  '  }',
  '  for (var i = 0; i < alphaTotal; i++) {',
  '    alphaTotal += i;',
  '  }',
  '  while (alphaTotal > 100) {',
  '    alphaTotal -= 5;',
  '  }',
  '  alphaTotal += 1;',
  '  return alphaTotal;',
  '}',
];

/// 16-line clone, beta names/literals, identical structure.
const _cloneB = [
  'int betaSecond(int betaArg) {',
  '  var betaTotal = 1;',
  '  if (betaArg > 1) {',
  '    betaTotal = betaArg * 3;',
  '  } else {',
  '    betaTotal = 20;',
  '  }',
  '  for (var k = 1; k < betaTotal; k++) {',
  '    betaTotal += k;',
  '  }',
  '  while (betaTotal > 200) {',
  '    betaTotal -= 7;',
  '  }',
  '  betaTotal += 2;',
  '  return betaTotal;',
  '}',
];

/// 16-line near-clone: same shape, second loop is `for` instead of
/// `while` (keywords participate in the bags).
const _cloneC = [
  'int gammaThird(int gammaArg) {',
  '  var gammaTotal = 0;',
  '  if (gammaArg > 0) {',
  '    gammaTotal = gammaArg * 2;',
  '  } else {',
  '    gammaTotal = 10;',
  '  }',
  '  for (var i = 0; i < gammaTotal; i++) {',
  '    gammaTotal += i;',
  '  }',
  '  for (var j = 0; j < gammaTotal; j++) {',
  '    gammaTotal -= 5;',
  '  }',
  '  gammaTotal += 1;',
  '  return gammaTotal;',
  '}',
];

/// 10-line identical twins (below the size bar).
const _tiny = [
  'int tiny(int x) {',
  '  var y = x * 2;',
  '  if (y > 0) {',
  '    y += 1;',
  '  }',
  '  for (var i = 0; i < y; i++) {',
  '    y += i;',
  '  }',
  '  return y;',
  '}',
];

/// 16-line branch-heavy function (negative control).
const _diffA = [
  'String describeA(int code) {',
  '  var seen = true;',
  '  if (code == 1) {',
  "    return 'one';",
  '  } else if (code == 2) {',
  "    return 'two';",
  '  } else if (code == 3) {',
  "    return 'three';",
  '  } else if (code == 4) {',
  "    return 'four';",
  '  } else if (code == 5) {',
  "    return 'five';",
  '  } else {',
  "    return 'other';",
  '  }',
  '}',
];

/// 20-line loop/switch-heavy function (negative control).
const _diffB = [
  'int accumulateB(int limit) {',
  '  var total = 0;',
  '  for (var i = 0; i < limit; i++) {',
  '    total += i;',
  '  }',
  '  while (total < 0) {',
  '    total++;',
  '  }',
  '  do {',
  '    total -= 2;',
  '  } while (total > 100);',
  '  switch (total) {',
  '    case 1:',
  '      total += 10;',
  '      break;',
  '    default:',
  '      total = 0;',
  '  }',
  '  return total;',
  '}',
];

/// 20-line class holding a 16-line method (nesting control).
const _shell = [
  'class Shell {',
  '  int bigMethod(int x) {',
  '    var a = x;',
  '    a += 1;',
  '    a += 2;',
  '    if (a > 0) { a -= 1; }',
  '    a += 3;',
  '    for (var i = 0; i < 3; i++) { a += i; }',
  '    a += 4;',
  '    while (a < 0) { a++; }',
  '    a += 5;',
  '    a += 6;',
  '    a += 7;',
  '    a += 8;',
  '    a += 9;',
  '    return a;',
  '  }',
  '  int small() => 1;',
  '  int tiny() => 2;',
  '}',
];

/// 18-line class, alpha names/literals (suppression control).
const _alpha = [
  'class Alpha {',
  '  int compute(int x) {',
  '    var total = x;',
  '    if (total > 0) {',
  '      total *= 2;',
  '    } else {',
  '      total = 5;',
  '    }',
  '    for (var i = 0; i < total; i++) {',
  '      total += i;',
  '    }',
  '    while (total > 50) {',
  '      total -= 3;',
  '    }',
  '    total += 4;',
  '    return total;',
  '  }',
  '}',
];

/// 18-line class, beta names/literals (suppression control).
const _beta = [
  'class Beta {',
  '  int calculate(int y) {',
  '    var sum = y;',
  '    if (sum > 1) {',
  '      sum *= 3;',
  '    } else {',
  '      sum = 6;',
  '    }',
  '    for (var k = 1; k < sum; k++) {',
  '      sum += k;',
  '    }',
  '    while (sum > 60) {',
  '      sum -= 4;',
  '    }',
  '    sum += 7;',
  '    return sum;',
  '  }',
  '}',
];

String _src(List<String> lines) => '${lines.join('\n')}\n';

void main() {
  group('bagJaccard', () {
    test('exact values and empties', () {
      expect(bagJaccard({'a': 2, 'b': 1}, {'a': 2, 'b': 1}), 1.0);
      expect(bagJaccard({'a': 1}, {'b': 1}), 0.0);
      expect(bagJaccard({'a': 4}, {'a': 4, 'b': 1}), closeTo(0.8, 1e-9));
      expect(bagJaccard({}, {}), 1.0);
      expect(bagJaccard({}, {'a': 1}), 0.0);
    });
  });

  group('collectUnits', () {
    test('collects >15-line declarations with exact spans', () {
      final units = collectUnits(_src(_cloneA));
      expect(units, hasLength(1));
      expect(units.single.name, 'alphaFirst');
      expect(units.single.line, 1);
      expect(units.single.endLine, 16);
    });

    test('skips 15-line twins and local functions', () {
      final fifteen = _src([..._cloneA.sublist(0, 13), ..._cloneA.sublist(14)]);
      expect(collectUnits(fifteen), isEmpty);
      const nested = [
        'int outer(int x) {',
        '  int inner(int y) {',
        '    return y * 2;',
        '  }',
        '  var total = inner(x);',
        '  if (total > 0) {',
        '    total += 1;',
        '  }',
        '  for (var i = 0; i < total; i++) {',
        '    total += i;',
        '  }',
        '  while (total > 10) {',
        '    total -= 1;',
        '  }',
        '  return total;',
        '}',
      ];
      final units = collectUnits(_src(nested));
      expect(units.map((u) => u.name), ['outer']);
    });

    test('normalization erases names/literals, keeps keywords', () {
      final a = collectUnits(_src(_cloneA)).single.bag;
      final b = collectUnits(_src(_cloneB)).single.bag;
      expect(a, b);
      final c = collectUnits(_src(_cloneC)).single.bag;
      expect(c, isNot(a));
      expect(c['for'], (a['for'] ?? 0) + 1);
      expect(c.containsKey('while'), isFalse);
    });
  });

  group('findDuplication', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('dry_');
      addTearDown(() => dir.deleteSync(recursive: true));
    });

    String write(String name, List<String> lines) {
      final file = File('${dir.path}/$name')
        ..writeAsStringSync(_src(lines));
      return file.path;
    }

    test('flags a 16-line rename clone at similarity 1.0', () {
      final a = write('a.dart', _cloneA);
      final b = write('b.dart', _cloneB);
      final verdict = findDuplication(dir.path);
      expect(verdict.passed, isTrue);
      expect(verdict.filesScanned, 2);
      expect(verdict.unitsCompared, 2);
      expect(verdict.errors, isEmpty);
      expect(verdict.pairs, hasLength(1));
      final pair = verdict.pairs.single;
      expect(pair.similarity, 1.0);
      expect(pair.nameA, 'alphaFirst');
      expect(pair.fileA, endsWith('a.dart'));
      expect([pair.lineA, pair.endLineA], [1, 16]);
      expect(pair.nameB, 'betaSecond');
      expect(pair.fileB, endsWith('b.dart'));
      expect([pair.lineB, pair.endLineB], [1, 16]);
      expect(a.compareTo(b) < 0, isTrue);
    });

    test('flags a near-clone below 1.0', () {
      write('a.dart', _cloneA);
      write('c.dart', _cloneC);
      final verdict = findDuplication(dir.path);
      expect(verdict.pairs, hasLength(1));
      final similarity = verdict.pairs.single.similarity;
      expect(similarity, greaterThanOrEqualTo(0.8));
      expect(similarity, lessThan(1.0));
    });

    test('skips 15-line and 10-line twins', () {
      final fifteen = [..._cloneA.sublist(0, 13), ..._cloneA.sublist(14)];
      write('a15.dart', fifteen);
      write('b15.dart', fifteen);
      write('tiny_a.dart', _tiny);
      write('tiny_b.dart', _tiny);
      final verdict = findDuplication(dir.path);
      expect(verdict.pairs, isEmpty);
      expect(verdict.unitsCompared, 0);
      expect(verdict.filesScanned, 4);
    });

    test('structurally different pair stays clean', () {
      write('diff_a.dart', _diffA);
      write('diff_b.dart', _diffB);
      final verdict = findDuplication(dir.path);
      expect(verdict.pairs, isEmpty,
          reason: 'despite equal size, shapes differ: ${verdict.pairs}');
      expect(verdict.unitsCompared, 2);
    });

    test('finds same-file clones', () {
      write('both.dart', [..._cloneA, ..._cloneB]);
      final verdict = findDuplication(dir.path);
      expect(verdict.pairs, hasLength(1));
      final pair = verdict.pairs.single;
      expect([pair.lineA, pair.endLineA], [1, 16]);
      expect([pair.lineB, pair.endLineB], [17, 32]);
    });

    test('nesting never self-reports', () {
      write('shell.dart', _shell);
      final verdict = findDuplication(dir.path);
      expect(verdict.unitsCompared, 2);
      expect(verdict.pairs, isEmpty);
    });

    test('class match subsumes member pairs', () {
      write('alpha.dart', _alpha);
      write('beta.dart', _beta);
      final verdict = findDuplication(dir.path);
      expect(verdict.pairs, hasLength(1),
          reason: 'only the class pair survives: ${verdict.pairs}');
      final pair = verdict.pairs.single;
      expect([pair.nameA, pair.nameB], ['Alpha', 'Beta']);
      expect(pair.similarity, 1.0);
    });

    test('tolerates bad files, rejects bad targets', () {
      File('${dir.path}/bad.dart').writeAsBytesSync([0xFF, 0xFE, 0x00]);
      write('ok.dart', _tiny);
      final verdict = findDuplication(dir.path);
      expect(verdict.errors, hasLength(1));
      expect(verdict.pairs, isEmpty);
      expect(verdict.filesScanned, 2);
      expect(() => findDuplication('${dir.path}/nope'), throwsArgumentError);
    });

    test('empty dir and non-dart file are empty verdicts', () {
      expect(findDuplication(dir.path).pairs, isEmpty);
      final noted = File('${dir.path}/note.txt')..writeAsStringSync('hi');
      final verdict = findDuplication(noted.path);
      expect(verdict.pairs, isEmpty);
      expect(verdict.filesScanned, 0);
    });
  });
}
