// TC-04.good: every resource released (FG-LIFE-001).

class _GoodState extends State<GoodWidget> {
  StreamSubscription? _sub;
  Timer? _timer;
  late final TextEditingController _controller;
  final _focus = FocusNode();
  final _store = Store();

  @override
  void initState() {
    super.initState();
    _sub = sensor.stream.listen(_onData);
    _timer = Timer(Duration(seconds: 1), _onTimer);
    _controller = TextEditingController();
    _store.addListener(_onStore);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    this._controller.dispose();
    _focus.dispose();
    _store.removeListener(_onStore);
    super.dispose();
  }

  void _probe() {
    final local = sensor.stream.listen(_onData);
    local.cancel();
  }

  void _onData(dynamic data) {}
  void _onStore() {}
  void _onTimer() {}

  @override
  Widget build(BuildContext context) => Container();
}

// Riverpod Notifiers register cleanup with ref.onDispose (SYS-CAL-002 P1-2).
class _GoodNotifier extends Notifier<Object> {
  late final StreamSubscription _sub;
  final TextEditingController _controller = TextEditingController();
  final _store = Store();

  @override
  Object build() {
    _sub = sensor.stream.listen(_onData);
    _store.addListener(_onStore);
    ref.onDispose(() {
      _sub.cancel();
      _controller.dispose();
      _store.removeListener(_onStore);
    });
    return Object();
  }

  void _onData(dynamic data) {}
  void _onStore() {}
}

class _TearoffNotifier extends Notifier<Object> {
  late final StreamSubscription _sub;

  @override
  Object build() {
    _sub = sensor.stream.listen(_onData);
    ref.onDispose(_sub.cancel);
    return Object();
  }

  void _onData(dynamic data) {}
}

// Cascade onDispose counts as a release (boot_resolver_io.dart:47 shape).
class _CascadeNotifier extends Notifier<Object> {
  StreamSubscription? _warmUp;

  @override
  Object build() {
    _warmUp = sensor.stream.listen(_onData);
    ref..onDispose(() => _warmUp?.close());
    return Object();
  }

  void _onData(dynamic data) {}
}

// Constructor-received fields are borrowed (cnpj_input_step.dart:30 shape).
class CnpjInput extends StatelessWidget {
  const CnpjInput({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Container();
}

class PhoneField extends StatelessWidget {
  PhoneField({super.key, required TextEditingController controller})
    : _controller = controller;

  final TextEditingController _controller;

  @override
  Widget build(BuildContext context) => Container();
}

// Services release in stop()/close() (fiscal_sync_worker.dart:113 shape).
class FiscalSyncWorker {
  StreamSubscription? _sub;

  void start() {
    _sub = events.listen(_onEvent);
  }

  void stop() {
    _sub?.cancel();
  }

  void _onEvent(dynamic event) {}
}

// Fields assigned from a closure parameter are borrowed, not owned
// (K1: cbenef_search_widget.dart:40 shape).
class _SearchState extends State<SearchWidget> {
  TextEditingController? _fieldController;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        _fieldController = controller;
        return TextField(controller: controller);
      },
    );
  }
}

// Releases in helpers reached from a release entry point count (K2):
// dispose() -> stopScanning(), one more level, and a local alias.
class LanScanner {
  StreamSubscription? _subscription;
  Timer? _cleanupTimer;

  void startScanning() {
    _subscription = socket.listen(_onEvent);
    _cleanupTimer = Timer.periodic(Duration(seconds: 5), (_) {});
  }

  Future<void> stopScanning() async {
    _cleanupTimer?.cancel();
    await _closeSocket();
  }

  Future<void> _closeSocket() async {
    final sub = _subscription;
    await sub?.cancel();
  }

  Future<void> dispose() async {
    await stopScanning();
  }

  void _onEvent(dynamic event) {}
}

// ref.onDispose closures reach same-class helpers (K2:
// printer_health_monitor.dart:37 shape).
class _HealthMonitor extends Notifier<Object> {
  Timer? _timer;

  @override
  Object build() {
    ref.onDispose(() {
      stop();
    });
    return Object();
  }

  void start() {
    _timer = Timer.periodic(Duration(seconds: 30), (_) {});
  }

  void stop() {
    _timer?.cancel();
  }
}

// destroy() is a release entry point outside State/Notifier (K2:
// hybrid_log_sink.dart:179 shape).
class _BufferedSink extends LogOutput {
  Timer? _timer;

  void startTimer() {
    _timer = Timer.periodic(Duration(seconds: 2), (_) {});
  }

  @override
  Future<void> destroy() async {
    _timer?.cancel();
    await super.destroy();
  }
}
