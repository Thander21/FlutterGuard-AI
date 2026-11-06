// Golden failing vector for FG-RIV-026: every declaration below is a
// Riverpod provider factory assigned to a suffixless ambient name.
final counter = Provider((ref) => 0);
final users = FutureProvider((ref) => 0);
final events = StreamProvider((ref) => 0);
final theme = StateProvider((ref) => 0);
final tally = NotifierProvider(() => 0);
final account = AsyncNotifierProvider(() => 0);
final legacy = StateNotifierProvider((ref) => 0);
final changer = ChangeNotifierProvider((ref) => 0);
final settings = r.Provider((ref) => 0);
final session = FutureProvider.autoDispose((ref) => 0);
final greeter = Provider.family((ref, id) => 0);
final made = new Provider((ref) => 0);
final fooprovider = Provider((ref) => 0);
final fooProviders = Provider((ref) => 0);

class Holder {
  static final cache = Provider((ref) => 0);
}
