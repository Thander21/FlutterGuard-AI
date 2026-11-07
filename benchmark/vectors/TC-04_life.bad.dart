// TC-04.bad: unreleased resources (FG-LIFE-001).

class _BadState extends State<BadWidget> {
  late final StreamSubscription _sub;
  Timer? _timer;
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _store = Store();
  final _store2 = Store();
  late final StreamSubscription _deact;
  var _lateSub;

  @override
  void initState() {
    super.initState();
    _sub = sensor.stream.listen(_onData);
    _timer = Timer.periodic(Duration(seconds: 1), (_) {});
    _store.addListener(_onStore);
    _store2.addListener(_h1);
    _deact = events.listen(_onEvent);
    _lateSub = sensor.stream.listen(_onData);
  }

  @override
  void deactivate() {
    _deact.cancel();
    super.deactivate();
  }

  @override
  void dispose() {
    _store2.removeListener(_h2);
    super.dispose();
  }

  void _onData(dynamic data) {}
  void _onStore() {}
  void _h1() {}
  void _h2() {}
  void _onEvent(dynamic event) {}

  @override
  Widget build(BuildContext context) => Container();
}

// Construction makes ownership: a field initialized with a controller
// and never disposed still flags next to a borrowed one (K1).
class _OwnedSearchState extends State<SearchWidget> {
  TextEditingController? _fieldController;
  final TextEditingController _query = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        _fieldController = controller;
        return TextField(controller: _query);
      },
    );
  }
}

// A release helper no entry point calls is not a release (K2:
// update_service.dart:51 shape).
class UpdateChecker {
  Timer? _periodicTimer;

  void startPeriodicCheck() {
    _periodicTimer = Timer.periodic(Duration(hours: 1), (_) {});
  }

  void stopPeriodicCheck() {
    _periodicTimer?.cancel();
  }
}
