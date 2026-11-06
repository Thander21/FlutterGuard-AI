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
