import 'package:test/test.dart';

import '../lib/shop.dart';

void main() {
  test('shop has a name', () {
    expect(shopName(), isNotEmpty);
  });
}
