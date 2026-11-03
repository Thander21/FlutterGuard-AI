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
