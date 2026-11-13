import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-LIFE-001 resource symmetry guard', () {
    test('flags unreleased fields and unpaired listeners', () {
      final violations = analyzeLifecycleFile(
        'benchmark/vectors/TC-04_life.bad.dart',
      );
      expect(violations.map((v) => v.line), [
        4,
        5,
        6,
        7,
        10,
        11,
        18,
        19,
        50,
        66,
      ]);
      expect(violations.first.message, contains('StreamSubscription'));
      expect(violations.first.message, contains('dispose'));
      expect(violations[5].message, contains('StreamSubscription'));
      expect(violations[5].message, contains('_lateSub'));
      expect(violations[7].message, contains('removeListener'));
      expect(violations[8].message, contains('_query'));
      expect(violations.last.message, contains('_periodicTimer'));
    });

    test('spares fully released resources (zero false positives)', () {
      final violations = analyzeLifecycleFile(
        'benchmark/vectors/TC-04_life.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('close() calls release tracked fields (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('life_test.');
      try {
        final path = '${root.path}/closer.dart';
        File(path).writeAsStringSync('''
class Panel extends State<Widget> {
  StreamSubscription? _sub;
  void init() {
    _sub = stream.listen(handler);
  }
  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }
}
''');
        expect(analyzeLifecycleFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('cancel() and close() methods release in plain classes (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('life_test.');
      try {
        final path = '${root.path}/worker.dart';
        File(path).writeAsStringSync('''
class A {
  StreamSubscription? _sub;
  void init() {
    _sub = stream.listen(handler);
  }
  void close() {
    _sub?.cancel();
  }
}

class B {
  Timer? _timer;
  void init() {
    _timer = Timer(Duration(seconds: 1), handler);
  }
  void cancel() {
    _timer?.cancel();
  }
}
''');
        expect(analyzeLifecycleFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('opaque acquires with declared types still flag (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('life_test.');
      try {
        final path = '${root.path}/opaque.dart';
        File(path).writeAsStringSync('''
class Holder {
  StreamSubscription? _sub;
  void init() {
    _sub = makeSub();
  }
}
''');
        final violations = analyzeLifecycleFile(path);
        expect(violations.map((v) => v.line), [2]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('State subclasses keep the dispose-only rule (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('life_test.');
      try {
        final path = '${root.path}/panel.dart';
        File(path).writeAsStringSync('''
class Panel extends State<Widget> {
  StreamSubscription? _sub;
  void init() {
    _sub = stream.listen(handler);
  }
  void close() {
    _sub?.cancel();
  }
}
''');
        final violations = analyzeLifecycleFile(path);
        expect(violations.map((v) => v.line), [2]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('construction overrides borrowed receipt (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('life_test.');
      try {
        final path = '${root.path}/box.dart';
        File(path).writeAsStringSync('''
class Box {
  Box(this.controller);
  TextEditingController controller;
  void reset() {
    controller = TextEditingController();
  }
}
''');
        final violations = analyzeLifecycleFile(path);
        expect(violations.map((v) => v.line), [3]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test(
      'borrows fields assigned from constructor params in bodies (R2-3)',
      () {
        final root = Directory.systemTemp.createTempSync('life_test.');
        try {
          final path = '${root.path}/field.dart';
          File(path).writeAsStringSync('''
class Field {
  Field(TextEditingController controller) {
    _controller = controller;
  }
  late final TextEditingController _controller;
}
''');
          expect(analyzeLifecycleFile(path), isEmpty);
        } finally {
          root.deleteSync(recursive: true);
        }
      },
    );

    test('borrows fields assigned from closure parameters (K1)', () {
      final root = Directory.systemTemp.createTempSync('life_test.');
      try {
        final path = '${root.path}/search.dart';
        File(path).writeAsStringSync('''
class _SearchState extends ConsumerState<Search> {
  TextEditingController? _fieldController;
  final TextEditingController _query = TextEditingController();
  TextEditingController? _owned;

  @override
  void initState() {
    super.initState();
    _owned = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      fieldViewBuilder: (context, controller, focusNode, submit) {
        _fieldController = controller;
        return TextField(controller: controller);
      },
    );
  }
}
''');
        final violations = analyzeLifecycleFile(path);
        expect(violations.map((v) => v.line), [3, 4]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('follows self-calls from release entry points (K2)', () {
      final root = Directory.systemTemp.createTempSync('life_test.');
      try {
        final path = '${root.path}/entries.dart';
        File(path).writeAsStringSync('''
class Scanner implements IScanner {
  StreamSubscription? _subscription;
  Timer? _cleanupTimer;
  void start() {
    _subscription = socket.listen(_onEvent);
    _cleanupTimer = Timer.periodic(period, (_) {});
  }
  Future<void> stopScanning() async {
    _cleanupTimer?.cancel();
    await _subscription!.cancel();
  }
  Future<void> dispose() async {
    await stopScanning();
  }
}

class Hub {
  StreamSubscription? _ws;
  void connect() {
    _ws = channel.stream.listen(_onEvent);
  }
  void disconnect() {
    final sub = _ws;
    if (sub != null) unawaited(sub.cancel());
    _ws = null;
  }
  void dispose() {
    this.disconnect();
  }
}

class Repo {
  Timer? _syncTimer;
  void _start() {
    _syncTimer = Timer.periodic(period, (_) {});
  }
  void _inner() {
    _syncTimer?.cancel();
  }
  void _stopSync() {
    _inner();
  }
  void dispose() {
    _stopSync();
  }
}

class Monitor extends Notifier<int> {
  Timer? _timer;
  @override
  int build() {
    ref.onDispose(() {
      stop();
    });
    return 0;
  }
  void start() {
    _timer = Timer.periodic(period, (_) {});
  }
  void stop() {
    _timer?.cancel();
  }
}

class Tables extends Notifier<int> {
  StreamSubscription? _eventsSub;
  @override
  int build() {
    ref.onDispose(() {
      final sub = _eventsSub;
      if (sub != null) unawaited(sub.cancel());
    });
    _eventsSub = hub.events.listen(_onEvent);
    return 0;
  }
}

class Sink extends LogOutput {
  Timer? _timer;
  void _startTimer() {
    _timer = Timer.periodic(period, (_) {});
  }
  @override
  Future<void> destroy() async {
    _timer?.cancel();
    await super.destroy();
  }
}

class Updater {
  Timer? _periodic;
  void startPeriodicCheck() {
    _periodic = Timer.periodic(period, (_) {});
  }
  void stopPeriodicCheck() {
    _periodic?.cancel();
  }
}

class Deep {
  Timer? _t;
  void init() {
    _t = Timer(period, () {});
  }
  void _c() {
    _t?.cancel();
  }
  void _b() {
    _c();
  }
  void _a() {
    _b();
  }
  void dispose() {
    _a();
  }
}

class WindowHelper {
  static void addListener(WindowListener listener) {
    windowManager.addListener(listener);
  }
}
''');
        final violations = analyzeLifecycleFile(path);
        expect(violations.map((v) => v.line), [91, 101]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('honors configured releaser verbs (R3)', () {
      final root = Directory.systemTemp.createTempSync('life_test.');
      try {
        final path = '${root.path}/poller.dart';
        File(path).writeAsStringSync('''
class Poller {
  late StreamSubscription _sub;
  void start() {
    _sub = sensor.stream.listen(_onData);
  }
  void dispose() {
    _sub.shutdown();
  }
}
''');
        expect(
          analyzeLifecycleFile(
            path,
            releasers: const RuleListConfig<String>(['shutdown']),
          ),
          isEmpty,
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('loads releasers from yaml, skipping malformed entries (R3)', () {
      final root = Directory.systemTemp.createTempSync('life_test.');
      try {
        File('${root.path}/flutterguard.yaml').writeAsStringSync('''
releasers:
  - shutdown
  - 42
  - {verb: teardown}
  - ''
  - teardown
''');
        final path = '${root.path}/poller.dart';
        File(path).writeAsStringSync('''
class Poller {
  late StreamSubscription _sub;
  void start() {
    _sub = sensor.stream.listen(_onData);
  }
  void dispose() {
    _sub.shutdown();
  }
}
''');
        expect(analyzeLifecycleFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('treats configured names as entries outside State (R3)', () {
      final root = Directory.systemTemp.createTempSync('life_test.');
      try {
        final path = '${root.path}/worker.dart';
        File(path).writeAsStringSync('''
class Worker {
  Timer? _timer;
  void start() {
    _timer = Timer.periodic(period, (_) {});
  }
  void teardown() {
    _timer?.cancel();
  }
}
''');
        expect(
          analyzeLifecycleFile(
            path,
            releasers: const RuleListConfig<String>(['teardown']),
          ),
          isEmpty,
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('ignores configured entries in State subclasses (R3)', () {
      final root = Directory.systemTemp.createTempSync('life_test.');
      try {
        final path = '${root.path}/clock.dart';
        File(path).writeAsStringSync('''
class _ClockState extends State<Clock> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(period, (_) {});
  }
  void cleanup() {
    _timer?.cancel();
  }
}
''');
        final violations = analyzeLifecycleFile(
          path,
          releasers: const RuleListConfig<String>(['cleanup']),
        );
        expect(violations.map((v) => v.line), [2]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('honors configured verbs in onDispose tear-offs (R3)', () {
      final root = Directory.systemTemp.createTempSync('life_test.');
      try {
        final path = '${root.path}/poller_notifier.dart';
        File(path).writeAsStringSync('''
class PollerNotifier extends Notifier<void> {
  late StreamSubscription _sub;
  @override
  void build() {
    _sub = sensor.stream.listen(_onData);
    ref.onDispose(_sub.shutdown);
  }
}
''');
        expect(
          analyzeLifecycleFile(
            path,
            releasers: const RuleListConfig<String>(['shutdown']),
          ),
          isEmpty,
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
