import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:where_its_at/data/search_index.dart';


class _DummyRef implements Ref<Object?> {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('search matches case-insensitive and highlights', () {
    final index = SearchIndex(_DummyRef());
    index.state = [
      SearchResult(type: 'loan', id: 'l1', itemId: 'i1', display: 'Hammer (Alice)', highlights: ['Hammer', 'Alice']),
      SearchResult(type: 'stash', id: 's1', itemId: 'i2', display: 'Wrench (Garage, shelf)', highlights: ['Wrench', 'Garage', 'shelf']),
    ];
    final results = index.search('ham');
    expect(results.length, 1);
    expect(results.first.display, contains('Hammer'));
    final results2 = index.search('alice');
    expect(results2.length, 1);
    expect(results2.first.display, contains('Alice'));
    final results3 = index.search('garage');
    expect(results3.length, 1);
    expect(results3.first.type, 'stash');
    final results4 = index.search('shelf');
    expect(results4.length, 1);
    expect(results4.first.display, contains('shelf'));
    final results5 = index.search('missing');
    expect(results5.isEmpty, true);
  });
}
