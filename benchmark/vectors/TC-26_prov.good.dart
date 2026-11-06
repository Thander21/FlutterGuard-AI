// Golden passing vector for FG-RIV-026: suffixed providers plus every
// near-miss from the fp_limits (unsuffixed but out of scope).
final counterProvider = Provider((ref) => 0);
final usersProvider = FutureProvider.autoDispose.family((ref, id) => 0);
final sessionProvider = r.Provider((ref) => 0);
final _cacheProvider = Provider((ref) => 0);
final card = Provider(create: (_) => 0);
final tile = Provider.value(value: 0);
final limit = 10;
final alias = counterProvider;

class Holder {
  static final cacheProvider = Provider((ref) => 0);
}

class Owned {
  final cache = Provider((ref) => 0);
}

class SessionState extends Notifier {}

int readLocal() {
  final local = Provider((ref) => 0);
  return local.hashCode;
}
